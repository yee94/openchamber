import { expect, test } from "bun:test"
import { MemoryInputDraftBlobDriver, createInputDraftBlobStore } from "./input-draft-blob-store"
import { draftAttachmentRefID } from "./input-draft-types"
import { createQueueAttachmentCoordinator, type QueueRuntime } from "./queue-attachment-coordinator"
import type { InputDraftBlobStore } from "./input-draft-blob-store"
import type { QueueItemDTO, QueueLedgerSnapshotV4 } from "@/stores/message-queue-ledger"

const metadata = () => ({ persist: async () => ({ ok: true as const, value: undefined }), flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} })
const runtime = { transportIdentity: "t", generation: 0, isCurrent: () => true }
const item = (): QueueItemDTO => ({ version: 1, queueItemID: "q", operationID: "o", messageID: "m", owner: { state: "bound", transportIdentity: "t", directory: "/d", sessionID: "s" }, content: "x", attachments: [], attachmentIssues: [], createdAt: 1, status: "queued", attemptCount: 0 })
const blob = (id = "b", occurrenceRefID = '["root","a"]'): QueueItemDTO["attachments"][number] => ({ version: 1, attachmentID: "a", occurrenceRefID, filename: "a", mimeType: "text/plain", size: 1, source: "local", locator: { kind: "blob", blobID: id } })
const identity = { queueItemID: "q", operationID: "o", messageID: "m" }
const snapshot = (queued: QueueItemDTO): QueueLedgerSnapshotV4 => ({ version: 4, queues: { 'bound:["t","/d","s"]': [queued] }, migration: { v3State: "complete" } })
test("admission commits a validated queue row", async () => {
  const coordinator = createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), metadata())
  await coordinator.hydrate(null)
  expect((await coordinator.admit(item(), runtime)).status).toBe("committed")
  expect(Object.values(coordinator.getSnapshot().queues).flat()).toHaveLength(1)
})
test("disabled coordinator avoids durable admission", async () => {
  const coordinator = createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), metadata())
  await coordinator.hydrate(null); await coordinator.setEnabled(false)
  expect((await coordinator.admit(item(), runtime)).status).toBe("disabled")
})
test("admission keeps a preexisting queue reference when metadata fails", async () => {
  const driver = new MemoryInputDraftBlobDriver(), blobs = createInputDraftBlobStore(driver), queued = item()
  queued.attachments = [{ version: 1, attachmentID: "a", occurrenceRefID: '["root","a"]', filename: "a", mimeType: "text/plain", size: 1, source: "local", locator: { kind: "blob", blobID: "b" } }]
  const reference = { transportIdentity: "t", owner: { kind: "queue" as const, ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' }
  const coordinator = createQueueAttachmentCoordinator(blobs, { ...metadata(), persist: async () => ({ ok: false as const, error: { code: "quota" as const } }) })
  await coordinator.hydrate(null); await blobs.putAndRetain(reference, "b", new Blob(["x"], { type: "text/plain" })); expect((await coordinator.admit(queued, runtime)).status).toBe("failed")
  const retained = await blobs.readReference(reference); expect(retained.ok && retained.value).toBe("b"); expect(draftAttachmentRefID(reference)).toContain("queue")
})
test("transition rejects owner changes", async () => {
  const coordinator = createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), metadata()), queued = item()
  await coordinator.hydrate(null); await coordinator.admit(queued, runtime)
  expect((await coordinator.transition({ queueItemID: "q", operationID: "o", messageID: "m" }, (value) => ({ ...value, owner: { state: "bound", transportIdentity: "t", directory: "/other", sessionID: "s" } }), runtime)).status).toBe("failed")
})
test("admission rejects all globally duplicate identities", async () => {
  for (const field of ["queueItemID", "operationID", "messageID"] as const) {
    const coordinator = createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), metadata())
    await coordinator.hydrate(null); await coordinator.admit(item(), runtime)
    const duplicate = item(); duplicate.queueItemID = "q2"; duplicate.operationID = "o2"; duplicate.messageID = "m2"; duplicate[field] = item()[field]
    expect((await coordinator.admit(duplicate, runtime)).status).toBe("failed")
  }
})
test("transition only accepts status fields", async () => {
  const blobs = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), coordinator = createQueueAttachmentCoordinator(blobs, metadata()), queued = item()
  queued.attachments = [blob()]; await coordinator.hydrate(null); await blobs.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' }, "b", new Blob(["x"])); expect(await coordinator.admit(queued, runtime)).toEqual({ status: "committed", current: true, errors: [], cleanupErrors: [] })
  expect((await coordinator.transition(identity, (value) => ({ ...value, attachments: [] }), runtime)).status).toBe("failed")
  expect((await coordinator.transition(identity, (value) => ({ ...value, status: "sending", attemptCount: value.attemptCount + 1 }), runtime)).status).toBe("committed")
  await coordinator.transition(identity, (value) => ({ ...value, status: "sending", attemptCount: value.attemptCount + 1 }), runtime)
  expect((await coordinator.transition(identity, (value) => ({ ...value, status: "failed", failureKind: "definitive" }), runtime)).status).toBe("committed")
})
test("send payload preserves mixed attachment order", async () => {
  const driver = new MemoryInputDraftBlobDriver(), blobs = createInputDraftBlobStore(driver), queued = item()
  queued.attachments = [{ ...blob("b1", '["root","a1"]'), attachmentID: "a1" }, { version: 1, attachmentID: "url", occurrenceRefID: '["root","url"]', filename: "u", mimeType: "text/plain", size: 1, source: "server", serverPath: "/u", locator: { kind: "url", url: "https://example.com/u" } }, { ...blob("b2", '["root","a2"]'), attachmentID: "a2" }]
  const coordinator = createQueueAttachmentCoordinator(blobs, metadata()); await coordinator.hydrate(null); await blobs.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","a1"]' }, "b1", new Blob(["1"])); await blobs.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","a2"]' }, "b2", new Blob(["2"])); await coordinator.admit(queued, runtime)
  expect((await coordinator.acquireSendPayload(identity, runtime)).values?.map((entry) => entry.attachment.attachmentID)).toEqual(["a1", "url", "a2"])
})
test("runtime generation changes produce stale before blob mutation", async () => {
  const driver = new MemoryInputDraftBlobDriver(), blobs = createInputDraftBlobStore(driver), queued = item()
  const changing: QueueRuntime = { transportIdentity: "t", generation: 1, isCurrent: () => true, current: () => ({ transportIdentity: "t", generation: 2 }) }
  const coordinator = createQueueAttachmentCoordinator(blobs, metadata()); await coordinator.hydrate(null)
  expect((await coordinator.admit(queued, changing)).status).toBe("stale")
  const stored = await blobs.readReference({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' })
  expect(stored.ok && stored.value).toBe(undefined)
})
test("partial hydrate publishes a read-only filtered snapshot without reconciling references", async () => {
  const driver = new MemoryInputDraftBlobDriver(), blobs = createInputDraftBlobStore(driver), queued = item(); queued.attachments = [blob()]
  const queueRef = { transportIdentity: "t", owner: { kind: "queue" as const, ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' }
  const sendRef = { transportIdentity: "t", owner: { kind: "send" as const, ownerID: "o" }, attachmentOccurrenceRefID: '["root","a"]' }
  await blobs.putAndRetain(queueRef, "b", new Blob(["x"])); await blobs.putAndRetain(sendRef, "b", new Blob(["x"])); const coordinator = createQueueAttachmentCoordinator(blobs, metadata())
  const loaded = await coordinator.hydrate({ raw: "partial", snapshot: snapshot(queued), status: "partial", issues: [{ scopeKey: "broken", path: "$.queues.broken", reason: "item" }], degradedScopeKeys: ["broken"] })
  const kept = await blobs.readReference(queueRef), retainedSend = await blobs.readReference(sendRef)
  expect(loaded.status).toBe("recovery-required"); expect(kept.ok && kept.value).toBe("b"); expect(retainedSend.ok && retainedSend.value).toBe("b")
})
test("disabled public operations leave blob and metadata untouched", async () => {
  let persists = 0, mutations = 0
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver())
  const blobs: InputDraftBlobStore = { ...base, retain: async (...args) => { mutations++; return base.retain(...args) }, releaseIfMatches: async (...args) => { mutations++; return base.releaseIfMatches(...args) } }
  const coordinator = createQueueAttachmentCoordinator(blobs, { ...metadata(), persist: async () => { persists++; return { ok: true as const, value: undefined } } })
  await coordinator.hydrate(null); await coordinator.setEnabled(false); const queued = item(); queued.attachments = [blob()]
  await coordinator.admit(queued, runtime); await coordinator.acquireSendPayload(identity, runtime); await coordinator.releaseSend(identity, "token" as never, runtime); await coordinator.remove(identity, runtime); await coordinator.reconcile(); await coordinator.retryCleanup()
  expect(persists).toBe(0); expect(mutations).toBe(0)
})
test("malformed attachment admission performs zero blob or metadata mutation", async () => {
  let persists = 0, mutations = 0
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver())
  const blobs: InputDraftBlobStore = { ...base, putAndRetain: async (...args) => { mutations++; return base.putAndRetain(...args) }, retain: async (...args) => { mutations++; return base.retain(...args) }, releaseIfMatches: async (...args) => { mutations++; return base.releaseIfMatches(...args) } }
  const coordinator = createQueueAttachmentCoordinator(blobs, { ...metadata(), persist: async () => { persists++; return { ok: true as const, value: undefined } } })
  const queued = item(); queued.attachments = [{ ...blob(), occurrenceRefID: "broken" }]
  await coordinator.hydrate(null)
  expect((await coordinator.admit(queued, runtime)).status).toBe("failed")
  expect(persists).toBe(0); expect(mutations).toBe(0); expect(coordinator.getSnapshot().queues).toEqual({})
})
test("metadata commit adopts its baseline after runtime becomes stale", async () => {
  let resolvePersist: ((value: { ok: true; value: undefined }) => void) | undefined
  let persistStarted: () => void
  const started = new Promise<void>((resolve) => { persistStarted = resolve })
  const blobs = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), queued = item(); queued.attachments = [blob()]
  let current = true
  const coordinator = createQueueAttachmentCoordinator(blobs, { ...metadata(), persist: () => new Promise((resolve) => { resolvePersist = resolve; persistStarted() }) })
  await coordinator.hydrate(null)
  const admitted = coordinator.admit(queued, { ...runtime, isCurrent: () => current }, () => new Blob(["x"]))
  await started; current = false; resolvePersist!({ ok: true, value: undefined })
  expect(await admitted).toEqual({ status: "committed", current: false, errors: [], cleanupErrors: [] })
  expect(Object.values(coordinator.getSnapshot().queues).flat()).toHaveLength(1)
  const retained = await blobs.readReference({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' })
  expect(retained.ok && retained.value).toBe("b")
})
test("bind metadata commit stays committed through cleanup failure and stale currentness", async () => {
  let current = true, writes = 0
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), queued = item(); queued.attachments = [blob()]
  const blobs: InputDraftBlobStore = { ...base, releaseIfMatches: async () => ({ ok: false as const, error: { code: "transaction-failed" as const } }) }
  const coordinator = createQueueAttachmentCoordinator(blobs, { ...metadata(), persist: async () => { if (++writes === 2) current = false; return { ok: true as const, value: undefined } } }); await coordinator.hydrate(null)
  await base.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' }, "b", new Blob(["x"]))
  await coordinator.admit(queued, { ...runtime, isCurrent: () => current })
  const bound = await coordinator.bind(identity, { state: "bound", transportIdentity: "t", directory: "/next", sessionID: "s" }, { ...runtime, isCurrent: () => current })
  expect(bound.status).toBe("committed"); expect(bound.current).toBe(false); expect(bound.cleanupErrors[0]?.code).toBe("transaction-failed")
  expect(Object.keys(coordinator.getSnapshot().queues)).toEqual(['bound:["t","/next","s"]'])
})
test("matching queue reference repairs a missing blob through the resolver", async () => {
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), queued = item(); queued.attachments = [blob()]
  const queueRef = { transportIdentity: "t", owner: { kind: "queue" as const, ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' }
  let repaired = 0
  const blobs: InputDraftBlobStore = { ...base, readReference: async (reference) => draftAttachmentRefID(reference) === draftAttachmentRefID(queueRef) ? { ok: true as const, value: "b" } : base.readReference(reference), read: async () => ({ ok: false as const, error: { code: "missing-blob" as const } }), putAndRetain: async (...args) => { repaired++; return base.putAndRetain(...args) } }
  const coordinator = createQueueAttachmentCoordinator(blobs, metadata()); await coordinator.hydrate(null)
  expect((await coordinator.admit(queued, runtime, () => new Blob(["x"]))).status).toBe("committed")
  expect(repaired).toBe(1)
})
test("disabled hydration reads and seeds without reconciliation, then enables operations", async () => {
  let reads = 0, reconciles = 0
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver())
  const blobs: InputDraftBlobStore = { ...base, reconcileReferences: async (...args) => { reconciles++; return base.reconcileReferences(...args) } }
  const coordinator = createQueueAttachmentCoordinator(blobs, { ...metadata(), readDetailed: async () => { reads++; return { ok: true as const, value: { raw: null, snapshot: snapshot(item()), status: "ok" as const, issues: [], degradedScopeKeys: [] } } } }, { enabled: false })
  expect((await coordinator.hydrate()).status).toBe("disabled"); expect(reads).toBe(1); expect(reconciles).toBe(0)
  await coordinator.setEnabled(true)
  await coordinator.transition(identity, (value) => ({ ...value, status: "sending", attemptCount: value.attemptCount + 1 }), runtime)
  expect((await coordinator.transition(identity, (value) => ({ ...value, status: "failed", failureKind: "definitive" }), runtime)).status).toBe("committed")
})
test("cleanup retry preserves a queue reference readmitted after rollback", async () => {
  let persists = 0, failsRelease = true
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), queued = item(); queued.attachments = [blob()]
  const blobs: InputDraftBlobStore = { ...base, releaseIfMatches: async (...args) => failsRelease ? { ok: false as const, error: { code: "transaction-failed" as const } } : base.releaseIfMatches(...args) }
  const coordinator = createQueueAttachmentCoordinator(blobs, { ...metadata(), persist: async () => ++persists === 1 ? { ok: false as const, error: { code: "quota" as const } } : { ok: true as const, value: undefined } })
  await coordinator.hydrate(null)
  expect((await coordinator.admit(queued, runtime, () => new Blob(["x"]))).cleanupErrors).toHaveLength(1)
  failsRelease = false
  expect((await coordinator.admit(queued, runtime, () => new Blob(["x"]))).status).toBe("committed")
  expect((await coordinator.retryCleanup()).status).toBe("committed")
  const retained = await base.readReference({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' })
  expect(retained.ok && retained.value).toBe("b")
})
test("recovery gate blocks every mutating operation until a complete hydrate", async () => {
  let persists = 0, mutations = 0
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver())
  const blobs: InputDraftBlobStore = { ...base, retain: async (...args) => { mutations++; return base.retain(...args) }, releaseIfMatches: async (...args) => { mutations++; return base.releaseIfMatches(...args) }, reconcileReferences: async (...args) => { mutations++; return base.reconcileReferences(...args) } }
  const coordinator = createQueueAttachmentCoordinator(blobs, { ...metadata(), persist: async () => { persists++; return { ok: true as const, value: undefined } } })
  const partial = { raw: "partial", snapshot: snapshot(item()), status: "partial" as const, issues: [{ path: "$.queues.bad", reason: "item" }], degradedScopeKeys: [] }
  expect((await coordinator.hydrate(partial)).status).toBe("recovery-required")
  for (const result of [await coordinator.admit(item(), runtime), await coordinator.transition(identity, (value) => value, runtime), await coordinator.acquireSendPayload(identity, runtime), await coordinator.remove(identity, runtime), await coordinator.reconcile(), await coordinator.retryCleanup()]) expect(result.status).toBe("recovery-required")
  expect((await coordinator.releaseSend(identity, "token" as never, runtime)).status).toBe("stale")
  expect(persists).toBe(0); expect(mutations).toBe(0)
  await coordinator.hydrate(snapshot(item()))
  await coordinator.transition(identity, (value) => ({ ...value, status: "sending", attemptCount: value.attemptCount + 1 }), runtime)
  expect((await coordinator.transition(identity, (value) => ({ ...value, status: "failed", failureKind: "definitive" }), runtime)).status).toBe("committed")
})
test("corrupt hydrate preserves the prior baseline and requires complete recovery", async () => {
  const coordinator = createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), metadata())
  await coordinator.hydrate(null); await coordinator.admit(item(), runtime)
  expect((await coordinator.hydrate({ raw: "{", snapshot: null, status: "corrupt", issues: [{ path: "$", reason: "json" }], degradedScopeKeys: [] })).status).toBe("recovery-required")
  expect(Object.values(coordinator.getSnapshot().queues).flat()).toHaveLength(1)
  await coordinator.hydrate(snapshot(item()))
  await coordinator.transition(identity, (value) => ({ ...value, status: "sending", attemptCount: value.attemptCount + 1 }), runtime)
  expect((await coordinator.transition(identity, (value) => ({ ...value, status: "failed", failureKind: "definitive" }), runtime)).status).toBe("committed")
})
test("live reconcile protects active sends while startup hydration clears stale sends", async () => {
  const blobs = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), queued = item(); queued.attachments = [blob()]
  const queueRef = { transportIdentity: "t", owner: { kind: "queue" as const, ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' }
  const sendRef = { transportIdentity: "t", owner: { kind: "send" as const, ownerID: "o" }, attachmentOccurrenceRefID: '["root","a"]' }
  const coordinator = createQueueAttachmentCoordinator(blobs, metadata()); await coordinator.hydrate(null); await blobs.putAndRetain(queueRef, "b", new Blob(["x"])); await coordinator.admit(queued, runtime); await coordinator.acquireSendPayload(identity, runtime); await coordinator.reconcile()
  const active = await blobs.readReference(sendRef); expect(active.ok && active.value).toBe("b")
  const restarted = createQueueAttachmentCoordinator(blobs, metadata()); await restarted.hydrate(snapshot(queued))
  const cleared = await blobs.readReference(sendRef); expect(cleared.ok && cleared.value).toBe(undefined)
})
test("preexisting send references validate matching blobs without releasing them on failure", async () => {
  const blobs = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), queued = item(); queued.attachments = [blob()]
  const queueRef = { transportIdentity: "t", owner: { kind: "queue" as const, ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' }
  const sendRef = { transportIdentity: "t", owner: { kind: "send" as const, ownerID: "o" }, attachmentOccurrenceRefID: '["root","a"]' }
  const coordinator = createQueueAttachmentCoordinator(blobs, metadata()); await coordinator.hydrate(null); await blobs.putAndRetain(queueRef, "b", new Blob(["x"])); await blobs.putAndRetain(sendRef, "b", new Blob(["x"])); await coordinator.admit(queued, runtime)
  expect((await coordinator.acquireSendPayload(identity, runtime)).status).toBe("committed")
  let releases = 0
  const conflictBlobs: InputDraftBlobStore = { ...blobs, readReference: async (value) => draftAttachmentRefID(value) === draftAttachmentRefID(sendRef) ? { ok: true as const, value: "other" } : blobs.readReference(value), releaseIfMatches: async (...args) => { releases++; return blobs.releaseIfMatches(...args) } }
  const conflict = createQueueAttachmentCoordinator(conflictBlobs, metadata()); await conflict.hydrate(snapshot(queued)); releases = 0; expect((await conflict.acquireSendPayload(identity, runtime)).status).toBe("failed")
  expect(releases).toBe(0)
})

test("disabled token release clears its acquisition and permits a later acquisition", async () => {
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), queued = item(); queued.attachments = [blob()]
  const coordinator = createQueueAttachmentCoordinator(base, metadata()); await coordinator.hydrate(null)
  await base.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' }, "b", new Blob(["x"]))
  await coordinator.admit(queued, runtime); const first = await coordinator.acquireSendPayload(identity, runtime)
  await coordinator.setEnabled(false); expect((await coordinator.releaseSend(identity, first.token!)).status).toBe("committed")
  await coordinator.setEnabled(true); expect((await coordinator.acquireSendPayload(identity, runtime)).status).toBe("committed")
})

test("disabled token release records failed cleanup for retry after enablement", async () => {
  let fail = true
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), blobs: InputDraftBlobStore = { ...base, releaseIfMatches: async (...args) => fail ? { ok: false as const, error: { code: "transaction-failed" as const } } : base.releaseIfMatches(...args) }, queued = item(); queued.attachments = [blob()]
  const coordinator = createQueueAttachmentCoordinator(blobs, metadata()); await coordinator.hydrate(null)
  await base.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' }, "b", new Blob(["x"]))
  await coordinator.admit(queued, runtime); const acquired = await coordinator.acquireSendPayload(identity, runtime)
  await coordinator.setEnabled(false); expect((await coordinator.releaseSend(identity, acquired.token!)).cleanupErrors[0]?.code).toBe("transaction-failed")
  fail = false; await coordinator.setEnabled(true); expect((await coordinator.retryCleanup()).status).toBe("committed")
})

