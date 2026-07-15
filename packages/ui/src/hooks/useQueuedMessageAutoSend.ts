import React from 'react';
import { useMessageQueueStore, queueScopeKey, type QueueItem, type QueueScope, type QueuedMessage } from '@/stores/messageQueueStore';
import { notifyConfirmedMessageSent, useSessionUIStore } from '@/sync/session-ui-store';
import { useSelectionStore } from '@/sync/selection-store';
import { useConfigStore } from '@/stores/useConfigStore';
import { useContextStore } from '@/stores/contextStore';
import { useAutoReviewStore } from '@/stores/useAutoReviewStore';
import { parseAgentMentions } from '@/lib/messages/agentMentions';
import { useScopedSessionStatusReader, useScopedSessionStatusRevision } from '@/sync/sync-context';
import type { ScopedSessionStatus } from '@/sync/scoped-session-status';
import { getRuntimeGeneration, getRuntimeTransportIdentity, subscribeRuntimeEndpointChanged } from '@/lib/runtime-switch';
import { fetchRecentSendConfirmationRecords, getSendFailureKind } from '@/sync/session-actions';
type SessionStatusType = ScopedSessionStatus;
const RETRY_BASE = 2000; const RETRY_MAX = 60000; const RECENT_ABORT_DELAY_MS = 2000; const RECONCILIATION_QUERY_DEADLINE_MS = 5000; const MAX_RECONCILIATION_CHECKS = 3;
export const getQueuedAutoSendRetryDelayMs = (failures: number) => Math.min(RETRY_BASE * 2 ** Math.max(failures - 1, 0), RETRY_MAX);
type QueueHeadPlan = { dispatch?: boolean; query?: boolean; resolve?: boolean; nextWakeAt?: number };
export const planQueueHead = (item: QueueItem | undefined, status: SessionStatusType, _previous: SessionStatusType | undefined, now: number, isInFlight = false): QueueHeadPlan => {
  if (!item) return {};
  if (item.status === 'sending') return {};
  if (item.status === 'queued') return status === 'idle' ? { dispatch: true } : {};
  if (item.status === 'retrying') return status !== 'idle' ? {} : item.nextAttemptAt && item.nextAttemptAt > now ? { nextWakeAt: item.nextAttemptAt } : { dispatch: true };
  if (item.status === 'reconciling') {
    const persistedChecks = item.reconciliationChecks ?? 0;
    if (persistedChecks >= MAX_RECONCILIATION_CHECKS || (item.reconciliationDeadlineAt ?? Infinity) <= now) return { resolve: true };
    if ((item.reconciliationNextCheckAt ?? 0) > now) return { nextWakeAt: item.reconciliationNextCheckAt };
    return isInFlight ? {} : { query: true };
  }
  return {};
};
export const shouldDispatchQueuedAutoSend = (previous: SessionStatusType | undefined, current: SessionStatusType, hasQueuedItems = false) => Boolean(planQueueHead(hasQueuedItems ? ({ status: 'queued' } as QueueItem) : undefined, current, previous, Date.now()).dispatch);

