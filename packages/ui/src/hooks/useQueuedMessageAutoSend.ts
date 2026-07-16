import React from 'react';
import { flushMessageQueuePersistence, useMessageQueueStore, queueScopeKey, type QueueItem, type QueueScope, type QueuedMessage } from '@/stores/messageQueueStore';
import { notifyConfirmedMessageSent, useSessionUIStore } from '@/sync/session-ui-store';
import { useSelectionStore } from '@/sync/selection-store';
import { useConfigStore } from '@/stores/useConfigStore';
import { useContextStore } from '@/stores/contextStore';
import { useAutoReviewStore } from '@/stores/useAutoReviewStore';
import { parseAgentMentions } from '@/lib/messages/agentMentions';
import { useChildStoreManager, useScopedSessionStatusReader, useScopedSessionStatusRevision } from '@/sync/sync-context';
import type { ScopedSessionStatus } from '@/sync/scoped-session-status';
import { getRuntimeGeneration, getRuntimeKey, getRuntimeTransportIdentity, subscribeRuntimeEndpointChanged } from '@/lib/runtime-switch';
import { fetchRecentSendConfirmationRecords, getSendFailureKind, releaseUnconfirmedQueueSend } from '@/sync/session-actions';
import { ascendingIdAfter } from '@/sync/message-id';
import { getSyncMessages } from '@/sync/sync-refs';
type SessionStatusType = ScopedSessionStatus;
const RETRY_BASE = 2000; const RETRY_MAX = 60000; const RECENT_ABORT_DELAY_MS = 2000; const RECONCILIATION_QUERY_DEADLINE_MS = 5000; const MAX_RECONCILIATION_CHECKS = 3;
export const getQueuedAutoSendRetryDelayMs = (failures: number) => Math.min(RETRY_BASE * 2 ** Math.max(failures - 1, 0), RETRY_MAX);
const dispatchFlights = new Map<string, Promise<void>>();
const dispatchFlightListeners = new Set<() => void>();
let dispatchFlightRevision = 0;
const notifyDispatchFlightChanged = () => {
  dispatchFlightRevision += 1;
  for (const listener of dispatchFlightListeners) listener();
};
const dispatchFlightKey = (scope: BoundScope, identity: Pick<QueueItem, 'queueItemID' | 'operationID'>) => JSON.stringify([queueScopeKey(scope), identity.queueItemID, identity.operationID]);
const getDispatchFlightKeys = () => new Set(dispatchFlights.keys());
const subscribeDispatchFlights = (listener: () => void) => {
  dispatchFlightListeners.add(listener);
  return () => dispatchFlightListeners.delete(listener);
};
type QueueHeadPlan = { dispatch?: boolean; query?: boolean; resolve?: boolean; recover?: boolean; nextWakeAt?: number };
const isAuthoritativeIdle = (status: SessionStatusType): boolean => status === 'idle';
export type QueueTurnState = 'settled' | 'unsettled' | 'unknown';
type QueueTurnMessage = { role?: string; time?: { created?: number; completed?: number } };
export const getTrailingQueueTurnState = (messages: readonly QueueTurnMessage[] | undefined): QueueTurnState => {
  if (messages === undefined) return 'unknown';
  const last = messages[messages.length - 1];
  if (!last) return 'settled';
  if (last.role === 'assistant' && typeof last.time?.completed === 'number') return 'settled';
  return 'unsettled';
};

