import { expect, test } from "bun:test"
import { createInputDraftBlobStore, MemoryInputDraftBlobDriver } from "./input-draft-blob-store"
import { createMessageQueueRuntimeController } from "./message-queue-runtime-controller"
import { createQueueAttachmentCoordinator, type QueueAttachmentCoordinator } from "./queue-attachment-coordinator"
import type { QueueItemDTO, QueueLedgerResult, QueueLedgerSnapshotV4 } from "@/stores/message-queue-ledger"

const runtime = () => ({ transportIdentity: "t", generation: 1, isCurrent: () => true })
const item = (id = "q"): QueueItemDTO => ({ version: 1, queueItemID: id, operationID: `o-${id}`, messageID: `m-${id}`, owner: { state: "bound", transportIdentity: "t", directory: "/d", sessionID: "s" }, content: id, attachments: [], attachmentIssues: [], createdAt: 1, status: "queued", attemptCount: 0 })
const unboundItem = (id = "legacy"): QueueItemDTO => ({ ...item(id), owner: { state: "unbound-legacy", sessionID: "s" } })
const snapshot = (...items: QueueItemDTO[]): QueueLedgerSnapshotV4 => ({ version: 4, queues: { 'bound:["t","/d","s"]': items }, migration: { v3State: "complete" } })
const setup = (persist: () => Promise<QueueLedgerResult<void>> = async () => ({ ok: true as const, value: undefined })) => createMessageQueueRuntimeController(createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { persist, flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} }), runtime)
const identity = (value: QueueItemDTO) => ({ scopeKey: 'bound:["t","/d","s"]', queueItemID: value.queueItemID, operationID: value.operationID, messageID: value.messageID })
const legacyIdentity = (value: QueueItemDTO) => ({ scopeKey: 'unbound-legacy:["s"]', queueItemID: value.queueItemID, operationID: value.operationID, messageID: value.messageID })

const releaseFixture = (mode: "failed" | "throw") => {
  const queued = item(), ledger = snapshot(queued)
  let releases = 0, acquisitions = 0
  const coordinator = {
    hydrate: async () => ({ status: "committed" as const, errors: [], cleanupErrors: [] }),
    getSnapshot: () => ledger,
    acquireSendPayload: async () => { acquisitions++; return { status: "committed" as const, current: true, errors: [], cleanupErrors: [], token: "reservation" as never, values: [] } },
    releaseSend: async () => {
      releases++
      if (mode === "throw") throw new Error("release")
      return { status: "failed" as const, errors: [], cleanupErrors: [{ phase: "blob" as const, code: "transaction-failed" }] }
    },
    setEnabled: async () => {},
  } as unknown as QueueAttachmentCoordinator
  const controller = createMessageQueueRuntimeController(coordinator, runtime)
  return { controller, queued, releases: () => releases, acquisitions: () => acquisitions }
}

