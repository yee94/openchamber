import { draftAttachmentRefID, type DraftAttachmentReference } from "./input-draft-types"
import { describeComposerDocumentResources } from "@/composer/extensions"
import type { DraftBlobValue, InputDraftBlobStore } from "./input-draft-blob-store"
import { emptyQueueLedgerSnapshot, parseQueueLedgerSnapshot, queueLedgerScopeKey, type QueueItemDTO, type QueueLedgerDetailedRead, type QueueLedgerRepository, type QueueLedgerSnapshotV4 } from "@/stores/message-queue-ledger"

export type QueueIdentity = Pick<QueueItemDTO, "queueItemID" | "operationID" | "messageID">
export type QueueRuntime = {
  transportIdentity: string
  generation: number
  isCurrent: () => boolean | Promise<boolean>
  current?: () => { transportIdentity: string; generation: number } | Promise<{ transportIdentity: string; generation: number }>
}
export type QueueAttachmentCoordinatorError = { phase: "blob" | "metadata" | "identity" | "runtime"; code: string; scopeKey?: string; queueItemID?: string; operationID?: string; attachmentID?: string; occurrenceRefID?: string; path?: string }
export type QueueAttachmentCoordinatorResult = { status: "committed" | "failed" | "stale" | "disabled" | "unseeded" | "recovery-required"; current?: boolean; errors: QueueAttachmentCoordinatorError[]; cleanupErrors: QueueAttachmentCoordinatorError[] }
export type QueueSendToken = string & { readonly __queueSendToken: unique symbol }
export type QueueSendPayload = QueueAttachmentCoordinatorResult & { token?: QueueSendToken; values?: Array<{ attachment: QueueItemDTO["attachments"][number]; value: DraftBlobValue }> }
export type QueueAttachmentCoordinator = {
  hydrate: (snapshot?: QueueLedgerSnapshotV4 | QueueLedgerDetailedRead | null) => Promise<QueueAttachmentCoordinatorResult>
  getSnapshot: () => QueueLedgerSnapshotV4
  admit: (item: QueueItemDTO, runtime: QueueRuntime, resolve?: (attachment: QueueItemDTO["attachments"][number]) => DraftBlobValue | undefined | Promise<DraftBlobValue | undefined>) => Promise<QueueAttachmentCoordinatorResult>
  transition: (identity: QueueIdentity, update: (item: QueueItemDTO) => QueueItemDTO, runtime: QueueRuntime) => Promise<QueueAttachmentCoordinatorResult>
  reorder: (scopeKey: string, queueItemIDs: string[], runtime: QueueRuntime) => Promise<QueueAttachmentCoordinatorResult>
  bind: (identity: QueueIdentity, owner: Extract<QueueItemDTO["owner"], { state: "bound" }>, runtime: QueueRuntime) => Promise<QueueAttachmentCoordinatorResult>
  bindMany: (identities: readonly QueueIdentity[], owner: Extract<QueueItemDTO["owner"], { state: "bound" }>, runtime: QueueRuntime) => Promise<QueueAttachmentCoordinatorResult>
  acquireSendPayload: (identity: QueueIdentity, runtime: QueueRuntime) => Promise<QueueSendPayload>
  releaseSend: (identity: QueueIdentity, token: QueueSendToken, runtime?: QueueRuntime) => Promise<QueueAttachmentCoordinatorResult>
  remove: (identity: QueueIdentity, runtime: QueueRuntime) => Promise<QueueAttachmentCoordinatorResult>
  reconcile: () => Promise<QueueAttachmentCoordinatorResult>
  retryCleanup: () => Promise<QueueAttachmentCoordinatorResult>
  flush: () => Promise<void>
  setEnabled: (enabled: boolean) => Promise<void>
}

