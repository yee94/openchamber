import { expect, test } from "bun:test"
import type { QueueItemDTO } from "@/stores/message-queue-ledger"
import { sessionDraftKey } from "./input-draft-types"
import { createLazyMessageQueueEditBridge, createMessageQueueEditBridge } from "./message-queue-edit-bridge"
import type { DraftCommitInput, DraftCommitResult } from "./input-store"
import type { MessageQueueRemoveResult, MessageQueueRuntimeResult, QueueRuntimeCapture, ScopedQueueIdentity } from "./message-queue-runtime-controller"
import { createMessageQueueRuntimeController } from "./message-queue-runtime-controller"
import { createQueueAttachmentCoordinator } from "./queue-attachment-coordinator"
import { createInputDraftBlobStore, MemoryInputDraftBlobDriver } from "./input-draft-blob-store"
import { createMessageQueueDispatcher } from "./message-queue-dispatch"

const runtime: QueueRuntimeCapture = { transportIdentity: "t", generation: 1, isCurrent: () => true }
const identity: ScopedQueueIdentity = { scopeKey: 'bound:["t","/d","s"]', queueItemID: "q", operationID: "o", messageID: "m" }
const key = sessionDraftKey(runtime, "s")
const attachment = (id: string, locator: QueueItemDTO["attachments"][number]["locator"]): QueueItemDTO["attachments"][number] => ({ version: 1, attachmentID: id, occurrenceRefID: `["root","${id}"]`, filename: `${id}.txt`, mimeType: "text/plain", size: 1, source: locator.kind === "url" ? "server" : "local", ...(locator.kind === "url" ? { serverPath: `/${id}` } : {}), locator })
const item = (): QueueItemDTO => ({ version: 1, ...identity, owner: { state: "bound", transportIdentity: "t", directory: "/d", sessionID: "s" }, content: "queued", attachments: [attachment("blob", { kind: "blob", blobID: "b" }), attachment("url", { kind: "url", url: "https://example.test/url" })], attachmentIssues: [], createdAt: 1, status: "queued", attemptCount: 0 })
const materialized = (value = item()): MessageQueueRuntimeResult => ({ status: "committed", current: true, errors: [], cleanupErrors: [], token: "edit" as never, item: value, values: [
  { attachment: value.attachments[1]!, value: "https://example.test/url" }, { attachment: value.attachments[0]!, value: new Blob(["x"]) },
] })
const draft = (durable = true, current = true): DraftCommitResult => ({ status: durable ? "committed" : "conflict", durable, current, errors: [], cleanupErrors: [] })
const removal = (durableRemoval = true, current = true): MessageQueueRemoveResult => ({ status: current ? "committed" : "stale", durableRemoval, current, errors: [], cleanupErrors: [] })

test("bridges mixed values in queue order and retains durable metadata", async () => {
  let committed: DraftCommitInput | undefined, removes = 0
  const bridge = createMessageQueueEditBridge({ queue: { materializeForEdit: async () => materialized(), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => { removes++; return removal() } }, commitDraftSnapshot: async (input) => { committed = input; return draft() } })
  const result = await bridge.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  expect(result.status).toBe("committed"); expect(result.current).toBe(true); expect(removes).toBe(1)
  expect(committed?.snapshot.attachments.map((value) => value.attachmentID)).toEqual(["blob", "url"])
  expect(committed?.values?.get('["root","url"]')).toBe("https://example.test/url")
  expect(committed?.snapshot.syntheticParts).toEqual([]); expect(committed?.snapshot.mentions).toEqual([])
})

test("gates mismatched captures before either owner call", async () => {
  let materializes = 0, commits = 0
  const bridge = createMessageQueueEditBridge({ queue: { materializeForEdit: async () => { materializes++; return materialized() }, releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => removal() }, commitDraftSnapshot: async () => { commits++; return draft() } })
  const outcome = await bridge.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: { transportIdentity: "other", generation: 2 } })
  expect(outcome.status).toBe("materialize-failed"); expect(materializes).toBe(0); expect(commits).toBe(0)
})