test("hydrate is single-flight and mutations wait for readiness", async () => {
  let reads = 0
  const controller = createMessageQueueRuntimeController(createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { readDetailed: async () => { reads++; return { ok: true as const, value: { raw: null, snapshot: null, status: "empty" as const, issues: [], degradedScopeKeys: [] } } }, persist: async () => ({ ok: true as const, value: undefined }), flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} }), runtime)
  expect((await controller.admit(item())).status).toBe("unseeded")
  await Promise.all([controller.hydrate(), controller.hydrate()])
  expect(reads).toBe(1)
})
test("partial and corrupt hydration keep mutations closed", async () => {
  for (const status of ["partial", "corrupt"] as const) { const controller = setup(); await controller.hydrate({ raw: "x", snapshot: status === "partial" ? snapshot(item()) : null, status, issues: [{ path: "$", reason: status }], degradedScopeKeys: [] }); expect((await controller.admit(item("next"))).status).toBe("recovery-required") }
})
test("admission publishes after metadata commit and preserves state on rollback or stale capture", async () => {
  let resolve: (() => void) | undefined
  let started: () => void
  const writing = new Promise<void>((done) => { started = done })
  const controller = setup(() => new Promise((done) => { resolve = () => done({ ok: true, value: undefined }); started() }))
  await controller.hydrate(null); const admitted = controller.admit(item()); await writing; expect(controller.getState().snapshot.queues).toEqual({}); resolve!(); expect((await admitted).status).toBe("committed")
  const failing = setup(async () => ({ ok: false as const, error: { code: "quota" as const } })); await failing.hydrate(null); await failing.admit(item()); expect(failing.getState().snapshot.queues).toEqual({})
})
test("stale admission publishes no runtime snapshot", async () => {
  const coordinator = createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { persist: async () => ({ ok: true as const, value: undefined }), flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} })
  const controller = createMessageQueueRuntimeController(coordinator, () => ({ transportIdentity: "t", generation: 1, isCurrent: () => false }))
  await controller.hydrate(null); expect((await controller.admit(item())).status).toBe("stale"); expect(controller.getState().snapshot.queues).toEqual({})
})
test("remove commits metadata before attachment release and reorder rollback keeps references", async () => {
  let writes = 0, fail = false
  const controller = setup(async () => ++writes && fail ? { ok: false as const, error: { code: "quota" as const } } : { ok: true as const, value: undefined })
  const first = item(), second = item("two"); await controller.hydrate(null); await controller.admit(first); await controller.admit(second); const before = controller.getState().snapshot.queues[identity(first).scopeKey]
  fail = true; expect((await controller.reorder(identity(first).scopeKey, [second.queueItemID, first.queueItemID])).status).toBe("failed"); expect(controller.getState().snapshot.queues[identity(first).scopeKey]).toBe(before)
})
test("bind preserves unbound identities and locked rows reject changes", async () => {
  const controller = setup(), first = unboundItem(), second = item("two"); await controller.hydrate({ version: 4, queues: { 'unbound-legacy:["s"]': [first], 'bound:["t","/d","s"]': [second] }, migration: { v3State: "complete" } })
  await controller.bind(legacyIdentity(first), { state: "bound", transportIdentity: "t", directory: "/other", sessionID: "s" }); const bound = controller.getState().snapshot.queues['bound:["t","/other","s"]']![0]!; expect([bound.queueItemID, bound.operationID, bound.messageID]).toEqual([first.queueItemID, first.operationID, first.messageID])
  await controller.transition(identity(second), "queued", (value) => ({ ...value, status: "sending", attemptCount: value.attemptCount + 1 })); expect((await controller.remove(identity(second))).errors[0]?.code).toBe("locked")
})
test("disable fences queued work and unchanged scopes retain their reference", async () => {
  const controller = setup(), first = item(); await controller.hydrate(null); await controller.admit(first); const queue = controller.getState().snapshot.queues[identity(first).scopeKey]; await controller.transition(identity(first), "queued", (value) => ({ ...value, status: "sending", attemptCount: value.attemptCount + 1 })); await controller.transition(identity(first), "sending", (value) => ({ ...value, status: "failed", failureKind: "definitive" })); expect(controller.getState().snapshot.queues[identity(first).scopeKey]).not.toBe(queue); await controller.setEnabled(false); expect((await controller.remove(identity(first))).status).toBe("disabled"); await controller.flush()
})
test("captures the default runtime before serialized work starts", async () => {
  let release: (() => void) | undefined, started: (() => void) | undefined, current = "t", writes = 0
  const writing = new Promise<void>((resolve) => { release = resolve })
  const began = new Promise<void>((resolve) => { started = resolve })
  const controller = createMessageQueueRuntimeController(createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { persist: async () => { writes++; started!(); await writing; return { ok: true as const, value: undefined } }, flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} }), () => ({ transportIdentity: current, generation: current === "t" ? 1 : 2, isCurrent: () => current === "t" }))
  await controller.hydrate(null)
  const blocking = controller.admit(item("blocking"))
  await began
  const admitted = controller.admit(unboundItem())
  current = "next"; release!()
  expect((await blocking).status).toBe("stale")
  expect((await admitted).status).toBe("stale")
  expect(writes).toBe(1)
  expect(controller.getState().snapshot.queues[identity(item("blocking")).scopeKey]?.map((entry) => entry.queueItemID)).toEqual(["blocking"])
})
test("bind adopts a durable baseline when commit completes after runtime currentness changes", async () => {
  let current = true, writes = 0
  const controller = createMessageQueueRuntimeController(createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { persist: async () => { if (++writes === 1) current = false; return { ok: true as const, value: undefined } }, flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} }), () => ({ transportIdentity: "t", generation: 1, isCurrent: () => current }))
  const queued = unboundItem(); await controller.hydrate({ version: 4, queues: { 'unbound-legacy:["s"]': [queued] }, migration: { v3State: "complete" } })
  const bound = await controller.bind(legacyIdentity(queued), { state: "bound", transportIdentity: "t", directory: "/next", sessionID: "s" })
  expect(bound.status).toBe("stale"); expect(bound.current).toBe(false)
  expect(controller.getState().snapshot.queues['bound:["t","/next","s"]']?.[0]?.queueItemID).toBe("legacy")
})
test("adopts durable admissions before reporting stale and preserves the baseline", async () => {
  let current = true, resolve: (() => void) | undefined, started: (() => void) | undefined, publications = 0
  const persisted = new Promise<void>((done) => { resolve = () => { current = false; done() } })
  const began = new Promise<void>((done) => { started = done })
  const controller = createMessageQueueRuntimeController(createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { persist: async () => { started!(); await persisted; return { ok: true as const, value: undefined } }, flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} }), () => ({ transportIdentity: "t", generation: 1, isCurrent: () => current }))
  await controller.hydrate(null); const unsubscribe = controller.subscribe(() => { publications++ }); const queued = item()
  const admitted = controller.admit(queued)
  await began; expect(publications).toBe(0)
  resolve!(); const outcome = await admitted; unsubscribe()
  expect(outcome.status).toBe("stale"); expect(outcome.current).toBe(false)
  expect(publications).toBe(1); expect(controller.getState().snapshot.queues[identity(queued).scopeKey]?.[0]?.queueItemID).toBe("q")
  current = true; expect((await controller.transition(identity(queued), "queued", (value) => ({ ...value, status: "sending", attemptCount: 1 }))).status).toBe("committed")
  expect(controller.getState().snapshot.queues[identity(queued).scopeKey]?.[0]?.status).toBe("sending")
})
test("adopts durable removals before reporting stale and keeps them removed", async () => {
  let current = true, writes = 0
  const controller = createMessageQueueRuntimeController(createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { persist: async () => { if (++writes === 1) current = false; return { ok: true as const, value: undefined } }, flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} }), () => ({ transportIdentity: "t", generation: 1, isCurrent: () => current }))
  const queued = item(); await controller.hydrate(snapshot(queued)); const removed = await controller.remove(identity(queued))
  expect(removed.status).toBe("stale"); expect(removed.current).toBe(false); expect(removed.durableRemoval).toBe(true); expect(controller.getState().snapshot.queues[identity(queued).scopeKey]).toBe(undefined)
  current = true; const next = item("next"); expect((await controller.admit(next)).status).toBe("committed")
  expect(controller.getState().snapshot.queues[identity(next).scopeKey]?.map((entry) => entry.queueItemID)).toEqual(["next"])
})