type Capture = { transportIdentity: string; generation: number; enableGeneration: number; identity: QueueIdentity }
type Held = { reference: DraftAttachmentReference; blobID: string; attachment: QueueItemDTO["attachments"][number]; item: QueueItemDTO }
type SendAcquisition = { token: QueueSendToken; identity: QueueIdentity; held: Held[] }
const clone = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T
const outcome = (status: QueueAttachmentCoordinatorResult["status"], errors: QueueAttachmentCoordinatorError[] = [], cleanupErrors: QueueAttachmentCoordinatorError[] = [], current?: boolean): QueueAttachmentCoordinatorResult => ({ status, ...(current === undefined ? {} : { current }), errors, cleanupErrors })
const sameIdentity = (item: QueueItemDTO, id: QueueIdentity): boolean => item.queueItemID === id.queueItemID && item.operationID === id.operationID && item.messageID === id.messageID
const reference = (item: QueueItemDTO, kind: "queue" | "send", occurrence: string): DraftAttachmentReference | undefined => item.owner.state === "bound" ? { transportIdentity: item.owner.transportIdentity, owner: { kind, ownerID: kind === "queue" ? item.queueItemID : item.operationID }, attachmentOccurrenceRefID: occurrence } : undefined
const stable = (value: unknown): string => JSON.stringify(value)
const transitionShape = (item: QueueItemDTO): unknown => ({ owner: item.owner, queueItemID: item.queueItemID, operationID: item.operationID, messageID: item.messageID, content: item.content, composerDocument: item.composerDocument, attachments: item.attachments, attachmentIssues: item.attachmentIssues, createdAt: item.createdAt, sendConfig: item.sendConfig })
const identityKey = (id: QueueIdentity): string => `${id.queueItemID}\u0000${id.operationID}\u0000${id.messageID}`
const integer = (value: unknown): value is number => typeof value === "number" && Number.isSafeInteger(value)
const transitionValid = (before: QueueItemDTO, next: QueueItemDTO): boolean => {
  if (stable(transitionShape(before)) !== stable(transitionShape(next)) || !integer(next.attemptCount) || next.attemptCount < before.attemptCount) return false
  const edge = `${before.status}:${next.status}`
  if (!["queued:sending", "retrying:sending", "sending:retrying", "sending:reconciling", "sending:failed", "reconciling:reconciling", "reconciling:unresolved"].includes(edge)) return false
  if (next.status === "sending" && next.attemptCount !== before.attemptCount + 1) return false
  if (next.status !== "sending" && next.attemptCount !== before.attemptCount) return false
  const reconciliation = [next.reconciliationStartedAt, next.reconciliationDeadlineAt, next.reconciliationChecks, next.reconciliationNextCheckAt]
  if (reconciliation.some((value) => value !== undefined && !integer(value))) return false
  if (before.status === "reconciling" && next.status === "reconciling") {
    if (next.reconciliationStartedAt !== before.reconciliationStartedAt || next.reconciliationDeadlineAt !== before.reconciliationDeadlineAt || (next.reconciliationChecks ?? 0) < (before.reconciliationChecks ?? 0)) return false
  }
  return true
}
const composerAttachmentsMatch = (item: QueueItemDTO): boolean => {
  if (!item.composerDocument) return true
  const referenced = new Set(item.composerDocument ? describeComposerDocumentResources(item.composerDocument).flatMap((resource) => resource.type === "attachment" ? [resource.attachmentRefID] : []) : [])
  const attached = new Set(item.attachments.map((attachment) => attachment.occurrenceRefID))
  return [...referenced].every((id) => attached.has(id))
}