test("stale tokens preserve newer acquisitions", async () => {
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), queued = item(); queued.attachments = [blob()]
  const coordinator = createQueueAttachmentCoordinator(base, metadata()); await coordinator.hydrate(null)
  await base.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' }, "b", new Blob(["x"]))
  await coordinator.admit(queued, runtime); const first = await coordinator.acquireSendPayload(identity, runtime); await coordinator.releaseSend(identity, first.token!)
  const second = await coordinator.acquireSendPayload(identity, runtime); expect((await coordinator.releaseSend(identity, first.token!)).status).toBe("stale")
  expect((await coordinator.acquireSendPayload(identity, runtime)).errors[0]?.code).toBe("active-send")
  await coordinator.releaseSend(identity, second.token!); expect((await coordinator.acquireSendPayload(identity, runtime)).status).toBe("committed")
})

test("remove commits metadata before queue and send cleanup, retaining failed cleanup for retry", async () => {
  let fail = true
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), blobs: InputDraftBlobStore = { ...base, releaseIfMatches: async (...args) => fail ? { ok: false as const, error: { code: "transaction-failed" as const } } : base.releaseIfMatches(...args) }, queued = item(); queued.attachments = [blob()]
  const coordinator = createQueueAttachmentCoordinator(blobs, metadata()); await coordinator.hydrate(null)
  await base.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","a"]' }, "b", new Blob(["x"]))
  await coordinator.admit(queued, runtime); await coordinator.acquireSendPayload(identity, runtime)
  const removed = await coordinator.remove(identity, runtime); expect(removed.status).toBe("committed"); expect(removed.cleanupErrors).toHaveLength(2); expect(coordinator.getSnapshot().queues).toEqual({})
  fail = false; expect((await coordinator.retryCleanup()).status).toBe("committed")
})