export const planQueueHead = (item: QueueItem | undefined, status: SessionStatusType, _previous: SessionStatusType | undefined, now: number, isInFlight = false, turnState: QueueTurnState = 'settled'): QueueHeadPlan => {
  if (!item) return {};
  // Abandoned in-flight POSTs must re-enter reconciliation; v4 does the same.
  if (item.status === 'sending') return isInFlight ? {} : { recover: true };
  if (item.status === 'queued') return isAuthoritativeIdle(status) && turnState !== 'unsettled' ? { dispatch: true } : {};
  if (item.status === 'retrying') {
    if (item.nextAttemptAt && item.nextAttemptAt > now) return { nextWakeAt: item.nextAttemptAt };
    return isAuthoritativeIdle(status) && turnState !== 'unsettled' ? { dispatch: true } : {};
  }
  if (item.status === 'reconciling') {
    const persistedChecks = item.reconciliationChecks ?? 0;
    if (persistedChecks >= MAX_RECONCILIATION_CHECKS || (item.reconciliationDeadlineAt ?? Infinity) <= now) return { resolve: true };
    if ((item.reconciliationNextCheckAt ?? 0) > now) return { nextWakeAt: item.reconciliationNextCheckAt };
    return isInFlight ? {} : { query: true };
  }
  return {};
};
export const shouldDispatchQueuedAutoSend = (previous: SessionStatusType | undefined, current: SessionStatusType, hasQueuedItems = false) => Boolean(planQueueHead(hasQueuedItems ? ({ status: 'queued' } as QueueItem) : undefined, current, previous, Date.now()).dispatch);
type PersistedAutoReviewRun = { status?: string; runtimeKey?: string };
export const getAutoReviewBlockedSessions = (runsByOriginalSessionID: Record<string, PersistedAutoReviewRun | undefined>, activeRuntimeKey: string): Set<string> => {
  const blockedSessions = new Set<string>();
  for (const [sessionID, run] of Object.entries(runsByOriginalSessionID)) {
    if (run?.status === 'running' && run.runtimeKey === activeRuntimeKey) blockedSessions.add(sessionID);
  }
  return blockedSessions;
};

type BoundScope = Extract<QueueScope, { state: 'bound' }>;
type QueueDebugEvent = 'dispatch_prepared' | 'persistence_failed' | 'prompt_accepted' | 'prompt_failed' | 'confirmed' | 'reconcile_result';
const queueDebug = (event: QueueDebugEvent, fields: Record<string, unknown>) => console.info(`[queue-debug] ${event} ${JSON.stringify(fields)}`);
const latestMessageID = (sessionID: string, directory: string): string | undefined => {
  let latest: string | undefined;
  for (const message of getSyncMessages(sessionID, directory)) {
    const id = typeof message?.id === 'string' ? message.id : '';
    if (/^msg_[0-9a-f]{12}[0-9A-Za-z]{14}$/.test(id) && (!latest || id > latest)) latest = id;
  }
  return latest;
};
type QueryOperation = { scope: BoundScope; item: QueueItem; key: string };
type QueueSchedulerPlan = { dispatchScopes: BoundScope[]; queryOperations: QueryOperation[]; resolveOperations: QueryOperation[]; recoverOperations: QueryOperation[]; nextWakeAt?: number; inspectedScopeCount: number };
export const planQueueScheduler = ({ queuedMessages, activeTransportIdentity, getStatus, getTurnState = () => 'settled', previous, inFlight, dispatchInFlight = getDispatchFlightKeys(), blockedSessions, now }: { queuedMessages: Record<string, QueuedMessage[]>; activeTransportIdentity: string; getStatus: (scope: BoundScope) => SessionStatusType; getTurnState?: (scope: BoundScope) => QueueTurnState; previous: Map<string, SessionStatusType>; inFlight: Set<string>; dispatchInFlight?: Set<string>; blockedSessions: Set<string>; now: number }): QueueSchedulerPlan => {
  const plan: QueueSchedulerPlan = { dispatchScopes: [], queryOperations: [], resolveOperations: [], recoverOperations: [], inspectedScopeCount: 0 };
  const liveKeys = new Set<string>();
  for (const [scopeKey, queue] of Object.entries(queuedMessages)) {
    const item = queue[0] as QueueItem | undefined; const scope = item?.owner;
    if (!item || scope?.state !== 'bound' || scope.transportIdentity !== activeTransportIdentity) continue;
    plan.inspectedScopeCount += 1;
    const key = `${scopeKey}:${item.queueItemID}`; const dispatchKey = dispatchFlightKey(scope, item); liveKeys.add(key);
    const status = getStatus(scope); const headPlan = planQueueHead(item, status, previous.get(scopeKey), now, dispatchInFlight.has(dispatchKey), getTurnState(scope));
    previous.set(scopeKey, status);
    if (headPlan.nextWakeAt && (!plan.nextWakeAt || headPlan.nextWakeAt < plan.nextWakeAt)) plan.nextWakeAt = headPlan.nextWakeAt;
    if (headPlan.dispatch && !blockedSessions.has(scope.sessionID) && !dispatchInFlight.has(dispatchKey)) plan.dispatchScopes.push(scope);
    if (headPlan.query && !inFlight.has(key)) plan.queryOperations.push({ scope, item, key });
    if (headPlan.resolve) plan.resolveOperations.push({ scope, item, key });
    if (headPlan.recover && !inFlight.has(key)) plan.recoverOperations.push({ scope, item, key });
  }
  for (const key of inFlight) if (!liveKeys.has(key)) inFlight.delete(key);
  for (const key of previous.keys()) if (!queuedMessages[key]) previous.delete(key);
  return plan;
};