test("retains queued work for rejected drafts and precommit removal failures", async () => {
  let capabilityRemovals = 0
  const rejected = createMessageQueueEditBridge({ queue: { materializeForEdit: async () => materialized(), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => { capabilityRemovals++; return removal() } }, commitDraftSnapshot: async () => draft(false) })
  expect((await rejected.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })).status).toBe("draft-rejected"); expect(capabilityRemovals).toBe(0)
  const retained = createMessageQueueEditBridge({ queue: { materializeForEdit: async () => materialized(), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => removal(false) }, commitDraftSnapshot: async () => draft(true, false) })
  const outcome = await retained.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: 3, inputRuntime: runtime })
  expect(outcome.status).toBe("queue-retained"); expect(outcome.draftDurable).toBe(true); expect(outcome.queueDurablyRemoved).toBe(false)
})

test("rejects attachment issues and malformed materialization payloads", async () => {
  let commits = 0
  const issue = item(); issue.attachmentIssues = [{ attachmentID: "blob", occurrenceRefID: '["root","blob"]', filename: "blob.txt", mimeType: "text/plain", size: 1, source: "local", reason: "missing-blob" }]
  const bridge = createMessageQueueEditBridge({ queue: { materializeForEdit: async () => materialized(issue), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => removal() }, commitDraftSnapshot: async () => { commits++; return draft() } })
  const issueResult = await bridge.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  expect(issueResult.status).toBe("materialize-failed"); expect(issueResult.attachmentIssues).toEqual(issue.attachmentIssues); expect(commits).toBe(0)
  const broken = materialized(); broken.values = [broken.values![0]!, broken.values![0]!]
  const invalid = createMessageQueueEditBridge({ queue: { materializeForEdit: async () => broken, releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => removal() }, commitDraftSnapshot: async () => draft() })
  expect((await invalid.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })).status).toBe("materialize-failed")
})

test("rejects missing roots and mismatched values before draft commit", async () => {
  for (const mutate of [
    (value: MessageQueueRuntimeResult) => { value.values = value.values?.slice(0, 1) },
    (value: MessageQueueRuntimeResult) => { value.values![0] = { ...value.values![0]!, value: "https://example.test/other" } },
    (value: MessageQueueRuntimeResult) => { value.values![0] = { ...value.values![0]!, attachment: { ...value.values![0]!.attachment, occurrenceRefID: '["part","p","blob"]' } } },
  ]) {
    let commits = 0
    const broken = materialized(); mutate(broken)
    const bridge = createMessageQueueEditBridge({ queue: { materializeForEdit: async () => broken, releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => removal() }, commitDraftSnapshot: async () => { commits++; return draft() } })
    const outcome = await bridge.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
    expect(outcome.status).toBe("materialize-failed"); expect(outcome.diagnostics[0]?.stage).toBe("attachments"); expect(commits).toBe(0)
  }
})

test("removes after durable post-commit stale drafts and retains queue on remove throw", async () => {
  let removes = 0
  const staleDraft = createMessageQueueEditBridge({ queue: { materializeForEdit: async () => materialized(), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => { removes++; return removal(true, false) } }, commitDraftSnapshot: async () => draft(true, false) })
  const stale = await staleDraft.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  expect(removes).toBe(1); expect(stale.status).toBe("committed"); expect(stale.current).toBe(false)
  const throwing = createMessageQueueEditBridge({ queue: { materializeForEdit: async () => materialized(), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => { throw new Error("remove") } }, commitDraftSnapshot: async () => draft() })
  const retained = await throwing.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  expect(retained.status).toBe("queue-retained"); expect(retained.diagnostics).toEqual([{ stage: "remove", code: "threw" }])
})

test("releases edit reservations after attachment, draft, and removal outcomes", async () => {
  const issue = item(); issue.attachmentIssues = [{ attachmentID: "blob", occurrenceRefID: '["root","blob"]', filename: "blob.txt", mimeType: "text/plain", size: 1, source: "local", reason: "missing-blob" }]
  for (const [source, commit, capabilityRemove] of [
    [materialized(issue), async () => draft(), async () => removal()],
    [materialized(), async () => draft(false), async () => removal()],
    [materialized(), async () => draft(), async () => removal(false)],
  ] as const) {
    let releases = 0
    const bridge = createMessageQueueEditBridge({ queue: { materializeForEdit: async () => source, releaseEditReservation: async () => { releases++; return { status: "committed", errors: [], cleanupErrors: [] } }, removeEditReservation: capabilityRemove }, commitDraftSnapshot: commit })
    await bridge.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
    expect(releases).toBe(1)
  }
})

