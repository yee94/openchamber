import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';
import { createDeferredSafeJSONStorage } from './utils/safeStorage';
import type { AttachedFile } from './types/sessionTypes';
import { updateDesktopSettings } from '@/lib/persistence';
import { ascendingId } from '@/sync/message-id';
import { createUuid } from '@/lib/uuid';

export type FollowUpBehavior = 'steer' | 'queue';
export type QueueItemStatus = 'queued' | 'sending' | 'retrying' | 'reconciling' | 'unresolved' | 'failed';
type QueueFailureKind = 'pre-dispatch' | 'ambiguous-dispatch' | 'definitive';
export type QueueScope =
  | { state: 'bound'; transportIdentity: string; directory: string; sessionID: string }
  | { state: 'unbound-legacy'; sessionID: string };
export type QueueOwner = QueueScope;

export const legacyQueueScope = (sessionID: string): QueueScope => ({ state: 'unbound-legacy', sessionID });
export const queueScopeKey = (scope: QueueScope): string => scope.state === 'bound'
  ? `bound:${JSON.stringify([scope.transportIdentity, scope.directory, scope.sessionID])}`
  : `unbound-legacy:${JSON.stringify([scope.sessionID])}`;
export const getQueueForScope = (state: { queuedMessages: Record<string, QueuedMessage[]> }, scope: QueueScope): QueuedMessage[] => state.queuedMessages[queueScopeKey(scope)] ?? EMPTY_QUEUE;
const EMPTY_QUEUE: QueuedMessage[] = [];

type QueueRecoveryPayload = { content: string; attachments?: AttachedFile[]; sendConfig?: QueuedMessage['sendConfig'] };
export type QueueFailure = { kind: QueueFailureKind; recovery: QueueRecoveryPayload };
const RECONCILIATION_DEADLINE_MS = 30_000;
export const DEFAULT_FOLLOW_UP_BEHAVIOR: FollowUpBehavior = 'queue';
export const isFollowUpBehavior = (value: unknown): value is FollowUpBehavior => value === 'steer' || value === 'queue';
export const normalizeFollowUpBehavior = (value: unknown, legacyQueueModeEnabled?: boolean | null): FollowUpBehavior => {
  if (value === 'immediate') return 'steer';
  if (isFollowUpBehavior(value)) return value;
  return legacyQueueModeEnabled === false ? 'steer' : 'queue';
};

export interface QueuedMessage {
  id: string; queueItemID?: string; operationID?: string; messageID?: string; content: string; attachments?: AttachedFile[]; createdAt: number;
  sendConfig?: { providerID: string; modelID: string; agent?: string; variant?: string };
  owner?: QueueOwner; status?: QueueItemStatus; attemptCount?: number; nextAttemptAt?: number; failure?: QueueFailure;
  reconciliationStartedAt?: number; reconciliationDeadlineAt?: number; reconciliationChecks?: number; reconciliationNextCheckAt?: number;
}
export interface QueueItem extends QueuedMessage { queueItemID: string; operationID: string; messageID: string; owner: QueueOwner; status: QueueItemStatus; attemptCount: number }
type QueueAdmission = Omit<QueuedMessage, 'id' | 'queueItemID' | 'operationID' | 'messageID' | 'createdAt' | 'owner' | 'status' | 'attemptCount' | 'nextAttemptAt' | 'failure' | 'reconciliationStartedAt' | 'reconciliationDeadlineAt' | 'reconciliationChecks' | 'reconciliationNextCheckAt'>;
type QueueFailureInput = Omit<QueueFailure, 'recovery'> & { recovery?: QueueRecoveryPayload };
type Identity = { queueItemID: string; operationID: string; messageID?: string };