export const buildQueuedAutoSendPayload = (queue: QueuedMessage[]) => {
  const queued = queue[0]; if (!queued) return null;
  const { sanitizedText, mention } = parseAgentMentions(queued.content, useConfigStore.getState().getVisibleAgents());
  return { queuedMessageId: queued.id, messageID: queued.messageID, operationID: queued.operationID, primaryText: sanitizedText, primaryAttachments: queued.attachments ?? [], agentMentionName: mention?.name, sendConfig: queued.sendConfig };
};
type Payload = NonNullable<ReturnType<typeof buildQueuedAutoSendPayload>>;
type Resolved = { providerID: string; modelID: string; agent?: string; variant?: string };
export const sendQueuedAutoSendPayload = (sessionId: string, payload: Payload, resolved: Resolved, options: { directory: string; delivery?: 'steer'; onSendConfirmed?: (messageID: string) => void }) => useSessionUIStore.getState().sendMessage(payload.primaryText, resolved.providerID, resolved.modelID, resolved.agent, payload.primaryAttachments, payload.agentMentionName, undefined, resolved.variant, 'normal', { sessionId, directoryHint: options.directory, delivery: options.delivery, messageID: payload.messageID, preserveOptimisticOnAmbiguous: true, onSendConfirmed: options.onSendConfirmed });
const resolve = (sessionID: string, captured?: QueuedMessage['sendConfig']): Resolved => {
  const context = useContextStore.getState(); const config = useConfigStore.getState(); const selection = useSelectionStore.getState();
  const agent = captured?.agent ?? context.getSessionAgentSelection(sessionID) ?? context.getCurrentAgent(sessionID) ?? config.currentAgentName ?? undefined;
  const model = context.getAgentModelForSession(sessionID, agent ?? '') ?? context.getSessionModelSelection(sessionID);
  const providerID = captured?.providerID ?? model?.providerId ?? config.currentProviderId ?? selection.lastUsedProvider?.providerID ?? ''; const modelID = captured?.modelID ?? model?.modelId ?? config.currentModelId ?? selection.lastUsedProvider?.modelID ?? '';
  return { providerID, modelID, agent, variant: captured?.variant ?? selection.getAgentModelVariantForSession(sessionID, agent ?? '', providerID, modelID) };
};
export const queueScopeForSession = (sessionID: string): BoundScope | null => { const directory = useSessionUIStore.getState().getDirectoryForSession(sessionID); return directory ? { state: 'bound', transportIdentity: getRuntimeTransportIdentity(), directory, sessionID } : null; };