test("coalesces the same queue identity and runs different identities concurrently", async () => {
  let materializes = 0, releaseSame!: () => void, releaseOther!: () => void
  const sameGate = new Promise<void>((resolve) => { releaseSame = resolve })
  const otherGate = new Promise<void>((resolve) => { releaseOther = resolve })
  const other = { ...identity, queueItemID: "q-other", operationID: "o-other", messageID: "m-other" }
  const bridge = createMessageQueueEditBridge({
    queue: {
      materializeForEdit: async (value) => { materializes++; await (value.queueItemID === identity.queueItemID ? sameGate : otherGate); return materialized() },
      releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }),
      removeEditReservation: async () => removal(),
    },
    commitDraftSnapshot: async () => draft(),
  })
  const first = bridge.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  const second = bridge.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  const concurrent = bridge.edit({ identity: other, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  expect(first).toBe(second); await Promise.resolve(); expect(materializes).toBe(2)
  releaseOther(); await concurrent; releaseSame(); await first
})

test("lazy bridge obtains owners only when edit starts", async () => {
  let queues = 0, inputs = 0
  const lazy = createLazyMessageQueueEditBridge({
    getQueue: () => { queues++; return { captureRuntime: () => runtime, materializeForEdit: async () => materialized(), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => removal() } },
    getInput: () => { inputs++; return { captureDraftRuntime: () => runtime, commitDraftSnapshot: async () => draft() } },
  })
  expect(queues).toBe(0); expect(inputs).toBe(0)
  await lazy.edit({ identity, targetKey: key, expectedRevision: "absent" })
  expect(queues).toBe(1); expect(inputs).toBe(1)
})

test("lazy bridge rebuilds execution context for replacement owners", async () => {
  let active = "a", materializedBy = "", committedBy = "", removedBy = ""
  const queue = (name: string) => ({ captureRuntime: () => runtime, materializeForEdit: async () => { materializedBy = name; return materialized() }, releaseEditReservation: async () => ({ status: "committed" as const, errors: [], cleanupErrors: [] }), removeEditReservation: async () => { removedBy = name; return removal() } })
  const input = (name: string) => ({ captureDraftRuntime: () => runtime, commitDraftSnapshot: async () => { committedBy = name; return draft() } })
  const lazy = createLazyMessageQueueEditBridge({ getQueue: () => queue(active), getInput: () => input(active) })
  await lazy.edit({ identity, targetKey: key, expectedRevision: "absent" })
  active = "b"
  await lazy.edit({ identity: { ...identity, queueItemID: "q-b", operationID: "o-b", messageID: "m-b" }, targetKey: key, expectedRevision: "absent" })
  expect(materializedBy).toBe("b"); expect(committedBy).toBe("b"); expect(removedBy).toBe("b")
})

test("lazy identity flight spans state wrappers and releases before the next owner", async () => {
  let resolveMaterialize!: (value: MessageQueueRuntimeResult) => void, calls = 0, active = "a"
  const pending = new Promise<MessageQueueRuntimeResult>((resolve) => { resolveMaterialize = resolve })
  const queue = () => ({ captureRuntime: () => runtime, materializeForEdit: async () => { calls++; return active === "a" ? pending : materialized() }, releaseEditReservation: async () => ({ status: "committed" as const, errors: [], cleanupErrors: [] }), removeEditReservation: async () => removal() })
  const stableCommit = async () => draft()
  const lazy = createLazyMessageQueueEditBridge({ getQueue: queue, getInput: () => ({ captureDraftRuntime: () => runtime, commitDraftSnapshot: stableCommit }) })
  const first = lazy.edit({ identity, targetKey: key, expectedRevision: "absent" })
  const second = lazy.edit({ identity, targetKey: key, expectedRevision: "absent" })
  expect(first).toBe(second); expect(calls).toBe(1)
  resolveMaterialize(materialized()); await first
  active = "b"
  expect((await lazy.edit({ identity, targetKey: key, expectedRevision: "absent" })).status).toBe("committed"); expect(calls).toBe(2)
})

test("durable capability removal reports cleanup without exposing payload", async () => {
  const bridge = createMessageQueueEditBridge({ queue: { materializeForEdit: async () => materialized(), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => ({ ...removal(), cleanupErrors: [{ phase: "blob", code: "transaction-failed" }] }) }, commitDraftSnapshot: async () => draft() })
  const outcome = await bridge.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  expect(outcome.status).toBe("committed"); expect(outcome.diagnostics).toEqual([{ stage: "cleanup", code: "remove-cleanup" }])
})