test("bindMany prepends source rows once and rolls back blob or metadata failures", async () => {
  const legacy = (id: string): QueueItemDTO => ({ ...item(), queueItemID: id, operationID: `o-${id}`, messageID: `m-${id}`, owner: { state: "unbound-legacy", sessionID: "legacy" }, attachments: [{ ...blob(`b-${id}`, `["root","${id}"]`), attachmentID: id }] })
  const first = legacy("one"), second = legacy("two"), existing = item(); existing.queueItemID = "existing"; existing.operationID = "o-existing"; existing.messageID = "m-existing"
  let writes = 0
  const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), coordinator = createQueueAttachmentCoordinator(base, { ...metadata(), persist: async () => { writes++; return { ok: true as const, value: undefined } } })
  await coordinator.hydrate({ version: 4, queues: { 'unbound-legacy:["legacy"]': [first, second], 'bound:["t","/d","s"]': [existing] }, migration: { v3State: "complete" } })
  await base.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "one" }, attachmentOccurrenceRefID: '["root","one"]' }, "b-one", new Blob(["1"])); await base.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "two" }, attachmentOccurrenceRefID: '["root","two"]' }, "b-two", new Blob(["2"]))
  expect((await coordinator.bindMany([{ ...identity, queueItemID: "one", operationID: "o-one", messageID: "m-one" }, { ...identity, queueItemID: "two", operationID: "o-two", messageID: "m-two" }], { state: "bound", transportIdentity: "t", directory: "/d", sessionID: "s" }, runtime)).status).toBe("committed")
  expect(coordinator.getSnapshot().queues['bound:["t","/d","s"]']?.map((row) => row.queueItemID)).toEqual(["one", "two", "existing"]); expect(writes).toBe(1)
})