const canDispatchQueueStatus = (status: QueueItem['status'] | undefined, manual: boolean): boolean => {
  if (status === 'queued' || status === 'retrying') return true;
  if (manual && (status === 'failed' || status === 'unresolved')) return true;
  return false;
};

const findQueueHead = (store: ReturnType<typeof useMessageQueueStore.getState>, sessionID: string, queueItemID?: string, preferred?: BoundScope): { scope: BoundScope; item: QueueItem } | null => {
  if (!preferred || preferred.sessionID !== sessionID) return null;
  const head = store.getQueueForScope(preferred)[0] as QueueItem | undefined;
  if (!head || head.owner?.state !== 'bound' || queueScopeKey(head.owner) !== queueScopeKey(preferred)) return null;
  if (queueItemID && head.queueItemID !== queueItemID && head.id !== queueItemID) return null;
  return { scope: preferred, item: head };
};

export function dispatchQueuedMessage(sessionID: string, options: { delivery?: 'steer'; queueItemID?: string; scope?: BoundScope; manual?: boolean } = {}): Promise<void> {
  const store = useMessageQueueStore.getState();
  const preferred = options.scope ?? queueScopeForSession(sessionID);
  if (preferred && !options.scope) store.bindLegacyQueue({ state: 'unbound-legacy', sessionID }, preferred);
  const located = findQueueHead(store, sessionID, options.queueItemID, preferred ?? undefined);
  if (!located || located.scope.transportIdentity !== getRuntimeTransportIdentity()) return Promise.resolve();
  const scope = located.scope;
  let item = located.item;
  const manual = options.manual === true || options.delivery === 'steer';
  const identity = { queueItemID: item.queueItemID, operationID: item.operationID, messageID: item.messageID };
  const key = dispatchFlightKey(scope, identity); const existing = dispatchFlights.get(key);
  if (existing) return existing;
  if (!canDispatchQueueStatus(item.status, manual)) return Promise.resolve();
  if (item.status === 'retrying' && !manual && (item.nextAttemptAt ?? 0) > Date.now()) return Promise.resolve();
  let settle: (() => void) | undefined;
  const flight = new Promise<void>((resolve) => { settle = resolve; });
  dispatchFlights.set(key, flight);
  notifyDispatchFlightChanged();
  void (async () => {
    try {
      const floorMessageID = latestMessageID(sessionID, scope.directory);
      const freshMessageID = ascendingIdAfter('msg', floorMessageID);
      const ready = store.beginQueueItemDispatch(scope, identity as Required<typeof identity>, freshMessageID, manual);
      if (!ready) return;
      item = ready;
      const freshIdentity = { queueItemID: ready.queueItemID, operationID: ready.operationID, messageID: ready.messageID };
      queueDebug('dispatch_prepared', { timestamp: Date.now(), sessionID, queueItemID: ready.queueItemID, operationID: ready.operationID, messageID: ready.messageID, previousMessageID: identity.messageID, floorMessageID, status: ready.status });
      if (!flushMessageQueuePersistence()) {
        store.markQueueItemPreDispatchRetry(scope, freshIdentity, Date.now() + getQueuedAutoSendRetryDelayMs(ready.attemptCount + 1));
        queueDebug('persistence_failed', { timestamp: Date.now(), sessionID, queueItemID: ready.queueItemID, operationID: ready.operationID, messageID: ready.messageID, status: 'retrying', failureKind: 'pre-dispatch' });
        return;
      }
      const generation = getRuntimeGeneration(); const payload = buildQueuedAutoSendPayload([ready]); if (!payload) return;
      const resolved = resolve(sessionID, ready.sendConfig);
      if (!resolved.providerID || !resolved.modelID) {
        store.markQueueItemPreDispatchRetry(scope, freshIdentity, Date.now() + getQueuedAutoSendRetryDelayMs(ready.attemptCount + 1));
        return;
      }
      const confirmationMatches = () => { const current = useMessageQueueStore.getState().getQueueForScope(scope)[0] as QueueItem | undefined; return getRuntimeTransportIdentity() === scope.transportIdentity && getRuntimeGeneration() === generation && current?.queueItemID === freshIdentity.queueItemID && current.operationID === freshIdentity.operationID && current.messageID === freshIdentity.messageID && queueScopeKey(current.owner) === queueScopeKey(scope); };
      const failureMatches = () => { const current = useMessageQueueStore.getState().getQueueForScope(scope)[0] as QueueItem | undefined; return current?.queueItemID === freshIdentity.queueItemID && current.operationID === freshIdentity.operationID && current.messageID === freshIdentity.messageID && queueScopeKey(current.owner) === queueScopeKey(scope); };
      const confirm = (messageID: string) => { if (confirmationMatches() && messageID === freshIdentity.messageID) { useMessageQueueStore.getState().confirmQueueItem(scope, freshIdentity); queueDebug('confirmed', { timestamp: Date.now(), sessionID, queueItemID: freshIdentity.queueItemID, operationID: freshIdentity.operationID, messageID, status: 'confirmed' }); } };
      try { await sendQueuedAutoSendPayload(sessionID, payload, resolved, { directory: scope.directory, delivery: options.delivery, onSendConfirmed: confirm }); queueDebug('prompt_accepted', { timestamp: Date.now(), sessionID, queueItemID: freshIdentity.queueItemID, operationID: freshIdentity.operationID, messageID: freshIdentity.messageID, status: 'sending' }); confirm(freshIdentity.messageID); }
      catch (error) { if (!failureMatches()) return; const kind = getSendFailureKind(error); if (kind === 'pre-dispatch') store.markQueueItemPreDispatchRetry(scope, freshIdentity, Date.now() + getQueuedAutoSendRetryDelayMs(ready.attemptCount + 1)); else if (kind === 'definitive-rejection') store.markQueueItemDefinitiveFailure(scope, freshIdentity); else store.markQueueItemReconciling(scope, freshIdentity); queueDebug('prompt_failed', { timestamp: Date.now(), sessionID, queueItemID: freshIdentity.queueItemID, operationID: freshIdentity.operationID, messageID: freshIdentity.messageID, status: kind === 'pre-dispatch' ? 'retrying' : kind === 'definitive-rejection' ? 'failed' : 'reconciling', failureKind: kind }); }
    } finally {
      if (dispatchFlights.get(key) === flight) {
        dispatchFlights.delete(key);
        notifyDispatchFlightChanged();
      }
      settle?.();
    }
  })();
  return flight;
}