type BoundScope = Extract<QueueScope, { state: 'bound' }>;
type QueryOperation = { scope: BoundScope; item: QueueItem; key: string };
type QueueSchedulerPlan = { dispatchScopes: BoundScope[]; queryOperations: QueryOperation[]; resolveOperations: QueryOperation[]; nextWakeAt?: number; inspectedScopeCount: number };
export const planQueueScheduler = ({ queuedMessages, activeTransportIdentity, getStatus, previous, inFlight, blockedSessions, now }: { queuedMessages: Record<string, QueuedMessage[]>; activeTransportIdentity: string; getStatus: (scope: BoundScope) => SessionStatusType; previous: Map<string, SessionStatusType>; inFlight: Set<string>; blockedSessions: Set<string>; now: number }): QueueSchedulerPlan => {
  const plan: QueueSchedulerPlan = { dispatchScopes: [], queryOperations: [], resolveOperations: [], inspectedScopeCount: 0 };
  const liveKeys = new Set<string>();
  for (const [scopeKey, queue] of Object.entries(queuedMessages)) {
    const item = queue[0] as QueueItem | undefined; const scope = item?.owner;
    if (!item || scope?.state !== 'bound' || scope.transportIdentity !== activeTransportIdentity) continue;
    plan.inspectedScopeCount += 1;
    const key = `${scopeKey}:${item.queueItemID}`; liveKeys.add(key);
    const status = getStatus(scope); const headPlan = planQueueHead(item, status, previous.get(scopeKey), now, inFlight.has(key));
    previous.set(scopeKey, status);
    if (headPlan.nextWakeAt && (!plan.nextWakeAt || headPlan.nextWakeAt < plan.nextWakeAt)) plan.nextWakeAt = headPlan.nextWakeAt;
    if (headPlan.dispatch && !blockedSessions.has(scope.sessionID)) plan.dispatchScopes.push(scope);
    if (headPlan.query && !inFlight.has(key)) plan.queryOperations.push({ scope, item, key });
    if (headPlan.resolve) plan.resolveOperations.push({ scope, item, key });
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
export const sendQueuedAutoSendPayload = (sessionId: string, payload: Payload, resolved: Resolved, options?: { delivery?: 'steer'; onSendConfirmed?: (messageID: string) => void }) => useSessionUIStore.getState().sendMessage(payload.primaryText, resolved.providerID, resolved.modelID, resolved.agent, payload.primaryAttachments, payload.agentMentionName, undefined, resolved.variant, 'normal', { sessionId, delivery: options?.delivery, messageID: payload.messageID, preserveOptimisticOnAmbiguous: true, onSendConfirmed: options?.onSendConfirmed });
const resolve = (sessionID: string, captured?: QueuedMessage['sendConfig']): Resolved => {
  const context = useContextStore.getState(); const config = useConfigStore.getState(); const selection = useSelectionStore.getState();
  const agent = captured?.agent ?? context.getSessionAgentSelection(sessionID) ?? context.getCurrentAgent(sessionID) ?? config.currentAgentName ?? undefined;
  const model = context.getAgentModelForSession(sessionID, agent ?? '') ?? context.getSessionModelSelection(sessionID);
  const providerID = captured?.providerID ?? model?.providerId ?? config.currentProviderId ?? selection.lastUsedProvider?.providerID ?? ''; const modelID = captured?.modelID ?? model?.modelId ?? config.currentModelId ?? selection.lastUsedProvider?.modelID ?? '';
  return { providerID, modelID, agent, variant: captured?.variant ?? selection.getAgentModelVariantForSession(sessionID, agent ?? '', providerID, modelID) };
};
export const queueScopeForSession = (sessionID: string): BoundScope | null => { const directory = useSessionUIStore.getState().getDirectoryForSession(sessionID); return directory ? { state: 'bound', transportIdentity: getRuntimeTransportIdentity(), directory, sessionID } : null; };

export async function dispatchQueuedMessage(sessionID: string, options: { delivery?: 'steer'; queueItemID?: string; scope?: BoundScope } = {}): Promise<void> {
  const scope = options.scope ?? queueScopeForSession(sessionID); if (!scope || scope.sessionID !== sessionID || scope.transportIdentity !== getRuntimeTransportIdentity()) return;
  const store = useMessageQueueStore.getState();
  if (!options.scope) store.bindLegacyQueue({ state: 'unbound-legacy', sessionID }, scope);
  const item = store.getQueueForScope(scope)[0] as QueueItem | undefined;
  if (!item || queueScopeKey(item.owner) !== queueScopeKey(scope) || (options.queueItemID && item.queueItemID !== options.queueItemID) || (item.status !== 'queued' && !(item.status === 'retrying' && (item.nextAttemptAt ?? 0) <= Date.now()))) return;
  const identity = { queueItemID: item.queueItemID, operationID: item.operationID, messageID: item.messageID }; const generation = getRuntimeGeneration(); const payload = buildQueuedAutoSendPayload([item]); if (!payload) return;
  const resolved = resolve(sessionID, item.sendConfig); if (!resolved.providerID || !resolved.modelID) return;
  store.markQueueItemSendAttempt(scope, identity);
  const confirmationMatches = () => { const current = useMessageQueueStore.getState().getQueueForScope(scope)[0] as QueueItem | undefined; return getRuntimeTransportIdentity() === scope.transportIdentity && getRuntimeGeneration() === generation && current?.queueItemID === identity.queueItemID && current.operationID === identity.operationID && current.messageID === identity.messageID && queueScopeKey(current.owner) === queueScopeKey(scope); };
  const failureMatches = () => { const current = useMessageQueueStore.getState().getQueueForScope(scope)[0] as QueueItem | undefined; return current?.queueItemID === identity.queueItemID && current.operationID === identity.operationID && current.messageID === identity.messageID && queueScopeKey(current.owner) === queueScopeKey(scope); };
  const confirm = (messageID: string) => { if (confirmationMatches() && messageID === identity.messageID) useMessageQueueStore.getState().confirmQueueItem(scope, identity); };
  try { await sendQueuedAutoSendPayload(sessionID, payload, resolved, { delivery: options.delivery, onSendConfirmed: confirm }); confirm(identity.messageID); }
  catch (error) { if (!failureMatches()) return; const kind = getSendFailureKind(error); if (kind === 'pre-dispatch') store.markQueueItemPreDispatchRetry(scope, identity, Date.now() + getQueuedAutoSendRetryDelayMs(item.attemptCount + 1)); else if (kind === 'definitive-rejection') store.markQueueItemDefinitiveFailure(scope, identity); else store.markQueueItemReconciling(scope, identity); }
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
  if (matched) { notifyConfirmedMessageSent(operation.scope.sessionID, operation.item.messageID); useMessageQueueStore.getState().confirmQueueItem(operation.scope, { queueItemID: current.queueItemID, operationID: current.operationID, messageID: current.messageID }); }
  else useMessageQueueStore.getState().recordQueueItemReconciliationCheck(operation.scope, { queueItemID: operation.item.queueItemID, operationID: operation.item.operationID, messageID: operation.item.messageID });
}

export function useQueuedMessageAutoSend(enabledOrOptions?: boolean | { enabled?: boolean }) {
  const enabled = typeof enabledOrOptions === 'boolean' ? enabledOrOptions : enabledOrOptions?.enabled ?? true;
  const queuedMessages = useMessageQueueStore((state) => state.queuedMessages); const runsByOriginalSessionID = useAutoReviewStore((state) => state.runsByOriginalSessionID);
  const activeTransportIdentity = getRuntimeTransportIdentity();
  const scopes = React.useMemo(() => Object.values(queuedMessages).flatMap((queue) => { const owner = queue[0]?.owner; return owner?.state === 'bound' && owner.transportIdentity === activeTransportIdentity ? [owner] : []; }), [activeTransportIdentity, queuedMessages]);
  const statusRevision = useScopedSessionStatusRevision(scopes);
  const getScopedStatus = useScopedSessionStatusReader();
  const [wake, setWake] = React.useState(0); const previous = React.useRef(new Map<string, SessionStatusType>()); const inFlight = React.useRef(new Set<string>());
  React.useEffect(() => subscribeRuntimeEndpointChanged(() => setWake((value) => value + 1)), []);
  React.useEffect(() => {
    if (!enabled) return; const now = Date.now(); const abortFlags = useSessionUIStore.getState().sessionAbortFlags; const blockedSessions = new Set<string>();
    for (const [sessionID, record] of abortFlags) if (now - record.timestamp < RECENT_ABORT_DELAY_MS) blockedSessions.add(sessionID);
    for (const [sessionID, run] of Object.entries(runsByOriginalSessionID)) if (run) blockedSessions.add(sessionID);
    const schedule = planQueueScheduler({ queuedMessages, activeTransportIdentity, getStatus: getScopedStatus, previous: previous.current, inFlight: inFlight.current, blockedSessions, now });
    for (const scope of schedule.dispatchScopes) void dispatchQueuedMessage(scope.sessionID, { scope });
    for (const operation of schedule.resolveOperations) useMessageQueueStore.getState().resolveQueueItemReconciliation(operation.scope, { queueItemID: operation.item.queueItemID, operationID: operation.item.operationID, messageID: operation.item.messageID });
    for (const operation of schedule.queryOperations) {
      inFlight.current.add(operation.key);
      const generation = getRuntimeGeneration();
      void reconcileQueuedMessage(operation, generation).finally(() => { inFlight.current.delete(operation.key); });
    }
    let timer: ReturnType<typeof setTimeout> | undefined; if (schedule.nextWakeAt) timer = setTimeout(() => setWake((value) => value + 1), Math.max(0, schedule.nextWakeAt - Date.now())); return () => { if (timer) clearTimeout(timer); };
  }, [activeTransportIdentity, enabled, queuedMessages, runsByOriginalSessionID, statusRevision, getScopedStatus, wake]);
}