test("transition matrix preserves snapshots and skips persistence for every rejected mutation", async () => {
  let writes = 0
  const coordinator = createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { ...metadata(), persist: async () => { writes++; return { ok: true as const, value: undefined } } })
  const reconciling = { ...item(), status: "reconciling" as const, attemptCount: 1, failureKind: "ambiguous-dispatch" as const, reconciliationStartedAt: 2, reconciliationDeadlineAt: 4, reconciliationChecks: 1, reconciliationNextCheckAt: 3 }
  await coordinator.hydrate(snapshot(reconciling)); const baseline = coordinator.getSnapshot(); writes = 0
  for (const update of [
    (value: QueueItemDTO) => ({ ...value, status: "queued" as const }),
    (value: QueueItemDTO) => ({ ...value, attemptCount: 0 }),
    (value: QueueItemDTO) => ({ ...value, attemptCount: 2 }),
    (value: QueueItemDTO) => ({ ...value, reconciliationChecks: 0 }),
    (value: QueueItemDTO) => ({ ...value, reconciliationStartedAt: 3 }),
    (value: QueueItemDTO) => ({ ...value, reconciliationDeadlineAt: 5 }),
    (value: QueueItemDTO) => ({ ...value, content: "changed" }),
    (value: QueueItemDTO) => ({ ...value, attachments: [blob()] }),
    (value: QueueItemDTO) => ({ ...value, queueItemID: "changed" }),
  ]) expect((await coordinator.transition(identity, update, runtime)).status).toBe("failed")
  expect(writes).toBe(0); expect(coordinator.getSnapshot()).toEqual(baseline)
})