export async function reconcileQueuedMessage(operation: QueryOperation, generation = getRuntimeGeneration()): Promise<void> {
  const deadlineAt = Math.min(operation.item.reconciliationDeadlineAt ?? Infinity, Date.now() + RECONCILIATION_QUERY_DEADLINE_MS);
  const controller = new AbortController(); const timeout = setTimeout(() => controller.abort(), Math.max(0, deadlineAt - Date.now()));
  let records: Awaited<ReturnType<typeof fetchRecentSendConfirmationRecords>> = null;
  try { records = await fetchRecentSendConfirmationRecords(operation.scope.sessionID, operation.item.messageID, operation.scope.directory, { signal: controller.signal, timeoutMs: Math.max(0, deadlineAt - Date.now()) }); }
  catch { records = null; }
  finally { clearTimeout(timeout); }
  const current = useMessageQueueStore.getState().getQueueForScope(operation.scope)[0] as QueueItem | undefined;
  const matchesOperation = current?.queueItemID === operation.item.queueItemID
    && current.operationID === operation.item.operationID
    && current.messageID === operation.item.messageID
    && queueScopeKey(current.owner) === queueScopeKey(operation.scope)
    && getRuntimeTransportIdentity() === operation.scope.transportIdentity
    && getRuntimeGeneration() === generation;
  if (!matchesOperation) return;
  const matched = records?.some((record) => record.info.id === operation.item.messageID);
  if (matched) { notifyConfirmedMessageSent(operation.scope.sessionID, operation.item.messageID); useMessageQueueStore.getState().confirmQueueItem(operation.scope, { queueItemID: current.queueItemID, operationID: current.operationID, messageID: current.messageID }); queueDebug('reconcile_result', { timestamp: Date.now(), sessionID: operation.scope.sessionID, queueItemID: current.queueItemID, operationID: current.operationID, messageID: current.messageID, status: 'confirmed', checks: current.reconciliationChecks }); }
  else { useMessageQueueStore.getState().recordQueueItemReconciliationCheck(operation.scope, { queueItemID: operation.item.queueItemID, operationID: operation.item.operationID, messageID: operation.item.messageID }); queueDebug('reconcile_result', { timestamp: Date.now(), sessionID: operation.scope.sessionID, queueItemID: operation.item.queueItemID, operationID: operation.item.operationID, messageID: operation.item.messageID, status: 'reconciling', checks: (current.reconciliationChecks ?? 0) + 1 }); }
}