test("failure results omit queued body, attachment values, and draft records", async () => {
  const secret = item(); secret.content = "body-marker"; secret.attachments[1] = attachment("url", { kind: "url", url: "https://example.test/url-marker" })
  const source = materialized(secret); source.values![1] = { attachment: secret.attachments[0]!, value: new Blob(["blob-marker"]) }
  const attachmentFailure = await createMessageQueueEditBridge({ queue: { materializeForEdit: async () => source, releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => removal() }, commitDraftSnapshot: async () => draft() }).edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  const record = { version: 1 as const, key, revision: 1, text: "draft-marker", attachments: [], syntheticParts: [], mentions: [] }
  const draftFailure = await createMessageQueueEditBridge({ queue: { materializeForEdit: async () => materialized(secret), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => removal() }, commitDraftSnapshot: async () => ({ ...draft(false), record }) }).edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  const removalFailure = await createMessageQueueEditBridge({ queue: { materializeForEdit: async () => materialized(secret), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => ({ ...removal(false), item: secret, values: source.values }) }, commitDraftSnapshot: async () => ({ ...draft(), record }) }).edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  for (const outcome of [attachmentFailure, draftFailure, removalFailure]) {
    const serialized = JSON.stringify(outcome)
    expect(serialized.includes("body-marker")).toBe(false); expect(serialized.includes("url-marker")).toBe(false); expect(serialized.includes("blob-marker")).toBe(false); expect(serialized.includes("draft-marker")).toBe(false)
  }
})

test("lazy getter and capture failures return stable diagnostics", async () => {
  const cases = [
    createLazyMessageQueueEditBridge({ getQueue: () => { throw new Error("queue") }, getInput: () => ({ captureDraftRuntime: () => runtime, commitDraftSnapshot: async () => draft() }) }),
    createLazyMessageQueueEditBridge({ getQueue: () => ({ captureRuntime: () => { throw new Error("capture") }, materializeForEdit: async () => materialized(), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => removal() }), getInput: () => ({ captureDraftRuntime: () => runtime, commitDraftSnapshot: async () => draft() }) }),
    createLazyMessageQueueEditBridge({ getQueue: () => ({ captureRuntime: () => runtime, materializeForEdit: async () => materialized(), releaseEditReservation: async () => ({ status: "committed", errors: [], cleanupErrors: [] }), removeEditReservation: async () => removal() }), getInput: () => { throw new Error("input") } }),
  ]
  for (const lazy of cases) {
    const outcome = await lazy.edit({ identity, targetKey: key, expectedRevision: "absent" })
    expect(outcome.status).toBe("materialize-failed"); expect(outcome.diagnostics[0]?.stage).toBe("identity")
  }
})

test("controlled draft commit reserves its queue identity against concurrent dispatch", async () => {
  const queued = item() as QueueItemDTO & { scopeKey?: string }; delete queued.scopeKey; queued.attachments = []
  const controller = createMessageQueueRuntimeController(createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { persist: async () => ({ ok: true as const, value: undefined }), flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} }), () => runtime)
  await controller.hydrate(null); await controller.admit(queued)
  let resolveDraft!: (value: DraftCommitResult) => void, reservationReady!: () => void, posts = 0
  const reserved = new Promise<void>((resolve) => { reservationReady = resolve })
  const pendingDraft = new Promise<DraftCommitResult>((resolve) => { resolveDraft = resolve })
  const bridge = createMessageQueueEditBridge({ queue: { materializeForEdit: async (value, capture) => { const result = await controller.materializeForEdit(value, capture); reservationReady(); return result }, releaseEditReservation: (value, token, capture) => controller.releaseEditReservation(value, token, capture), removeEditReservation: (value, token, capture) => controller.removeEditReservation(value, token, capture) }, commitDraftSnapshot: async () => pendingDraft })
  const dispatcher = createMessageQueueDispatcher({ runtime: controller, post: async () => { posts++ }, query: async () => "unavailable", classifyFailure: () => "pre-dispatch", notifyConfirmed: () => {} })
  const editing = bridge.edit({ identity, queueRuntime: runtime, targetKey: key, expectedRevision: "absent", inputRuntime: runtime })
  await reserved
  expect(await dispatcher.dispatch(identity)).toBe("failed"); expect(posts).toBe(0)
  resolveDraft(draft())
  expect((await editing).status).toBe("committed")
})