test("remove marks precommit failures non-durable and postcommit stale removals durable", async () => {
  const failing = setup(async () => ({ ok: false as const, error: { code: "quota" as const } })); const queued = item()
  await failing.hydrate(snapshot(queued)); const rejected = await failing.remove(identity(queued))
  expect(rejected.durableRemoval).toBe(false); expect(failing.getState().snapshot.queues[identity(queued).scopeKey]).toHaveLength(1)
  let current = true
  const controller = createMessageQueueRuntimeController(createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { persist: async () => { current = false; return { ok: true as const, value: undefined } }, flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} }), () => ({ transportIdentity: "t", generation: 1, isCurrent: () => current }))
  await controller.hydrate(snapshot(queued)); current = true
  const stale = await controller.remove(identity(queued))
  expect(stale.durableRemoval).toBe(true); expect(stale.status).toBe("stale")
})

test("materializeForEdit clones ordered values, releases its token, and preserves the queue row", async () => {
  const blobs = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), queued = item(); queued.attachments = [
    { version: 1, attachmentID: "first", occurrenceRefID: '["root","first"]', filename: "first", mimeType: "text/plain", size: 1, source: "local", locator: { kind: "blob", blobID: "b1" } },
    { version: 1, attachmentID: "url", occurrenceRefID: '["root","url"]', filename: "url", mimeType: "text/plain", size: 1, source: "server", serverPath: "/url", locator: { kind: "url", url: "https://example.com/url" } },
    { version: 1, attachmentID: "last", occurrenceRefID: '["root","last"]', filename: "last", mimeType: "text/plain", size: 1, source: "local", locator: { kind: "blob", blobID: "b2" } },
  ]
  const coordinator = createQueueAttachmentCoordinator(blobs, { persist: async () => ({ ok: true as const, value: undefined }), flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} })
  const controller = createMessageQueueRuntimeController(coordinator, runtime); await controller.hydrate(null)
  await blobs.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","first"]' }, "b1", new Blob(["1"])); await blobs.putAndRetain({ transportIdentity: "t", owner: { kind: "queue", ownerID: "q" }, attachmentOccurrenceRefID: '["root","last"]' }, "b2", new Blob(["2"])); await controller.admit(queued)
  const edited = await controller.materializeForEdit(identity(queued)); expect(edited.values?.map((entry) => entry.attachment.attachmentID)).toEqual(["first", "url", "last"]); expect(edited.values?.map((entry) => entry.value instanceof Blob ? "blob" : entry.value)).toEqual(["blob", "https://example.com/url", "blob"])
  expect(edited.token).toBeDefined(); expect(edited.item).toEqual(queued); expect(edited.item).not.toBe(queued); expect(edited.values?.[0]?.attachment).not.toBe(queued.attachments[0])
  edited.item!.content = "changed"; edited.values![0]!.attachment.filename = "changed"
  expect(controller.getState().snapshot.queues[identity(queued).scopeKey]?.[0]?.content).toBe("q"); expect(controller.getState().snapshot.queues[identity(queued).scopeKey]?.[0]?.attachments[0]?.filename).toBe("first")
  expect((await controller.acquireSendPayload(identity(queued))).errors[0]?.code).toBe("reserved"); await controller.releaseEditReservation(identity(queued), edited.token!); const reacquired = await controller.acquireSendPayload(identity(queued)); expect(reacquired.status).toBe("committed"); await controller.releaseSend(identity(queued), reacquired.token!); expect(controller.getState().snapshot.queues[identity(queued).scopeKey]).toHaveLength(1)
})

