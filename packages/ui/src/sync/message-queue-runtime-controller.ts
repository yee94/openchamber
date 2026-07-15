import type { QueueItemDTO, QueueLedgerDetailedRead, QueueLedgerSnapshotV4 } from "@/stores/message-queue-ledger"
import { emptyQueueLedgerSnapshot, queueLedgerScopeKey } from "@/stores/message-queue-ledger"
import type { QueueAttachmentCoordinator, QueueAttachmentCoordinatorError, QueueAttachmentCoordinatorResult, QueueIdentity, QueueRuntime, QueueSendToken } from "./queue-attachment-coordinator"

export type MessageQueueRuntimeHydration = "idle" | "hydrating" | "ready" | "recovery-required" | "failed"
export type MessageQueueRuntimeIssue = QueueAttachmentCoordinatorError
export type MessageQueueRuntimeState = { hydration: MessageQueueRuntimeHydration; snapshot: QueueLedgerSnapshotV4; issues: readonly MessageQueueRuntimeIssue[]; enabled: boolean }
export type ScopedQueueIdentity = QueueIdentity & { scopeKey: string }
export type QueueRuntimeCapture = QueueRuntime
export type QueueTransitionStatus = QueueItemDTO["status"]
export type MessageQueueRuntimeResult = QueueAttachmentCoordinatorResult & { item?: QueueItemDTO; token?: QueueSendToken; values?: Awaited<ReturnType<QueueAttachmentCoordinator["acquireSendPayload"]>>["values"] }
export type MessageQueueRuntimeController = {
  subscribe: (listener: () => void) => () => void
  getState: () => MessageQueueRuntimeState
  captureRuntime: () => QueueRuntimeCapture
  hydrate: (source?: QueueLedgerSnapshotV4 | QueueLedgerDetailedRead | null) => Promise<MessageQueueRuntimeResult>
  flush: () => Promise<void>
  setEnabled: (enabled: boolean) => Promise<void>
  admit: (item: QueueItemDTO, resolve?: Parameters<QueueAttachmentCoordinator["admit"]>[2], capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  materializeForEdit: (identity: ScopedQueueIdentity, capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  remove: (identity: ScopedQueueIdentity, capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  reorder: (scopeKey: string, queueItemIDs: string[], capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  bind: (identity: ScopedQueueIdentity, owner: Extract<QueueItemDTO["owner"], { state: "bound" }>, capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  bindMany: (identities: readonly ScopedQueueIdentity[], owner: Extract<QueueItemDTO["owner"], { state: "bound" }>, capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  transition: (identity: ScopedQueueIdentity, expected: QueueTransitionStatus | readonly QueueTransitionStatus[], update: (item: QueueItemDTO) => QueueItemDTO, capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  confirm: (identity: ScopedQueueIdentity, capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  acquireSendPayload: (identity: ScopedQueueIdentity, capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  releaseSend: (identity: ScopedQueueIdentity, token: QueueSendToken, capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
}

const same = (left: unknown, right: unknown) => JSON.stringify(left) === JSON.stringify(right)
const result = (status: QueueAttachmentCoordinatorResult["status"], errors: QueueAttachmentCoordinatorError[] = []): MessageQueueRuntimeResult => ({ status, errors, cleanupErrors: [] })
const locked = (item: QueueItemDTO) => item.status === "sending" || item.status === "reconciling"

export const createMessageQueueRuntimeController = (coordinator: QueueAttachmentCoordinator, runtimeCapture: () => QueueRuntime, options: { enabled?: boolean } = {}): MessageQueueRuntimeController => {
  let state: MessageQueueRuntimeState = { hydration: "idle", snapshot: emptyQueueLedgerSnapshot(), issues: [], enabled: options.enabled ?? true }
  let hydration: Promise<MessageQueueRuntimeResult> | undefined
  let tail = Promise.resolve()
  const listeners = new Set<() => void>()
  const publish = (next: MessageQueueRuntimeState) => { state = next; listeners.forEach((listener) => listener()) }
  const adopt = (next: QueueLedgerSnapshotV4) => {
    const queues: Record<string, QueueItemDTO[]> = {}
    for (const [key, value] of Object.entries(next.queues)) queues[key] = same(state.snapshot.queues[key], value) ? state.snapshot.queues[key]! : value
    const snapshot = same(state.snapshot.queues, queues) && same(state.snapshot.migration, next.migration) ? state.snapshot : { ...next, queues }
    publish({ ...state, snapshot })
  }
  const serialize = <T>(work: () => Promise<T>) => { const next = tail.then(work, work); tail = next.then(() => undefined, () => undefined); return next }
  const find = (identity: ScopedQueueIdentity) => {
    const item = state.snapshot.queues[identity.scopeKey]?.find((entry) => entry.queueItemID === identity.queueItemID && entry.operationID === identity.operationID && entry.messageID === identity.messageID)
    return item && queueLedgerScopeKey(item.owner) === identity.scopeKey ? item : undefined
  }
  const available = (): MessageQueueRuntimeResult | undefined => state.hydration === "idle" || state.hydration === "hydrating" ? result("unseeded") : state.hydration === "recovery-required" ? result("recovery-required", [...state.issues]) : state.hydration === "failed" ? result("failed", [...state.issues]) : undefined
  const commit = async (work: () => Promise<QueueAttachmentCoordinatorResult>): Promise<MessageQueueRuntimeResult> => {
    const before = state.snapshot, committed = await work()
    if (committed.status === "committed") adopt(coordinator.getSnapshot())
    if (committed.status === "committed" && committed.current === false) return { ...committed, status: "stale" }
    if (committed.status !== "committed" && state.snapshot !== before) publish({ ...state, snapshot: before })
    return committed
  }
  const captureRuntime = (): QueueRuntimeCapture => runtimeCapture()
  const boundMatches = (item: QueueItemDTO, capture: QueueRuntimeCapture) => item.owner.state !== "bound" || item.owner.transportIdentity === capture.transportIdentity
  return {
    subscribe: (listener) => { listeners.add(listener); return () => listeners.delete(listener) },
    getState: () => state,
    captureRuntime,
    hydrate: (source) => hydration ??= serialize(async () => {
      publish({ ...state, hydration: "hydrating" }); const loaded = await coordinator.hydrate(source)
      const issues = loaded.errors.map((entry) => ({ phase: entry.phase, code: entry.code, scopeKey: entry.scopeKey, path: entry.path }))
      const hydrationState: MessageQueueRuntimeHydration = loaded.status === "committed" || loaded.status === "disabled" ? "ready" : loaded.status === "recovery-required" ? "recovery-required" : "failed"
      adopt(coordinator.getSnapshot()); publish({ ...state, hydration: hydrationState, issues, enabled: state.enabled }); return loaded
    }).finally(() => { hydration = undefined }),
    flush: () => serialize(() => coordinator.flush()),
    setEnabled: (enabled) => serialize(async () => { await coordinator.setEnabled(enabled); publish({ ...state, enabled }) }),
    admit: (item, resolve, captured = captureRuntime()) => serialize(async () => { const gate = available(); if (gate) return gate; if (!boundMatches(item, captured)) return result("stale"); return commit(() => coordinator.admit(item, captured, resolve)) }),
    materializeForEdit: (identity, captured = captureRuntime()) => serialize(async () => { const gate = available(), item = find(identity); if (gate) return gate; if (!item || !boundMatches(item, captured)) return result("stale"); if (locked(item)) return result("failed", [{ phase: "identity", code: "locked" }]); const payload = await coordinator.acquireSendPayload(identity, captured); if (payload.status !== "committed" || !payload.token) return payload.status === "committed" ? result("failed", [{ phase: "identity", code: "missing-send-token" }]) : payload; const released = await coordinator.releaseSend(identity, payload.token, captured); return released.status === "committed" ? { ...payload, item: JSON.parse(JSON.stringify(item)) } : released }),
    remove: (identity, captured = captureRuntime()) => serialize(async () => { const gate = available(), item = find(identity); if (gate) return gate; if (!item || !boundMatches(item, captured)) return result("stale"); if (locked(item)) return result("failed", [{ phase: "identity", code: "locked" }]); return commit(() => coordinator.remove(identity, captured)) }),
    reorder: (scopeKey, ids, captured = captureRuntime()) => serialize(async () => { const gate = available(), queue = state.snapshot.queues[scopeKey]; if (gate) return gate; if (!queue || queue.some((item) => locked(item) || !boundMatches(item, captured))) return result("failed", [{ phase: "identity", code: "locked" }]); return commit(() => coordinator.reorder(scopeKey, ids, captured)) }),
    bind: (identity, owner, captured = captureRuntime()) => serialize(async () => { const gate = available(), item = find(identity); if (gate) return gate; if (!item || owner.transportIdentity !== captured.transportIdentity || !boundMatches(item, captured)) return result("stale"); if (locked(item)) return result("failed", [{ phase: "identity", code: "locked" }]); return commit(() => coordinator.bind(identity, owner, captured)) }),
    bindMany: (identities, owner, captured = captureRuntime()) => serialize(async () => { const gate = available(), items = identities.map(find); if (gate) return gate; if (!items.length || items.some((item) => !item || locked(item) || !boundMatches(item, captured)) || owner.transportIdentity !== captured.transportIdentity) return result("stale"); return commit(() => coordinator.bindMany(identities, owner, captured)) }),
    transition: (identity, expected, update, captured = captureRuntime()) => serialize(async () => { const gate = available(), item = find(identity); if (gate) return gate; if (!item || !boundMatches(item, captured)) return result("stale"); if (!(Array.isArray(expected) ? expected : [expected]).includes(item.status)) return result("stale"); return commit(() => coordinator.transition(identity, update, captured)) }),
    confirm: (identity, captured = captureRuntime()) => serialize(async () => { const gate = available(), item = find(identity); if (gate) return gate; if (!item || !boundMatches(item, captured)) return result("stale"); return commit(() => coordinator.remove(identity, captured)) }),
    acquireSendPayload: (identity, captured = captureRuntime()) => serialize(async () => { const gate = available(), item = find(identity); if (gate) return gate; if (!item || !boundMatches(item, captured)) return result("stale"); return coordinator.acquireSendPayload(identity, captured) }),
    releaseSend: (identity, token, captured = captureRuntime()) => serialize(async () => coordinator.releaseSend(identity, token, captured)),
  }
}
