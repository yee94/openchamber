import type { QueueItemDTO, QueueLedgerSnapshotV4 } from "@/stores/message-queue-ledger"
import { queueLedgerScopeKey } from "@/stores/message-queue-ledger"
import type { QueueRuntimeCapture, ScopedQueueIdentity, MessageQueueRuntimeController } from "./message-queue-runtime-controller"
import type { DraftBlobValue } from "./input-draft-blob-store"
import type { QueueSendToken } from "./queue-attachment-coordinator"

export type QueueDispatchIdentity = ScopedQueueIdentity
export type QueueDispatchMode = { mode?: "manual" | "auto"; delivery?: "steer" }
export type QueueDispatchFailure = "pre-dispatch" | "definitive-rejection" | "ambiguous-dispatched"
export type QueueReconciliationResult = "confirmed" | "authoritative-miss" | "unavailable"
export type QueueDispatchPayload = { content: string; composerDocument?: QueueItemDTO["composerDocument"]; sendConfig?: QueueItemDTO["sendConfig"]; attachments: Array<{ attachment: QueueItemDTO["attachments"][number]; value: DraftBlobValue }> }
export type QueueDispatchResult = "confirmed" | "pending" | "unresolved" | "stale" | "failed" | "skipped"

export type QueueDispatcherDependencies = {
  runtime: Pick<MessageQueueRuntimeController, "getState" | "captureRuntime" | "transition" | "confirm" | "acquireSendPayload" | "releaseSend">
  post: (scope: Extract<QueueItemDTO["owner"], { state: "bound" }>, payload: QueueDispatchPayload, options: QueueDispatchMode & { onSendConfirmed: (messageID: string) => void }) => Promise<void>
  query: (scope: Extract<QueueItemDTO["owner"], { state: "bound" }>, messageID: string, capture: QueueRuntimeCapture) => Promise<QueueReconciliationResult>
  classifyFailure: (error: unknown) => QueueDispatchFailure
  notifyConfirmed: (scope: Extract<QueueItemDTO["owner"], { state: "bound" }>, messageID: string) => void | Promise<void>
  now?: () => number
  retryDelayMs?: (attemptCount: number) => number
  reconciliationDelayMs?: (checks: number) => number
  reconciliationDeadlineMs?: number
  maxReconciliationChecks?: number
}

export type QueueSchedulerPlan = { dispatch: QueueDispatchIdentity[]; query: QueueDispatchIdentity[]; resolve: QueueDispatchIdentity[]; recover: QueueDispatchIdentity[]; nextWakeAt?: number; inspectedScopeCount: number }
const MAX_SAFE = Number.MAX_SAFE_INTEGER
const add = (left: number, right: number): number | undefined => Number.isSafeInteger(left) && Number.isSafeInteger(right) && right >= 0 && left <= MAX_SAFE - right ? left + right : undefined
const identity = (scopeKey: string, item: QueueItemDTO): QueueDispatchIdentity => ({ scopeKey, queueItemID: item.queueItemID, operationID: item.operationID, messageID: item.messageID })
const same = (item: QueueItemDTO | undefined, id: QueueDispatchIdentity, scopeKey: string): item is QueueItemDTO => !!item && queueLedgerScopeKey(item.owner) === scopeKey && item.queueItemID === id.queueItemID && item.operationID === id.operationID && item.messageID === id.messageID
const clearTransient = (item: QueueItemDTO, patch: Partial<QueueItemDTO>): QueueItemDTO => {
  const base = { ...item }
  delete base.nextAttemptAt; delete base.reconciliationStartedAt; delete base.reconciliationDeadlineAt
  delete base.reconciliationChecks; delete base.reconciliationNextCheckAt; delete base.failureKind
  return { ...base, ...patch }
}

const flightKey = (id: QueueDispatchIdentity) => `${id.scopeKey}\u0000${id.queueItemID}\u0000${id.operationID}\u0000${id.messageID}`