interface MessageQueueState { queuedMessages: Record<string, QueuedMessage[]>; followUpBehavior: FollowUpBehavior }
interface MessageQueueActions {
  addToQueue: (scope: QueueScope, message: QueueAdmission) => QueueItem;
  removeFromQueue: (scope: QueueScope, queueItemID: string, operationID: string | undefined) => void;
  reorderQueue: (scope: QueueScope, fromID: string, toID: string, operationID: string | undefined) => void;
  popToInput: (scope: QueueScope, queueItemID: string, operationID: string | undefined) => QueuedMessage | null;
  clearQueue: (scope: QueueScope) => void; clearAllQueues: () => void; setFollowUpBehavior: (behavior: FollowUpBehavior) => void;
  getQueueForScope: (scope: QueueScope) => QueuedMessage[];
  bindLegacyQueue: (legacyScope: QueueScope, targetScope: QueueScope) => QueueItem[];
  markQueueItemSendAttempt: (scope: QueueScope, identity: Identity) => void;
  markQueueItemPreDispatchRetry: (scope: QueueScope, identity: Identity, nextAttemptAt: number, failure?: QueueFailureInput) => void;
  markQueueItemReconciling: (scope: QueueScope, identity: Identity, failure?: QueueFailureInput) => void;
  recordQueueItemReconciliationCheck: (scope: QueueScope, identity: Required<Identity>) => void;
  resolveQueueItemReconciliation: (scope: QueueScope, identity: Required<Identity>) => void;
  markQueueItemDefinitiveFailure: (scope: QueueScope, identity: Identity, failure?: QueueFailureInput) => void;
  resetQueueItemForDispatch: (scope: QueueScope, identity: Identity) => void;
  beginQueueItemDispatch: (scope: QueueScope, expectedIdentity: Required<Identity>, freshMessageID: string, manual: boolean, now?: number) => QueueItem | null;
  confirmQueueItem: (scope: QueueScope, identity: { operationID?: string; messageID?: string; queueItemID?: string }) => void;
}
type Store = MessageQueueState & MessageQueueActions;
type Persisted = { queuedMessages?: Record<string, QueuedMessage[]>; followUpBehavior?: FollowUpBehavior; queueModeEnabled?: boolean };
const createID = (prefix: string) => `${prefix}-${createUuid()}`;
const recoveryFor = (item: QueuedMessage): QueueRecoveryPayload => ({ content: item.content, attachments: item.attachments, sendConfig: item.sendConfig });
const sameIdentity = (item: QueueItem, identity: Identity) => item.queueItemID === identity.queueItemID && item.operationID === identity.operationID && (!identity.messageID || item.messageID === identity.messageID);
const locked = (item: QueueItem) => item.status === 'sending' || item.status === 'reconciling';
const messageQueueStorage = createDeferredSafeJSONStorage<Pick<MessageQueueState, 'queuedMessages' | 'followUpBehavior'>>();
export const flushMessageQueuePersistence = (): boolean => messageQueueStorage?.flush() ?? true;

const reconciliationFields = (message: QueuedMessage, now = Date.now()) => ({
  reconciliationStartedAt: message.reconciliationStartedAt ?? now,
  reconciliationDeadlineAt: message.reconciliationDeadlineAt ?? (message.reconciliationStartedAt ?? now) + RECONCILIATION_DEADLINE_MS,
  reconciliationChecks: Math.max(0, Math.floor(message.reconciliationChecks ?? 0)),
});

const migrateItem = (sessionID: string, message: QueuedMessage, scope: QueueScope): QueueItem => {
  const queueItemID = message.queueItemID ?? (message.id || createID('queued'));
  const unownedAmbiguous = !message.owner && (message.status === 'sending' || message.status === 'reconciling');
  const status = unownedAmbiguous ? 'unresolved' : message.status === 'sending' ? 'reconciling' : message.status === 'retrying' || message.status === 'reconciling' || message.status === 'unresolved' || message.status === 'failed' ? message.status : 'queued';
  const messageID = typeof message.messageID === 'string' && message.messageID.startsWith('msg_') ? message.messageID : ascendingId('msg');
  return { ...message, id: queueItemID, queueItemID, operationID: message.operationID ?? createID('operation'), messageID, owner: scope, status, attemptCount: Math.max(0, Math.floor(message.attemptCount ?? 0)), ...(message.status === 'sending' || message.status === 'reconciling' ? reconciliationFields(message) : {}), ...(unownedAmbiguous || (status === 'reconciling' && message.status === 'sending') ? { failure: { kind: 'ambiguous-dispatch' as const, recovery: message.failure?.recovery ?? recoveryFor(message) } } : {}) };
};