test("transition matrix accepts every durable edge", async () => {
  const make = async (queued: QueueItemDTO) => { const coordinator = createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), metadata()); await coordinator.hydrate(snapshot(queued)); return coordinator }
  const queued = await make(item()); expect((await queued.transition(identity, (value) => ({ ...value, status: "sending", attemptCount: 1 }), runtime)).status).toBe("committed")
  const retrying = await make({ ...item(), status: "retrying", attemptCount: 1, nextAttemptAt: 2, failureKind: "pre-dispatch" }); expect((await retrying.transition(identity, (value) => ({ ...value, status: "sending", attemptCount: 2, nextAttemptAt: undefined, failureKind: undefined }), runtime)).status).toBe("committed")
  for (const update of [
    (value: QueueItemDTO) => ({ ...value, status: "retrying" as const, nextAttemptAt: 2, failureKind: "pre-dispatch" as const }),
    (value: QueueItemDTO) => ({ ...value, status: "reconciling" as const, failureKind: "ambiguous-dispatch" as const, reconciliationStartedAt: 1, reconciliationDeadlineAt: 2, reconciliationChecks: 0, reconciliationNextCheckAt: 1 }),
    (value: QueueItemDTO) => ({ ...value, status: "failed" as const, failureKind: "definitive" as const }),
  ]) { const coordinator = await make(item()); await coordinator.transition(identity, (value) => ({ ...value, status: "sending", attemptCount: 1 }), runtime); expect((await coordinator.transition(identity, update, runtime)).status).toBe("committed") }
  const reconciling = { ...item(), status: "reconciling" as const, attemptCount: 1, failureKind: "ambiguous-dispatch" as const, reconciliationStartedAt: 1, reconciliationDeadlineAt: 2, reconciliationChecks: 0, reconciliationNextCheckAt: 1 }
  const checking = await make(reconciling); expect((await checking.transition(identity, (value) => ({ ...value, reconciliationChecks: 1, reconciliationNextCheckAt: 2 }), runtime)).status).toBe("committed")
  const unresolved = await make(reconciling); expect((await unresolved.transition(identity, (value) => ({ ...value, status: "unresolved", reconciliationNextCheckAt: undefined }), runtime)).status).toBe("committed")
})