export const planMessageQueueWork = (snapshot: QueueLedgerSnapshotV4, transportIdentity: string, now: number, options: { maxReconciliationChecks?: number; inFlightKeys?: ReadonlySet<string> } = {}): QueueSchedulerPlan => {
  const plan: QueueSchedulerPlan = { dispatch: [], query: [], resolve: [], recover: [], inspectedScopeCount: 0 }
  const maxChecks = options.maxReconciliationChecks ?? 3
  for (const [scopeKey, queue] of Object.entries(snapshot.queues)) {
    const item = queue[0]
    if (!item || item.owner.state !== "bound" || item.owner.transportIdentity !== transportIdentity) continue
    plan.inspectedScopeCount++
    const id = identity(scopeKey, item)
    if (options.inFlightKeys?.has(flightKey(id))) continue
    if (item.status === "sending") { plan.recover.push(id); continue }
    if (item.status === "queued") plan.dispatch.push(id)
    if (item.status === "retrying") {
      if ((item.nextAttemptAt ?? 0) <= now) plan.dispatch.push(id)
      else plan.nextWakeAt = Math.min(plan.nextWakeAt ?? MAX_SAFE, item.nextAttemptAt!)
    }
    if (item.status === "reconciling") {
      if ((item.reconciliationDeadlineAt ?? 0) <= now || (item.reconciliationChecks ?? 0) >= maxChecks) plan.resolve.push(id)
      else if ((item.reconciliationNextCheckAt ?? 0) <= now) plan.query.push(id)
      else plan.nextWakeAt = Math.min(plan.nextWakeAt ?? MAX_SAFE, item.reconciliationNextCheckAt!)
    }
  }
  return plan
}