const releaseUnresolvedQueueHead = (scope: BoundScope, item: QueueItem) => {
  releaseUnconfirmedQueueSend({
    sessionID: scope.sessionID,
    messageID: item.messageID,
    directory: scope.directory,
  });
  useMessageQueueStore.getState().resolveQueueItemReconciliation(scope, {
    queueItemID: item.queueItemID,
    operationID: item.operationID,
    messageID: item.messageID,
  });
};

export function useQueuedMessageAutoSend(enabledOrOptions?: boolean | { enabled?: boolean }) {
  const enabled = typeof enabledOrOptions === 'boolean' ? enabledOrOptions : enabledOrOptions?.enabled ?? true;
  const queuedMessages = useMessageQueueStore((state) => state.queuedMessages); const runsByOriginalSessionID = useAutoReviewStore((state) => state.runsByOriginalSessionID);
  const activeTransportIdentity = React.useSyncExternalStore(
    subscribeRuntimeEndpointChanged,
    getRuntimeTransportIdentity,
    getRuntimeTransportIdentity,
  );
  const activeRuntimeKey = React.useSyncExternalStore(
    subscribeRuntimeEndpointChanged,
    getRuntimeKey,
    getRuntimeKey,
  );
  const dispatchFlightState = React.useSyncExternalStore(subscribeDispatchFlights, () => dispatchFlightRevision, () => dispatchFlightRevision);
  const scopes = React.useMemo(() => Object.values(queuedMessages).flatMap((queue) => { const owner = queue[0]?.owner; return owner?.state === 'bound' && owner.transportIdentity === activeTransportIdentity ? [owner] : []; }), [activeTransportIdentity, queuedMessages]);
  const statusRevision = useScopedSessionStatusRevision(scopes);
  const getScopedStatus = useScopedSessionStatusReader();
  const childStores = useChildStoreManager();
  const scopeKey = React.useMemo(() => scopes.map((scope) => `${scope.directory}\n${scope.sessionID}`).join('\u0000'), [scopes]);
  const scopesRef = React.useRef(scopes);
  scopesRef.current = scopes;
  const messageCompletionRevision = React.useSyncExternalStore(
    React.useCallback((notify: () => void) => {
      if (!scopeKey) return () => undefined;
      const unsubs: Array<() => void> = [];
      const seen = new Set<string>();
      for (const scope of scopesRef.current) {
        if (seen.has(scope.directory)) continue;
        seen.add(scope.directory);
        const store = childStores.getChild(scope.directory);
        if (!store) continue;
        unsubs.push(store.subscribe((state, previous) => {
          for (const entry of scopesRef.current) {
            if (entry.directory !== scope.directory) continue;
            if (state.message?.[entry.sessionID] !== previous.message?.[entry.sessionID]) {
              notify();
              return;
            }
          }
        }));
      }
      const unsubRegistry = childStores.subscribeRegistry(() => notify());
      return () => {
        unsubRegistry();
        for (const unsub of unsubs) unsub();
      };
    }, [childStores, scopeKey]),
    React.useCallback(() => {
      if (!scopeKey) return '';
      return scopesRef.current.map((scope) => {
        const messages = childStores.getChild(scope.directory)?.getState().message?.[scope.sessionID] as Array<{ id?: string; role?: string; time?: { completed?: number } }> | undefined;
        const last = messages?.[messages.length - 1];
        return `${scope.sessionID}:${last?.id ?? ''}:${last?.role ?? ''}:${last?.time?.completed ?? ''}`;
      }).join('\u0000');
    }, [childStores, scopeKey]),
    () => '',
  );
  const getStatus = React.useCallback((scope: BoundScope): SessionStatusType => {
    return getScopedStatus(scope);
  }, [getScopedStatus]);
  const getTurnState = React.useCallback((scope: BoundScope): QueueTurnState => {
    return getTrailingQueueTurnState(childStores.getChild(scope.directory)?.getState().message?.[scope.sessionID]);
  }, [childStores]);
  const [wake, setWake] = React.useState(0); const previous = React.useRef(new Map<string, SessionStatusType>()); const reconciliationInFlight = React.useRef(new Set<string>());
  React.useEffect(() => {
    if (!enabled) return; const now = Date.now(); const abortFlags = useSessionUIStore.getState().sessionAbortFlags; const blockedSessions = new Set<string>();
    for (const [sessionID, record] of abortFlags) if (now - record.timestamp < RECENT_ABORT_DELAY_MS) blockedSessions.add(sessionID);
    // A running auto-review pauses only its matching stable runtime. Legacy
    // unkeyed records allow drain so persisted history cannot strand a queue.
    for (const sessionID of getAutoReviewBlockedSessions(runsByOriginalSessionID, activeRuntimeKey)) blockedSessions.add(sessionID);
    const schedule = planQueueScheduler({ queuedMessages, activeTransportIdentity, getStatus, getTurnState, previous: previous.current, inFlight: reconciliationInFlight.current, blockedSessions, now });
    for (const operation of schedule.recoverOperations) {
      useMessageQueueStore.getState().markQueueItemReconciling(operation.scope, {
        queueItemID: operation.item.queueItemID,
        operationID: operation.item.operationID,
        messageID: operation.item.messageID,
      });
    }
    for (const scope of schedule.dispatchScopes) {
      const head = useMessageQueueStore.getState().getQueueForScope(scope)[0] as QueueItem | undefined;
      if (!head) continue;
      void dispatchQueuedMessage(scope.sessionID, { scope }).finally(() => {
        setWake((value) => value + 1);
      });
    }
    for (const operation of schedule.resolveOperations) releaseUnresolvedQueueHead(operation.scope, operation.item);
    for (const operation of schedule.queryOperations) {
      reconciliationInFlight.current.add(operation.key);
      const generation = getRuntimeGeneration();
      void reconcileQueuedMessage(operation, generation).finally(() => {
        reconciliationInFlight.current.delete(operation.key);
        setWake((value) => value + 1);
      });
    }
    let timer: ReturnType<typeof setTimeout> | undefined; if (schedule.nextWakeAt) timer = setTimeout(() => setWake((value) => value + 1), Math.max(0, schedule.nextWakeAt - Date.now())); return () => { if (timer) clearTimeout(timer); };
  }, [activeRuntimeKey, activeTransportIdentity, childStores, dispatchFlightState, enabled, queuedMessages, runsByOriginalSessionID, statusRevision, messageCompletionRevision, getStatus, getTurnState, wake]);
}