export const migrateMessageQueueState = (persistedState: unknown): Pick<MessageQueueState, 'queuedMessages' | 'followUpBehavior'> => {
  const state = (persistedState ?? {}) as Persisted;
  const queues: Record<string, QueueItem[]> = {};
  for (const [key, queue] of Object.entries(state.queuedMessages ?? {})) {
    if (!Array.isArray(queue)) continue;
    let scope: QueueScope;
    if (key.startsWith('bound:') || key.startsWith('unbound-legacy:')) {
      const first = queue[0];
      const legacySessionID = key.startsWith('unbound-legacy:')
        ? (() => { try { const parsed = JSON.parse(key.slice('unbound-legacy:'.length)); return Array.isArray(parsed) && typeof parsed[0] === 'string' ? parsed[0] : key; } catch { return key; } })()
        : key;
      scope = first?.owner?.state === 'bound' ? first.owner : legacyQueueScope(first?.owner?.sessionID ?? legacySessionID);
    } else {
      scope = legacyQueueScope(key);
    }
    for (const item of queue) {
      const itemScope = item.owner?.state === 'bound' ? item.owner : scope;
      const itemKey = queueScopeKey(itemScope);
      (queues[itemKey] ??= []).push(migrateItem(itemScope.sessionID, item, itemScope));
    }
  }
  return { queuedMessages: queues, followUpBehavior: normalizeFollowUpBehavior(state.followUpBehavior, state.queueModeEnabled ?? null) };
};

const update = (set: (fn: (state: Store) => Store | Partial<Store>) => void, scope: QueueScope, identity: Identity, fn: (item: QueueItem) => QueueItem) => {
  const key = queueScopeKey(scope);
  set((state) => {
    const queue = state.queuedMessages[key]; const index = queue?.findIndex((item) => queueScopeKey((item as QueueItem).owner) === key && sameIdentity(item as QueueItem, identity)) ?? -1;
    if (index < 0 || !queue) return state;
    const next = fn(queue[index] as QueueItem); if (next === queue[index]) return state;
    const nextQueue = queue.slice(); nextQueue[index] = next;
    return { queuedMessages: { ...state.queuedMessages, [key]: nextQueue } };
  });
};