export const createMessageQueueDispatcher = (deps: QueueDispatcherDependencies) => {
  const now = deps.now ?? Date.now
  const retryDelay = deps.retryDelayMs ?? ((attempt) => Math.min(2_000 * 2 ** Math.max(attempt - 1, 0), 60_000))
  const reconciliationDelay = deps.reconciliationDelayMs ?? (() => 2_000)
  const deadlineMs = deps.reconciliationDeadlineMs ?? 30_000
  const maxChecks = deps.maxReconciliationChecks ?? 3
  const flights = new Map<string, Promise<QueueDispatchResult>>()
  const validConfig = () => Number.isSafeInteger(deadlineMs) && deadlineMs >= 0 && Number.isSafeInteger(maxChecks) && maxChecks >= 0
  const locate = (id: QueueDispatchIdentity, capture: QueueRuntimeCapture): QueueItemDTO | undefined => {
    const item = deps.runtime.getState().snapshot.queues[id.scopeKey]?.[0]
    return same(item, id, id.scopeKey) && item.owner.state === "bound" && item.owner.transportIdentity === capture.transportIdentity ? item : undefined
  }
  const release = async (id: QueueDispatchIdentity, token: QueueSendToken, capture: QueueRuntimeCapture) => { try { await deps.runtime.releaseSend(id, token, capture) } catch { /* token cleanup remains best effort */ } }
  const current = async (capture: QueueRuntimeCapture): Promise<boolean> => {
    try { return await capture.isCurrent() } catch { return false }
  }
  const confirm = async (id: QueueDispatchIdentity, capture: QueueRuntimeCapture): Promise<QueueDispatchResult> => {
    try {
      const item = locate(id, capture)
      if (!item || !await current(capture)) return "stale"
      const removed = await deps.runtime.confirm(id, capture)
      if (removed.status !== "committed") return removed.status === "stale" ? "stale" : "failed"
      try { await deps.notifyConfirmed(item.owner as Extract<QueueItemDTO["owner"], { state: "bound" }>, id.messageID) } catch { /* durable confirmation remains authoritative */ }
      return "confirmed"
    } catch { return "failed" }
  }
  const dispatchWork = async (id: QueueDispatchIdentity, options: QueueDispatchMode = {}, explicitCapture?: QueueRuntimeCapture): Promise<QueueDispatchResult> => {
    if (!validConfig()) return "failed"
    const capture = explicitCapture ?? deps.runtime.captureRuntime()
    let item = locate(id, capture)
    if (!item || !await current(capture) || !["queued", "retrying"].includes(item.status) || item.status === "retrying" && (item.nextAttemptAt ?? 0) > now()) return "skipped"
    let acquired
    try { acquired = await deps.runtime.acquireSendPayload(id, capture) } catch { return "failed" }
    if (acquired.status !== "committed" || !acquired.values || !acquired.token) return acquired.status === "stale" ? "stale" : "failed"
    const token = acquired.token
    let released = false
    const releaseToken = async () => {
      if (released) return
      released = true
      await release(id, token, capture)
    }
    const finishConfirmation = async (): Promise<QueueDispatchResult> => {
      const result = await confirm(id, capture)
      if (result !== "confirmed") await releaseToken()
      return result
    }
    item = locate(id, capture)
    if (!item || !await current(capture)) { await releaseToken(); return "stale" }
    if (!Number.isSafeInteger(item.attemptCount) || item.attemptCount >= MAX_SAFE) { await releaseToken(); return "failed" }
    let sending
    try { sending = await deps.runtime.transition(id, ["queued", "retrying"], (value) => clearTransient(value, { status: "sending", attemptCount: value.attemptCount + 1 }), capture) } catch { await releaseToken(); return "failed" }
    if (sending.status !== "committed") { await releaseToken(); return sending.status === "stale" ? "stale" : "failed" }
    let confirmation: Promise<QueueDispatchResult> | undefined
    const settleConfirmed = (messageID: string) => {
      if (messageID === id.messageID) confirmation ??= finishConfirmation()
    }
    try {
      await deps.post(item.owner as Extract<QueueItemDTO["owner"], { state: "bound" }>, { content: item.content, ...(item.composerDocument ? { composerDocument: item.composerDocument } : {}), sendConfig: item.sendConfig, attachments: acquired.values }, { ...options, onSendConfirmed: settleConfirmed })
      settleConfirmed(id.messageID)
      return await confirmation!
    } catch (error) {
      if (confirmation) return await confirmation
      if (!await current(capture) || !locate(id, capture)) { await releaseToken(); return "stale" }
      let kind: QueueDispatchFailure
      try { kind = deps.classifyFailure(error) } catch { await releaseToken(); return "failed" }
      const currentItem = locate(id, capture)!
      const at = now()
      if (kind === "pre-dispatch") {
        let delay: number
        try { delay = retryDelay(currentItem.attemptCount) } catch { await releaseToken(); return "failed" }
        const nextAttemptAt = add(at, delay)
        if (!Number.isSafeInteger(delay) || delay < 0 || nextAttemptAt === undefined) { await releaseToken(); return "failed" }
        try { const changed = await deps.runtime.transition(id, "sending", (value) => clearTransient(value, { status: "retrying", failureKind: "pre-dispatch", nextAttemptAt }), capture); await releaseToken(); return changed.status === "committed" ? "pending" : changed.status === "stale" ? "stale" : "failed" } catch { await releaseToken(); return "failed" }
      } else if (kind === "definitive-rejection") {
        try { const changed = await deps.runtime.transition(id, "sending", (value) => clearTransient(value, { status: "failed", failureKind: "definitive" }), capture); await releaseToken(); return changed.status === "committed" ? "failed" : changed.status === "stale" ? "stale" : "failed" } catch { await releaseToken(); return "failed" }
      } else {
        const deadline = add(at, deadlineMs)
        if (deadline === undefined) { await releaseToken(); return "failed" }
        try { const changed = await deps.runtime.transition(id, "sending", (value) => clearTransient(value, { status: "reconciling", failureKind: "ambiguous-dispatch", reconciliationStartedAt: at, reconciliationDeadlineAt: deadline, reconciliationChecks: 0, reconciliationNextCheckAt: at }), capture); await releaseToken(); return changed.status === "committed" ? "pending" : changed.status === "stale" ? "stale" : "failed" } catch { await releaseToken(); return "failed" }
      }
    }
  }
  const dispatch = (id: QueueDispatchIdentity, options: QueueDispatchMode = {}, explicitCapture?: QueueRuntimeCapture) => {
    const key = flightKey(id), existing = flights.get(key)
    if (existing) return existing
    const work = dispatchWork(id, options, explicitCapture).catch(() => "failed" as const).finally(() => { if (flights.get(key) === work) flights.delete(key) })
    flights.set(key, work); return work
  }
  const reconcileWork = async (id: QueueDispatchIdentity, explicitCapture?: QueueRuntimeCapture): Promise<QueueDispatchResult> => {
    if (!validConfig()) return "failed"
    const capture = explicitCapture ?? deps.runtime.captureRuntime(), item = locate(id, capture)
    if (!item || item.status !== "reconciling" || !await current(capture)) return "skipped"
    const initialNow = now()
    if ((item.reconciliationDeadlineAt ?? 0) <= initialNow || (item.reconciliationChecks ?? 0) >= maxChecks) {
      try { const resolved = await deps.runtime.transition(id, "reconciling", (value) => clearTransient(value, { status: "unresolved", failureKind: "ambiguous-dispatch", reconciliationStartedAt: value.reconciliationStartedAt!, reconciliationDeadlineAt: value.reconciliationDeadlineAt!, reconciliationChecks: value.reconciliationChecks ?? 0, reconciliationNextCheckAt: value.reconciliationNextCheckAt }), capture); return resolved.status === "committed" ? "unresolved" : resolved.status === "stale" ? "stale" : "failed" } catch { return "failed" }
    }
    if (item.reconciliationNextCheckAt !== undefined && item.reconciliationNextCheckAt > initialNow) return "skipped"
    let verdict: QueueReconciliationResult
    try { verdict = await deps.query(item.owner as Extract<QueueItemDTO["owner"], { state: "bound" }>, id.messageID, capture) } catch { verdict = "unavailable" }
    if (!await current(capture) || !locate(id, capture)) return "stale"
    if (verdict === "confirmed") return confirm(id, capture)
    const currentItem = locate(id, capture)!, at = now(), priorChecks = currentItem.reconciliationChecks ?? 0
    const deadline = currentItem.reconciliationDeadlineAt
    if (!Number.isSafeInteger(priorChecks) || priorChecks < 0 || typeof deadline !== "number" || !Number.isSafeInteger(deadline)) return "failed"
    const checks = verdict === "authoritative-miss" ? add(priorChecks, 1) : priorChecks
    if (checks === undefined) return "failed"
    if (at >= deadline || checks >= maxChecks) {
      try { const resolved = await deps.runtime.transition(id, "reconciling", (value) => clearTransient(value, { status: "unresolved", failureKind: "ambiguous-dispatch", reconciliationStartedAt: value.reconciliationStartedAt!, reconciliationDeadlineAt: value.reconciliationDeadlineAt!, reconciliationChecks: checks, reconciliationNextCheckAt: value.reconciliationNextCheckAt }), capture); return resolved.status === "committed" ? "unresolved" : resolved.status === "stale" ? "stale" : "failed" } catch { return "failed" }
    }
    let delay: number
    try { delay = reconciliationDelay(checks) } catch { return "failed" }
    const candidate = add(at, delay)
    if (!Number.isSafeInteger(delay) || delay < 0 || candidate === undefined) return "failed"
    const next = Math.min(candidate, deadline)
    try { const changed = await deps.runtime.transition(id, "reconciling", (value) => clearTransient(value, { status: "reconciling", failureKind: "ambiguous-dispatch", reconciliationStartedAt: value.reconciliationStartedAt!, reconciliationDeadlineAt: value.reconciliationDeadlineAt!, reconciliationChecks: checks, reconciliationNextCheckAt: next }), capture); return changed.status === "committed" ? "pending" : changed.status === "stale" ? "stale" : "failed" } catch { return "failed" }
  }
  const reconcile = (id: QueueDispatchIdentity, capture?: QueueRuntimeCapture) => {
    const key = flightKey(id), existing = flights.get(key)
    if (existing) return existing
    const work = reconcileWork(id, capture).catch(() => "failed" as const).finally(() => { if (flights.get(key) === work) flights.delete(key) })
    flights.set(key, work); return work
  }
  const recoverWork = async (id: QueueDispatchIdentity, capture = deps.runtime.captureRuntime()): Promise<QueueDispatchResult> => {
    const item = locate(id, capture), at = now(), deadline = add(at, deadlineMs)
    if (!validConfig() || !item || item.status !== "sending" || !await current(capture) || deadline === undefined) return "skipped"
    try { const changed = await deps.runtime.transition(id, "sending", (value) => clearTransient(value, { status: "reconciling", failureKind: "ambiguous-dispatch", reconciliationStartedAt: at, reconciliationDeadlineAt: deadline, reconciliationChecks: 0, reconciliationNextCheckAt: at }), capture); return changed.status === "committed" ? "pending" : changed.status === "stale" ? "stale" : "failed" } catch { return "failed" }
  }
  const recover = (id: QueueDispatchIdentity, capture?: QueueRuntimeCapture) => {
    const key = flightKey(id), existing = flights.get(key)
    if (existing) return existing
    const work = recoverWork(id, capture).catch(() => "failed" as const).finally(() => { if (flights.get(key) === work) flights.delete(key) })
    flights.set(key, work); return work
  }
  return { dispatch, reconcile, recover, plan: (capture = deps.runtime.captureRuntime()) => planMessageQueueWork(deps.runtime.getState().snapshot, capture.transportIdentity, now(), { maxReconciliationChecks: maxChecks, inFlightKeys: new Set(flights.keys()) }) }
}