test("edit reservations fence dispatch work through draft commit and release independently", async () => {
  const controller = setup(), first = item(), second = item("other")
  await controller.hydrate(null); await controller.admit(first); await controller.admit(second)
  const reserved = await controller.materializeForEdit(identity(first))
  expect(reserved.status).toBe("committed"); expect(reserved.token).toBeDefined()
  expect((await controller.acquireSendPayload(identity(first))).errors[0]?.code).toBe("reserved")
  expect((await controller.transition(identity(first), "queued", (value) => ({ ...value, status: "sending", attemptCount: 1 }))).errors[0]?.code).toBe("reserved")
  const other = await controller.acquireSendPayload(identity(second))
  expect(other.status).toBe("committed"); await controller.releaseSend(identity(second), other.token!)
  await controller.releaseEditReservation(identity(first), reserved.token!)
  const released = await controller.acquireSendPayload(identity(first))
  expect(released.status).toBe("committed"); await controller.releaseSend(identity(first), released.token!)
})

test("only the edit removal capability mutates a reserved row", async () => {
  const controller = setup(), first = item(), second = item("other")
  await controller.hydrate(null); await controller.admit(first); await controller.admit(second)
  const reserved = await controller.materializeForEdit(identity(first))
  expect((await controller.remove(identity(first))).errors[0]?.code).toBe("reserved")
  expect((await controller.reorder(identity(first).scopeKey, [second.queueItemID, first.queueItemID])).errors[0]?.code).toBe("reserved")
  expect((await controller.bind(identity(first), { state: "bound", transportIdentity: "t", directory: "/next", sessionID: "s" })).errors[0]?.code).toBe("reserved")
  expect((await controller.bindMany([identity(first)], { state: "bound", transportIdentity: "t", directory: "/next", sessionID: "s" })).errors[0]?.code).toBe("reserved")
  expect((await controller.removeEditReservation(identity(first), reserved.token!)).durableRemoval).toBe(true)
})

