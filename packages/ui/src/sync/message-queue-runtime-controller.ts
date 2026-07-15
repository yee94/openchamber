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
export type MessageQueueRemoveResult = MessageQueueRuntimeResult & { durableRemoval: boolean }
export type MessageQueueRuntimeController = {
  subscribe: (listener: () => void) => () => void
  getState: () => MessageQueueRuntimeState
  captureRuntime: () => QueueRuntimeCapture
  hydrate: (source?: QueueLedgerSnapshotV4 | QueueLedgerDetailedRead | null) => Promise<MessageQueueRuntimeResult>
  flush: () => Promise<void>
  setEnabled: (enabled: boolean) => Promise<void>
  admit: (item: QueueItemDTO, resolve?: Parameters<QueueAttachmentCoordinator["admit"]>[2], capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  materializeForEdit: (identity: ScopedQueueIdentity, capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  releaseEditReservation: (identity: ScopedQueueIdentity, token: QueueSendToken, capture?: QueueRuntimeCapture) => Promise<MessageQueueRuntimeResult>
  removeEditReservation: (identity: ScopedQueueIdentity, token: QueueSendToken, capture?: QueueRuntimeCapture) => Promise<MessageQueueRemoveResult>
  remove: (identity: ScopedQueueIdentity, capture?: QueueRuntimeCapture) => Promise<MessageQueueRemoveResult>
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
  const reservations = new Map<string, { token: QueueSendToken; runtime: QueueRuntimeCapture }>()
  const reservationKey = (identity: ScopedQueueIdentity) => `${identity.scopeKey}\u0000${identity.queueItemID}\u0000${identity.operationID}\u0000${identity.messageID}`
  const reserved = (identity: ScopedQueueIdentity) => reservations.has(reservationKey(identity))
  const reservedResult = (): MessageQueueRuntimeResult => result("failed", [{ phase: "identity", code: "reserved" }])
  const sameCapture = (left: QueueRuntimeCapture, right: QueueRuntimeCapture) => left.transportIdentity === right.transportIdentity && left.generation === right.generation
  const releaseReservations = async () => {
    for (const [key, reservation] of reservations) {
      const [, queueItemID, operationID, messageID] = key.split("\u0000")
      try {
        const released = await coordinator.releaseSend({ queueItemID: queueItemID!, operationID: operationID!, messageID: messageID! }, reservation.token, reservation.runtime)
        if (released.status !== "stale") reservations.delete(key)
      } catch { reservations.delete(key) }
    }
  }
  return {
    subscribe: (listener) => { listeners.add(listener); return () => listeners.delete(listener) },
    getState: () => state,
    captureRuntime,
    hydrate: (source) => hydration ??= serialize(async () => {
      await releaseReservations(); publish({ ...state, hydration: "hydrating" }); const loaded = await coordinator.hydrate(source)
      const issues = loaded.errors.map((entry) => ({ phase: entry.phase, code: entry.code, scopeKey: entry.scopeKey, path: entry.path }))
      const hydrationState: MessageQueueRuntimeHydration = loaded.status === "committed" || loaded.status === "disabled" ? "ready" : loaded.status === "recovery-required" ? "recovery-required" : "failed"
      adopt(coordinator.getSnapshot()); publish({ ...state, hydration: hydrationState, issues, enabled: state.enabled }); return loaded
    }).finally(() => { hydration = undefined }),
    flush: () => serialize(() => coordinator.flush()),
    setEnabled: (enabled) => serialize(async () => { if (!enabled) await releaseReservations(); await coordinator.setEnabled(enabled); publish({ ...state, enabled }) }),
    admit: (item, resolve, captured = captureRuntime()) => serialize(async () => { const gate = available(); if (gate) return gate; if (!boundMatches(item, captured)) return result("stale"); return commit(() => coordinator.admit(item, captured, resolve)) }),
    materializeForEdit: (identity, captured = captureRuntime()) => serialize(async () => { const gate = available(), item = find(identity); if (gate) return gate; if (!item || !boundMatches(item, captured)) return result("stale"); if (locked(item)) return result("failed", [{ phase: "identity", code: "locked" }]); if (reserved(identity)) return reservedResult(); const payload = await coordinator.acquireSendPayload(identity, captured); if (payload.status !== "committed" || !payload.token) return payload.status === "committed" ? result("failed", [{ phase: "identity", code: "missing-send-token" }]) : payload; reservations.set(reservationKey(identity), { token: payload.token, runtime: captured }); return { ...payload, item: JSON.parse(JSON.stringify(item)), values: payload.values?.map(({ attachment, value }) => ({ attachment: JSON.parse(JSON.stringify(attachment)), value })) } }),
    releaseEditReservation: (identity, token, captured = captureRuntime()) => serialize(async () => { const key = reservationKey(identity), reservation = reservations.get(key); if (!reservation || reservation.token !== token || !sameCapture(reservation.runtime, captured)) return result("stale"); try { const released = await coordinator.releaseSend(identity, token, captured); if (released.status !== "stale") reservations.delete(key); return released } catch { reservations.delete(key); return result("failed", [{ phase: "runtime", code: "reservation-release-threw" }]) } }),
    removeEditReservation: (identity, token, captured = captureRuntime()) => serialize(async (): Promise<MessageQueueRemoveResult> => { const key = reservationKey(identity), reservation = reservations.get(key), gate = available(), item = find(identity); if (gate) return { ...gate, durableRemoval: false }; if (!reservation || reservation.token !== token || !sameCapture(reservation.runtime, captured) || !item || !boundMatches(item, captured)) return { ...result("stale"), durableRemoval: false }; if (locked(item)) return { ...result("failed", [{ phase: "identity", code: "locked" }]), durableRemoval: false }; const before = state.snapshot, committed = await coordinator.remove(identity, captured), durableRemoval = committed.status === "committed"; if (durableRemoval) { reservations.delete(key); adopt(coordinator.getSnapshot()) }; if (durableRemoval && committed.current === false) return { ...committed, status: "stale", durableRemoval }; if (!durableRemoval && state.snapshot !== before) publish({ ...state, snapshot: before }); return { ...committed, durableRemoval } }),
    remove: (identity, captured = captureRuntime()) => serialize(async (): Promise<MessageQueueRemoveResult> => {
      const gate = available(), item = find(identity)
      if (gate) return { ...gate, durableRemoval: false }
      if (!item || !boundMatches(item, captured)) return { ...result("stale"), durableRemoval: false }
      if (reserved(identity)) return { ...reservedResult(), durableRemoval: false }
      if (locked(item)) return { ...result("failed", [{ phase: "identity", code: "locked" }]), durableRemoval: false }
      const before = state.snapshot, committed = await coordinator.remove(identity, captured)
      const durableRemoval = committed.status === "committed"
      if (durableRemoval) adopt(coordinator.getSnapshot())
      if (durableRemoval && committed.current === false) return { ...committed, status: "stale", durableRemoval }
      if (!durableRemoval && state.snapshot !== before) publish({ ...state, snapshot: before })
      return { ...committed, durableRemoval }
    }),
    reorder: (scopeKey, ids, captured = captureRuntime()) => serialize(async () => { const gate = available(), queue = state.snapshot.queues[scopeKey]; if (gate) return gate; if (!queue) return result("failed", [{ phase: "identity", code: "locked" }]); if (queue.some((item) => reserved({ scopeKey, queueItemID: item.queueItemID, operationID: item.operationID, messageID: item.messageID }))) return reservedResult(); if (queue.some((item) => locked(item) || !boundMatches(item, captured))) return result("failed", [{ phase: "identity", code: "locked" }]); return commit(() => coordinator.reorder(scopeKey, ids, captured)) }),
    bind: (identity, owner, captured = captureRuntime()) => serialize(async () => { const gate = available(), item = find(identity); if (gate) return gate; if (!item || owner.transportIdentity !== captured.transportIdentity || !boundMatches(item, captured)) return result("stale"); if (reserved(identity)) return reservedResult(); if (locked(item)) return result("failed", [{ phase: "identity", code: "locked" }]); return commit(() => coordinator.bind(identity, owner, captured)) }),
    bindMany: (identities, owner, captured = captureRuntime()) => serialize(async () => { const gate = available(), items = identities.map(find); if (gate) return gate; if (identities.some(reserved)) return reservedResult(); if (!items.length || items.some((item) => !item || locked(item) || !boundMatches(item, captured)) || owner.transportIdentity !== captured.transportIdentity) return result("stale"); return commit(() => coordinator.bindMany(identities, owner, captured)) }),
    transition: (identity, expected, update, captured = captureRuntime()) => serialize(async () => { const gate = available(), item = find(identity); if (gate) return gate; if (!item || !boundMatches(item, captured)) return result("stale"); if (reserved(identity)) return result("failed", [{ phase: "identity", code: "reserved" }]); if (!(Array.isArray(expected) ? expected : [expected]).includes(item.status)) return result("stale"); return commit(() => coordinator.transition(identity, update, captured)) }),
    confirm: (identity, captured = captureRuntime()) => serialize(async () => { const gate = available(), item = find(identity); if (gate) return gate; if (!item || !boundMatches(item, captured)) return result("stale"); if (reserved(identity)) return result("failed", [{ phase: "identity", code: "reserved" }]); return commit(() => coordinator.remove(identity, captured)) }),
    acquireSendPayload: (identity, captured = captureRuntime()) => serialize(async () => { const gate = available(), item = find(identity); if (gate) return gate; if (!item || !boundMatches(item, captured)) return result("stale"); if (reserved(identity)) return result("failed", [{ phase: "identity", code: "reserved" }]); return coordinator.acquireSendPayload(identity, captured) }),
    releaseSend: (identity, token, captured = captureRuntime()) => serialize(async () => coordinator.releaseSend(identity, token, captured)),
  }
}