export const useMessageQueueStore = create<Store>()(devtools(persist((set, get) => ({
  queuedMessages: {}, followUpBehavior: DEFAULT_FOLLOW_UP_BEHAVIOR,
  addToQueue: (scope, message) => {
    const item: QueueItem = { ...message, id: createID('queued'), queueItemID: '', operationID: createID('operation'), messageID: ascendingId('msg'), createdAt: Date.now(), owner: scope, status: 'queued', attemptCount: 0 };
    item.queueItemID = item.id;
    const key = queueScopeKey(scope); set((state) => ({ queuedMessages: { ...state.queuedMessages, [key]: [...(state.queuedMessages[key] ?? []), item] } })); return item;
  },
  removeFromQueue: (scope, queueItemID, operationID) => { if (!operationID) return; const key = queueScopeKey(scope); set((state) => { const queue = state.queuedMessages[key]; const item = queue?.find((candidate) => (candidate.queueItemID === queueItemID || candidate.id === queueItemID) && candidate.operationID === operationID && queueScopeKey((candidate as QueueItem).owner) === key) as QueueItem | undefined; if (!item || locked(item)) return state; const next = queue!.filter((candidate) => candidate !== item); if (next.length) return { queuedMessages: { ...state.queuedMessages, [key]: next } }; const { [key]: removed, ...queuedMessages } = state.queuedMessages; void removed; return { queuedMessages }; }); },
  reorderQueue: (scope, fromID, toID, operationID) => { if (!operationID) return; const key = queueScopeKey(scope); set((state) => { const queue = state.queuedMessages[key]; const from = queue?.findIndex((item) => (item.id === fromID || item.queueItemID === fromID) && item.operationID === operationID && queueScopeKey((item as QueueItem).owner) === key) ?? -1; const to = queue?.findIndex((item) => (item.id === toID || item.queueItemID === toID) && queueScopeKey((item as QueueItem).owner) === key) ?? -1; if (!queue || from < 0 || to < 0 || from === to || locked(queue[from] as QueueItem) || locked(queue[to] as QueueItem)) return state; const next = queue.slice(); const [item] = next.splice(from, 1); next.splice(to, 0, item!); return { queuedMessages: { ...state.queuedMessages, [key]: next } }; }); },
  popToInput: (scope, id, operationID) => { if (!operationID) return null; const item = getQueueForScope(get(), scope).find((candidate) => (candidate.id === id || candidate.queueItemID === id) && candidate.operationID === operationID && queueScopeKey((candidate as QueueItem).owner) === queueScopeKey(scope)) as QueueItem | undefined; if (!item || locked(item)) return null; get().removeFromQueue(scope, item.queueItemID, item.operationID); return item; },
  clearQueue: (scope) => { const key = queueScopeKey(scope); set((state) => { const queue = state.queuedMessages[key]; if (!queue || queue.some((item) => locked(item as QueueItem))) return state; const { [key]: removed, ...queuedMessages } = state.queuedMessages; void removed; return { queuedMessages }; }); },
  clearAllQueues: () => set((state) => {
    const queuedMessages: Record<string, QueuedMessage[]> = {};
    let changed = false;
    for (const [key, queue] of Object.entries(state.queuedMessages)) {
      const retained = queue.filter((item) => locked(item as QueueItem));
      if (retained.length) queuedMessages[key] = retained;
      if (retained.length !== queue.length) changed = true;
    }
    return changed ? { queuedMessages } : state;
  }),
  setFollowUpBehavior: (behavior) => { set({ followUpBehavior: behavior }); void updateDesktopSettings({ followUpBehavior: behavior }); },
  getQueueForScope: (scope) => getQueueForScope(get(), scope),
  bindLegacyQueue: (legacy, target) => {
    if (legacy.state !== 'unbound-legacy' || target.state !== 'bound' || legacy.sessionID !== target.sessionID) return [];
    const legacyKey = queueScopeKey(legacy); const targetKey = queueScopeKey(target); let moved: QueueItem[] = [];
    set((state) => {
      const source = state.queuedMessages[legacyKey] as QueueItem[] | undefined;
      if (!source) return state;
      moved = source.filter((item) => !locked(item));
      if (moved.length === 0) return state;
      const remaining = source.filter(locked); const queuedMessages = { ...state.queuedMessages, [targetKey]: [...moved.map((item) => ({ ...item, owner: target })), ...(state.queuedMessages[targetKey] ?? [])] };
      if (remaining.length) queuedMessages[legacyKey] = remaining; else delete queuedMessages[legacyKey];
      return { queuedMessages };
    });
    return moved.map((item) => ({ ...item, owner: target }));
  },
  markQueueItemSendAttempt: (scope, identity) => update(set, scope, identity, (item) => item.status === 'queued' || (item.status === 'retrying' && (item.nextAttemptAt ?? 0) <= Date.now()) ? { ...item, status: 'sending', attemptCount: item.attemptCount + 1, nextAttemptAt: undefined, failure: undefined } : item),
  markQueueItemPreDispatchRetry: (scope, identity, nextAttemptAt, failure) => update(set, scope, identity, (item) => item.status === 'sending' ? { ...item, status: 'retrying', nextAttemptAt, failure: { kind: 'pre-dispatch', recovery: failure?.recovery ?? recoveryFor(item) } } : item),
  markQueueItemReconciling: (scope, identity, failure) => update(set, scope, identity, (item) => item.status === 'sending' ? { ...item, status: 'reconciling', nextAttemptAt: undefined, ...reconciliationFields(item), reconciliationNextCheckAt: undefined, failure: { kind: 'ambiguous-dispatch', recovery: failure?.recovery ?? recoveryFor(item) } } : item),
  recordQueueItemReconciliationCheck: (scope, identity) => update(set, scope, identity, (item) => item.status === 'reconciling' && sameIdentity(item, identity) ? { ...item, reconciliationChecks: (item.reconciliationChecks ?? 0) + 1, reconciliationNextCheckAt: Date.now() + 2000 } : item),
  resolveQueueItemReconciliation: (scope, identity) => update(set, scope, identity, (item) => item.status === 'reconciling' && sameIdentity(item, identity) ? { ...item, status: 'unresolved', nextAttemptAt: undefined } : item),
  markQueueItemDefinitiveFailure: (scope, identity, failure) => update(set, scope, identity, (item) => item.status === 'sending' ? { ...item, status: 'failed', nextAttemptAt: undefined, failure: { kind: 'definitive', recovery: failure?.recovery ?? recoveryFor(item) } } : item),
  resetQueueItemForDispatch: (scope, identity) => update(set, scope, identity, (item) => {
    if (item.status !== 'failed' && item.status !== 'unresolved' && item.status !== 'retrying') return item;
    return {
      ...item,
      status: 'queued',
      nextAttemptAt: undefined,
      failure: undefined,
      reconciliationStartedAt: undefined,
      reconciliationDeadlineAt: undefined,
      reconciliationChecks: undefined,
      reconciliationNextCheckAt: undefined,
    };
  }),
  beginQueueItemDispatch: (scope, expectedIdentity, freshMessageID, manual, now = Date.now()) => {
    if (!freshMessageID.startsWith('msg_')) return null;
    const key = queueScopeKey(scope);
    let dispatched: QueueItem | null = null;
    set((state) => {
      const queue = state.queuedMessages[key];
      const item = queue?.[0] as QueueItem | undefined;
      const eligible = item?.status === 'queued'
        || (item?.status === 'retrying' && (manual || (item.nextAttemptAt ?? 0) <= now))
        || (manual && (item?.status === 'failed' || item?.status === 'unresolved'));
      if (!item || queueScopeKey(item.owner) !== key || !sameIdentity(item, expectedIdentity) || !eligible) return state;
      dispatched = {
        ...item,
        messageID: freshMessageID,
        status: 'sending',
        attemptCount: item.attemptCount + 1,
        nextAttemptAt: undefined,
        failure: undefined,
        reconciliationStartedAt: undefined,
        reconciliationDeadlineAt: undefined,
        reconciliationChecks: undefined,
        reconciliationNextCheckAt: undefined,
      };
      const nextQueue = queue.slice();
      nextQueue[0] = dispatched;
      return { queuedMessages: { ...state.queuedMessages, [key]: nextQueue } };
    });
    return dispatched;
  },
  confirmQueueItem: (scope, identity) => { const key = queueScopeKey(scope); set((state) => { const queue = state.queuedMessages[key]; const item = queue?.find((candidate) => { const operationMatch = identity.operationID ? candidate.operationID === identity.operationID : true; const messageMatch = identity.messageID ? candidate.messageID === identity.messageID : true; const itemMatch = identity.queueItemID ? candidate.queueItemID === identity.queueItemID : true; return operationMatch && messageMatch && itemMatch; }); if (!item || (!identity.operationID && !identity.messageID)) return state; const next = queue!.filter((candidate) => candidate !== item); if (next.length) return { queuedMessages: { ...state.queuedMessages, [key]: next } }; const { [key]: removed, ...queuedMessages } = state.queuedMessages; void removed; return { queuedMessages }; }); },
}), { name: 'message-queue-store', version: 4, storage: messageQueueStorage, partialize: (state) => ({ queuedMessages: state.queuedMessages, followUpBehavior: state.followUpBehavior }), migrate: migrateMessageQueueState, merge: (persisted, current) => ({ ...current, ...migrateMessageQueueState(persisted) }) }), { name: 'message-queue-store' }));