test("disable, hydrate, and an old capture release reservation ownership", async () => {
  let generation = 1
  const controller = createMessageQueueRuntimeController(createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { persist: async () => ({ ok: true as const, value: undefined }), flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} }), () => ({ transportIdentity: "t", generation, isCurrent: () => true }))
  const first = item(); await controller.hydrate(null); await controller.admit(first)
  const captured = controller.captureRuntime(), reserved = await controller.materializeForEdit(identity(first), captured)
  generation = 2
  expect((await controller.releaseEditReservation(identity(first), reserved.token!, captured)).status).toBe("committed")
  const again = await controller.materializeForEdit(identity(first)); await controller.setEnabled(false); await controller.setEnabled(true)
  const acquired = await controller.acquireSendPayload(identity(first)); expect(acquired.status).toBe("committed")
  await controller.releaseSend(identity(first), acquired.token!)
  expect(again.token).toBeDefined()
})

test("failed release cleanup ends its reservation and permits another materialization", async () => {
  const fixture = releaseFixture("failed"); await fixture.controller.hydrate()
  const first = await fixture.controller.materializeForEdit(identity(fixture.queued))
  const released = await fixture.controller.releaseEditReservation(identity(fixture.queued), first.token!)
  expect(released.status).toBe("failed"); expect(released.cleanupErrors).toHaveLength(1); expect(fixture.releases()).toBe(1)
  expect((await fixture.controller.materializeForEdit(identity(fixture.queued))).status).toBe("committed"); expect(fixture.acquisitions()).toBe(2)
})

test("wrong reservation token preserves the matching token for later release", async () => {
  const fixture = releaseFixture("failed"); await fixture.controller.hydrate()
  const first = await fixture.controller.materializeForEdit(identity(fixture.queued))
  const wrong = await fixture.controller.releaseEditReservation(identity(fixture.queued), "wrong" as never)
  expect(wrong.status).toBe("stale"); expect(fixture.releases()).toBe(0)
  expect((await fixture.controller.materializeForEdit(identity(fixture.queued))).errors[0]?.code).toBe("reserved")
  expect((await fixture.controller.releaseEditReservation(identity(fixture.queued), first.token!)).status).toBe("failed"); expect(fixture.releases()).toBe(1)
})

test("release throw reports a stable error and clears the local reservation fence", async () => {
  const fixture = releaseFixture("throw"); await fixture.controller.hydrate()
  const first = await fixture.controller.materializeForEdit(identity(fixture.queued))
  const released = await fixture.controller.releaseEditReservation(identity(fixture.queued), first.token!)
  expect(released.status).toBe("failed"); expect(released.errors[0]?.code).toBe("reservation-release-threw"); expect(fixture.releases()).toBe(1)
  expect((await fixture.controller.materializeForEdit(identity(fixture.queued))).status).toBe("committed")
})

test("failed and thrown reservations clear through hydrate and disable lifecycle", async () => {
  for (const mode of ["failed", "throw"] as const) {
    const hydrated = releaseFixture(mode); await hydrated.controller.hydrate(); await hydrated.controller.materializeForEdit(identity(hydrated.queued)); await hydrated.controller.hydrate()
    expect((await hydrated.controller.materializeForEdit(identity(hydrated.queued))).status).toBe("committed"); expect(hydrated.releases()).toBe(1)
    const disabled = releaseFixture(mode); await disabled.controller.hydrate(); await disabled.controller.materializeForEdit(identity(disabled.queued)); await disabled.controller.setEnabled(false); await disabled.controller.setEnabled(true)
    expect((await disabled.controller.materializeForEdit(identity(disabled.queued))).status).toBe("committed"); expect(disabled.releases()).toBe(1)
  }
})