export const createQueueAttachmentCoordinator = (blobStore: InputDraftBlobStore, metadata: QueueLedgerRepository, options: { enabled?: boolean } = {}): QueueAttachmentCoordinator => {
  let snapshot = emptyQueueLedgerSnapshot()
  let seeded = false
  let enabled = options.enabled ?? true
  let enableGeneration = 0
  let degraded = false
  let recoveryReadOnly = false
  let tail = Promise.resolve()
  const cleanup = new Map<string, Held>()
  const activeSend = new Map<string, Held>()
  const acquisitions = new Map<string, SendAcquisition>()
  let nextToken = 0n
  const run = <T>(work: () => Promise<T>): Promise<T> => { const next = tail.then(work, work); tail = next.then(() => undefined, () => undefined); return next }
  const all = (): QueueItemDTO[] => Object.values(snapshot.queues).flat()
  const find = (id: QueueIdentity): QueueItemDTO | undefined => all().find((candidate) => sameIdentity(candidate, id))
  const error = (phase: QueueAttachmentCoordinatorError["phase"], code: string, item?: QueueItemDTO, attachment?: QueueItemDTO["attachments"][number], path?: string): QueueAttachmentCoordinatorError => ({ phase, code, ...(item ? { scopeKey: queueLedgerScopeKey(item.owner), queueItemID: item.queueItemID, operationID: item.operationID } : {}), ...(attachment ? { attachmentID: attachment.attachmentID, occurrenceRefID: attachment.occurrenceRefID } : {}), ...(path ? { path } : {}) })
  const entries = (item: QueueItemDTO, kind: "queue" | "send"): Held[] => item.attachments.flatMap((attachment) => attachment.locator.kind === "blob" ? (() => { const value = reference(item, kind, attachment.occurrenceRefID); return value ? [{ reference: value, blobID: attachment.locator.blobID, attachment, item }] : [] })() : [])
  const capture = (runtime: QueueRuntime, item: QueueItemDTO): Capture => ({ transportIdentity: runtime.transportIdentity, generation: runtime.generation, enableGeneration, identity: { queueItemID: item.queueItemID, operationID: item.operationID, messageID: item.messageID } })
  const ownsRuntime = (item: QueueItemDTO, runtime: QueueRuntime): boolean => item.owner.state !== "bound" || item.owner.transportIdentity === runtime.transportIdentity
  const current = async (runtime: QueueRuntime, captured: Capture): Promise<boolean> => {
    if (!enabled || captured.enableGeneration !== enableGeneration || runtime.transportIdentity !== captured.transportIdentity || runtime.generation !== captured.generation || !await runtime.isCurrent()) return false
    const authoritative = await runtime.current?.()
    return authoritative === undefined || authoritative.transportIdentity === captured.transportIdentity && authoritative.generation === captured.generation
  }
  const stale = (): QueueAttachmentCoordinatorResult => outcome(enabled ? "stale" : "disabled", [], [], false)
  const recoveryRequired = (): QueueAttachmentCoordinatorResult => outcome("recovery-required", [error("metadata", "recovery-required")])
  const release = async (held: Held, cleanupErrors: QueueAttachmentCoordinatorError[]): Promise<void> => {
    const released = await blobStore.releaseIfMatches(held.reference, held.blobID)
    if (!released.ok) { cleanup.set(draftAttachmentRefID(held.reference), held); cleanupErrors.push(error("blob", released.error.code, held.item, held.attachment)) }
  }
  const rollback = async (held: Held[]): Promise<QueueAttachmentCoordinatorError[]> => {
    const cleanupErrors: QueueAttachmentCoordinatorError[] = []
    for (const entry of [...held].reverse()) await release(entry, cleanupErrors)
    return cleanupErrors
  }
  const queueDesired = (): Map<string, string> => {
    const desired = new Map<string, string>()
    for (const item of all()) for (const held of entries(item, "queue")) desired.set(draftAttachmentRefID(held.reference), held.blobID)
    return desired
  }
  const protectedCleanup = (key: string, held: Held, desired = queueDesired()): boolean => desired.get(key) === held.blobID || activeSend.get(key)?.blobID === held.blobID
  const commit = async (next: QueueLedgerSnapshotV4, runtime: QueueRuntime, captured: Capture): Promise<{ committed: boolean; current: boolean; error?: QueueAttachmentCoordinatorError }> => {
    if (!await current(runtime, captured)) return { committed: false, current: false }
    const stored = await metadata.persist(next)
    if (!stored.ok) return { committed: false, current: true, error: error("metadata", stored.error.code) }
    snapshot = next
    return { committed: true, current: await current(runtime, captured) }
  }
  const reconcileInternal = async (startup = false): Promise<QueueAttachmentCoordinatorResult> => {
    if (!seeded) return outcome("unseeded")
    if (!enabled) return outcome("disabled")
    if (recoveryReadOnly || degraded) return recoveryRequired()
    const desired = queueDesired()
    const sendDesired = startup ? new Map<string, string>() : new Map([...activeSend].map(([key, held]) => [key, held.blobID]))
    const lookup = new Map<string, Held>()
    for (const item of all()) for (const held of entries(item, "queue")) lookup.set(draftAttachmentRefID(held.reference), held)
    const sendLookup = new Map<string, Held>(activeSend)
    const errors: QueueAttachmentCoordinatorError[] = []
    if (!degraded) {
      const queue = await blobStore.reconcileReferences(desired, { ownerKinds: ["queue"] })
      if (!queue.ok) errors.push(error("blob", queue.error.code))
      else for (const id of queue.value.missing) { const held = lookup.get(id); errors.push(error("blob", "missing-blob", held?.item, held?.attachment, id)) }
    }
    const send = await blobStore.reconcileReferences(sendDesired, { ownerKinds: ["send"] })
    if (!send.ok) errors.push(error("blob", send.error.code))
    else for (const id of send.value.missing) { const held = sendLookup.get(id); errors.push(error("blob", "missing-blob", held?.item, held?.attachment, id)) }
    return outcome(errors.length ? "failed" : "committed", errors)
  }
  return {
    hydrate: (incoming) => run(async () => {
      const loaded = incoming === undefined ? metadata.readDetailed ? await metadata.readDetailed() : metadata.read ? await metadata.read().then((result) => result.ok ? { ok: true as const, value: result.value === null ? { raw: null, snapshot: null, status: "empty" as const, issues: [], degradedScopeKeys: [] } : { raw: null, snapshot: result.value, status: "ok" as const, issues: [], degradedScopeKeys: [] } } : result) : undefined : undefined
      if (loaded && !loaded.ok) return outcome("failed", [error("metadata", loaded.error.code)])
      const source = loaded?.value ?? incoming
      const detailed = source && "status" in source ? source : undefined
      let raw = detailed?.snapshot ?? (source && !("status" in source) ? source : null)
      if (detailed?.snapshot === null && detailed.raw !== null) { try { raw = JSON.parse(detailed.raw) } catch { raw = null } }
      const parsed = raw ? parseQueueLedgerSnapshot(raw, { normalizeSending: true }) : { status: "ok" as const, snapshot: emptyQueueLedgerSnapshot(), issues: [], degradedScopeKeys: [] }
      const issues = detailed?.issues ?? parsed.issues
      seeded = true
      const corrupt = detailed?.status === "corrupt" || parsed.status === "corrupt"
      const partial = detailed?.status === "partial" || issues.length > 0
      activeSend.clear(); acquisitions.clear()
      if (corrupt) {
        recoveryReadOnly = true
        degraded = true
        return outcome("recovery-required", issues.map((issue) => ({ phase: "metadata", code: issue.reason, ...issue })))
      }
      snapshot = parsed.snapshot
      recoveryReadOnly = partial
      degraded = partial
      if (partial) return outcome("recovery-required", issues.map((issue) => ({ phase: "metadata", code: issue.reason, ...issue })))
      if (!enabled) return outcome("disabled", issues.map((issue) => ({ phase: "metadata", code: issue.reason, ...issue })))
      return reconcileInternal(true)
    }),
    getSnapshot: () => clone(snapshot),
    admit: (item, runtime, resolve) => run(async () => {
      if (!enabled) return outcome("disabled")
      if (!seeded) return outcome("unseeded")
      if (recoveryReadOnly) return recoveryRequired()
      if (!ownsRuntime(item, runtime)) return stale()
      const key = queueLedgerScopeKey(item.owner)
      const candidate = clone(snapshot); candidate.queues[key] = [...(candidate.queues[key] ?? []), item]
      const parsed = parseQueueLedgerSnapshot(candidate)
      if (!composerAttachmentsMatch(item)) return outcome("failed", [error("identity", "composer-attachment-mismatch", item)])
      if (parsed.status === "corrupt" || parsed.issues.length) return outcome("failed", parsed.issues.map((issue) => ({ phase: "identity", code: issue.reason, ...issue })))
      const captured = capture(runtime, item)
      if (!await current(runtime, captured)) return stale()
      const acquired: Held[] = []
      for (const held of entries(item, "queue")) {
        if (!await current(runtime, captured)) return { ...stale(), cleanupErrors: await rollback(acquired) }
        const existing = await blobStore.readReference(held.reference)
        if (!existing.ok) return outcome("failed", [error("blob", existing.error.code, item, held.attachment)], await rollback(acquired))
        if (existing.value && existing.value !== held.blobID) return outcome("failed", [error("blob", "blob-id-conflict", item, held.attachment)], await rollback(acquired))
        if (existing.value === held.blobID) {
          const present = await blobStore.read(held.blobID)
          if (present.ok) continue
          if (present.error.code !== "missing-blob") return outcome("failed", [error("blob", present.error.code, item, held.attachment)], await rollback(acquired))
          const value = await resolve?.(held.attachment)
          if (value === undefined) return outcome("failed", [error("blob", "missing-blob", item, held.attachment)], await rollback(acquired))
          const repaired = await blobStore.putAndRetain(held.reference, held.blobID, value)
          if (!repaired.ok) return outcome("failed", [error("blob", repaired.error.code, item, held.attachment)], await rollback(acquired))
          continue
        }
        const present = await blobStore.read(held.blobID)
        const retained = present.ok ? await blobStore.retain(held.reference, held.blobID) : present.error.code === "missing-blob" ? await (async () => { const value = await resolve?.(held.attachment); return value === undefined ? { ok: false as const, error: { code: "missing-blob" } } : blobStore.putAndRetain(held.reference, held.blobID, value) })() : present
        if (!retained.ok) return outcome("failed", [error("blob", retained.error.code, item, held.attachment)], await rollback(acquired))
        acquired.push(held)
      }
      const committed = await commit(parsed.snapshot, runtime, captured)
      if (!committed.committed) return committed.error ? outcome("failed", [committed.error], await rollback(acquired)) : { ...stale(), cleanupErrors: await rollback(acquired) }
      for (const held of entries(item, "queue")) cleanup.delete(draftAttachmentRefID(held.reference))
      return outcome("committed", [], [], committed.current)
    }),
    transition: (id, update, runtime) => run(async () => {
      if (!enabled) return outcome("disabled")
      if (!seeded) return outcome("unseeded")
      if (recoveryReadOnly) return recoveryRequired()
      const item = find(id); if (!item || !ownsRuntime(item, runtime)) return stale()
      const captured = capture(runtime, item); if (!await current(runtime, captured)) return stale()
      const nextItem = update(clone(item))
      const next = clone(snapshot), key = queueLedgerScopeKey(item.owner); next.queues[key] = next.queues[key]!.map((entry) => sameIdentity(entry, id) ? nextItem : entry)
      const parsed = parseQueueLedgerSnapshot(next)
      if (!sameIdentity(nextItem, id) || !transitionValid(item, nextItem) || parsed.status === "corrupt" || parsed.issues.length) return outcome("failed", [error("identity", "invalid-transition", item)])
      const committed = await commit(parsed.snapshot, runtime, captured)
      return committed.committed ? outcome("committed", [], [], committed.current) : committed.error ? outcome("failed", [committed.error]) : stale()
    }),
    reorder: (scopeKey, queueItemIDs, runtime) => run(async () => {
      if (!enabled) return outcome("disabled")
      if (!seeded) return outcome("unseeded")
      if (recoveryReadOnly) return recoveryRequired()
      const queue = snapshot.queues[scopeKey]
      if (!queue || queue.length !== queueItemIDs.length || new Set(queueItemIDs).size !== queue.length || queue.some((item) => !queueItemIDs.includes(item.queueItemID))) return outcome("failed", [error("identity", "invalid-reorder")])
      if (queue.some((item) => !ownsRuntime(item, runtime))) return stale()
      const captured = capture(runtime, queue[0]!)
      if (!await current(runtime, captured)) return stale()
      const byID = new Map(queue.map((item) => [item.queueItemID, item]))
      const next = clone(snapshot)
      next.queues[scopeKey] = queueItemIDs.map((id) => byID.get(id)!)
      const committed = await commit(next, runtime, captured)
      return committed.committed ? outcome("committed", [], [], committed.current) : committed.error ? outcome("failed", [committed.error]) : stale()
    }),
    bind: (id, owner, runtime) => run(async () => {
      if (!enabled) return outcome("disabled")
      if (!seeded) return outcome("unseeded")
      if (recoveryReadOnly) return recoveryRequired()
      const item = find(id)
      if (!item) return outcome("failed", [error("identity", "invalid-bind")])
      if (!ownsRuntime(item, runtime) || owner.transportIdentity !== runtime.transportIdentity) return stale()
      if (item.owner.state !== "unbound-legacy" || item.attachments.length) return outcome("failed", [error("identity", "invalid-bind", item)])
      const sourceKey = queueLedgerScopeKey(item.owner), sourceQueue = snapshot.queues[sourceKey]
      if (!sourceQueue || sourceQueue.length !== 1 || !sameIdentity(sourceQueue[0]!, id) || sourceQueue[0]!.owner.state !== "unbound-legacy" || sourceQueue[0]!.attachments.length) return outcome("failed", [error("identity", "invalid-bind", item)])
      const captured = capture(runtime, item)
      if (!await current(runtime, captured)) return stale()
      const nextItem = { ...clone(item), owner }
      const parsedItem = parseQueueLedgerSnapshot({ version: 4, queues: { [queueLedgerScopeKey(owner)]: [nextItem] }, migration: snapshot.migration })
      if (parsedItem.status === "corrupt" || parsedItem.issues.length) return outcome("failed", [error("identity", "invalid-bind", item)])
      const next = clone(snapshot), oldKey = sourceKey, newKey = queueLedgerScopeKey(owner)
      next.queues[oldKey] = next.queues[oldKey]!.filter((entry) => !sameIdentity(entry, id)); if (!next.queues[oldKey]!.length) delete next.queues[oldKey]
      next.queues[newKey] = [nextItem, ...(next.queues[newKey] ?? [])]
      const parsed = parseQueueLedgerSnapshot(next)
      if (parsed.status === "corrupt" || parsed.issues.length) return outcome("failed", [error("identity", "invalid-bind", item)])
      const committed = await commit(parsed.snapshot, runtime, captured)
      return committed.committed ? outcome("committed", [], [], committed.current) : committed.error ? outcome("failed", [committed.error]) : stale()
    }),
    bindMany: (ids, owner, runtime) => run(async () => {
      if (!enabled) return outcome("disabled")
      if (!seeded) return outcome("unseeded")
      if (recoveryReadOnly) return recoveryRequired()
      const items = ids.map(find)
      if (!items.length || items.some((item) => !item || !ownsRuntime(item, runtime) || item.owner.state !== "unbound-legacy") || owner.transportIdentity !== runtime.transportIdentity) return stale()
      const source = items[0]!.owner
      const sourceQueue = snapshot.queues[queueLedgerScopeKey(source)]
      if (!sourceQueue || sourceQueue.length !== ids.length || items.some((item) => stable(item!.owner) !== stable(source) || item!.attachments.length) || sourceQueue.some((item, index) => !sameIdentity(item, ids[index]!))) return outcome("failed", [error("identity", "invalid-bind")])
      const captured = capture(runtime, items[0]!); if (!await current(runtime, captured)) return stale()
      const bound = items as QueueItemDTO[], moved = bound.map((item) => ({ ...clone(item), owner }))
      const next = clone(snapshot), oldKey = queueLedgerScopeKey(source), newKey = queueLedgerScopeKey(owner)
      next.queues[oldKey] = next.queues[oldKey]!.filter((entry) => !bound.some((item) => sameIdentity(entry, item))); if (!next.queues[oldKey]!.length) delete next.queues[oldKey]
      next.queues[newKey] = [...moved, ...(next.queues[newKey] ?? [])]
      const parsed = parseQueueLedgerSnapshot(next)
      if (parsed.status === "corrupt" || parsed.issues.length) return outcome("failed", [error("identity", "invalid-bind")])
      const committed = await commit(parsed.snapshot, runtime, captured)
      return committed.committed ? outcome("committed", [], [], committed.current) : committed.error ? outcome("failed", [committed.error]) : stale()
    }),
    acquireSendPayload: (id, runtime) => run(async () => {
      if (!enabled) return outcome("disabled")
      if (!seeded) return outcome("unseeded")
      if (recoveryReadOnly) return recoveryRequired()
      const item = find(id); if (!item || !ownsRuntime(item, runtime)) return stale()
      if (acquisitions.has(identityKey(id))) return outcome("failed", [error("identity", "active-send", item)])
      const captured = capture(runtime, item); if (!await current(runtime, captured)) return stale()
      const acquired: Held[] = [], values: NonNullable<QueueSendPayload["values"]> = []
      for (const attachment of item.attachments) {
        if (!await current(runtime, captured)) return { ...stale(), cleanupErrors: await rollback(acquired) }
        if (attachment.locator.kind === "url") { values.push({ attachment, value: attachment.locator.url }); continue }
        const held = entries(item, "send").find((entry) => entry.attachment.occurrenceRefID === attachment.occurrenceRefID)!
        const existing = await blobStore.readReference(held.reference)
        if (!existing.ok || existing.value && existing.value !== held.blobID) return outcome("failed", [error("blob", existing.ok ? "blob-id-conflict" : existing.error.code, item, attachment)], await rollback(acquired))
        if (existing.value !== held.blobID) { const retained = await blobStore.retain(held.reference, held.blobID); if (!retained.ok) return outcome("failed", [error("blob", retained.error.code, item, attachment)], await rollback(acquired)); acquired.push(held) }
        const value = await blobStore.read(held.blobID)
        if (!value.ok) return outcome("failed", [error("blob", value.error.code, item, attachment)], await rollback(acquired))
        values.push({ attachment, value: value.value })
      }
      if (!await current(runtime, captured)) return { ...stale(), cleanupErrors: await rollback(acquired) }
      const held = entries(item, "send"), token = `${++nextToken}` as QueueSendToken
      for (const entry of held) activeSend.set(draftAttachmentRefID(entry.reference), entry)
      acquisitions.set(identityKey(id), { token, identity: id, held })
      return { ...outcome("committed", [], [], true), token, values }
    }),
    releaseSend: (id, token) => run(async () => {
      const acquisition = acquisitions.get(identityKey(id))
      if (typeof token !== "string" || !acquisition || acquisition.token !== token) return outcome("stale")
      acquisitions.delete(identityKey(id))
      const cleanupErrors: QueueAttachmentCoordinatorError[] = []; for (const held of acquisition.held) { activeSend.delete(draftAttachmentRefID(held.reference)); await release(held, cleanupErrors) }
      return outcome(cleanupErrors.length ? "failed" : "committed", [], cleanupErrors, true)
    }),
    remove: (id, runtime) => run(async () => {
      if (!enabled) return outcome("disabled")
      if (!seeded) return outcome("unseeded")
      if (recoveryReadOnly) return recoveryRequired()
      const item = find(id); if (!item || !ownsRuntime(item, runtime)) return stale()
      const captured = capture(runtime, item); if (!await current(runtime, captured)) return stale()
      const next = clone(snapshot); for (const [key, queue] of Object.entries(next.queues)) { const left = queue.filter((entry) => !sameIdentity(entry, id)); if (left.length) next.queues[key] = left; else delete next.queues[key] }
      const committed = await commit(next, runtime, captured)
      if (!committed.committed) return committed.error ? outcome("failed", [committed.error]) : stale()
      const acquisition = acquisitions.get(identityKey(id)); acquisitions.delete(identityKey(id))
      const cleanupErrors: QueueAttachmentCoordinatorError[] = []; for (const held of entries(item, "queue")) await release(held, cleanupErrors); for (const held of acquisition?.held ?? entries(item, "send")) { activeSend.delete(draftAttachmentRefID(held.reference)); await release(held, cleanupErrors) }
      return outcome("committed", [], cleanupErrors, committed.current)
    }),
    reconcile: () => run(() => reconcileInternal(false)),
    retryCleanup: () => run(async () => { if (!enabled) return outcome("disabled"); if (recoveryReadOnly || degraded) return recoveryRequired(); const cleanupErrors: QueueAttachmentCoordinatorError[] = [], desired = queueDesired(); for (const [key, held] of cleanup) { if (protectedCleanup(key, held, desired)) { cleanup.delete(key); continue } const released = await blobStore.releaseIfMatches(held.reference, held.blobID); if (released.ok) cleanup.delete(key); else cleanupErrors.push(error("blob", released.error.code, held.item, held.attachment)) } return outcome(cleanupErrors.length ? "failed" : "committed", [], cleanupErrors) }),
    flush: () => tail.then(() => metadata.flush()),
    setEnabled: async (next) => { enabled = next; enableGeneration++; metadata.cancelPending(); await metadata.setEnabled(next); await tail },
  }
}
