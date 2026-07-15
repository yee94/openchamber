import { expect, test } from "bun:test"
import { createMessageQueueDispatcher, planMessageQueueWork, type QueueDispatcherDependencies } from "./message-queue-dispatch"
import type { QueueItemDTO, QueueLedgerSnapshotV4 } from "@/stores/message-queue-ledger"
import type { QueueSendToken } from "./queue-attachment-coordinator"
import { createInputDraftBlobStore, MemoryInputDraftBlobDriver } from "./input-draft-blob-store"
import { createMessageQueueRuntimeController } from "./message-queue-runtime-controller"
import { createQueueAttachmentCoordinator } from "./queue-attachment-coordinator"

const scopeKey = 'bound:["t","/d","s"]'
const id = { scopeKey, queueItemID: "q", operationID: "o-q", messageID: "m-q" }
const item = (name = "q"): QueueItemDTO => ({ version: 1, queueItemID: name, operationID: `o-${name}`, messageID: `m-${name}`, owner: { state: "bound", transportIdentity: "t", directory: "/d", sessionID: "s" }, content: name, attachments: [], attachmentIssues: [], createdAt: 1, status: "queued", attemptCount: 0 })
const deferred = <T>() => { let resolve!: (value: T) => void; let reject!: (reason?: unknown) => void; const promise = new Promise<T>((ok, fail) => { resolve = ok; reject = fail }); return { promise, resolve, reject } }

const reconciling = (value: QueueItemDTO, fields: Partial<QueueItemDTO> = {}): QueueItemDTO => ({ ...value, status: "reconciling", failureKind: "ambiguous-dispatch", reconciliationStartedAt: 1, reconciliationDeadlineAt: 100, reconciliationChecks: 0, reconciliationNextCheckAt: 1, ...fields })
const realHarness = (persist: () => Promise<{ ok: true; value: undefined }> = async () => ({ ok: true, value: undefined })) => {
  let current = true, releases = 0
  const controller = createMessageQueueRuntimeController(createQueueAttachmentCoordinator(createInputDraftBlobStore(new MemoryInputDraftBlobDriver()), { persist, flush: async () => {}, setEnabled: async () => {}, cancelPending: () => {} }), () => ({ transportIdentity: "t", generation: 1, isCurrent: () => current }))
  const release = controller.releaseSend.bind(controller)
  controller.releaseSend = async (...args) => { releases++; return release(...args) }
  return { controller, setCurrent: (value: boolean) => { current = value }, get releases() { return releases } }
}

const harness = (options: Partial<QueueDispatcherDependencies> = {}) => {
  let value: QueueItemDTO | undefined = item()
  const log: string[] = [], token = "1" as QueueSendToken
  const capture = { transportIdentity: "t", generation: 1, isCurrent: () => true }
  const runtime: QueueDispatcherDependencies["runtime"] = {
    captureRuntime: () => capture,
    getState: () => ({ hydration: "ready", issues: [], enabled: true, snapshot: { version: 4, queues: value ? { [scopeKey]: [value] } : {} as Record<string, QueueItemDTO[]>, migration: { v3State: "complete" } } }),
    acquireSendPayload: async () => { log.push("acquire"); return { status: "committed", errors: [], cleanupErrors: [], token, values: [] } },
    releaseSend: async () => { log.push("release"); return { status: "committed", errors: [], cleanupErrors: [] } },
    transition: async (_identity, _expected, update) => { log.push("transition"); value = update(value!); return { status: "committed", errors: [], cleanupErrors: [] } },
    confirm: async () => { log.push("confirm"); value = undefined; return { status: "committed", errors: [], cleanupErrors: [] } },
  }
  const deps: QueueDispatcherDependencies = { runtime, post: async (_scope, _payload, options) => { log.push("post"); options.onSendConfirmed(id.messageID) }, query: async () => "unavailable", classifyFailure: () => "pre-dispatch", notifyConfirmed: () => { log.push("notify") }, ...options }
  return { dispatcher: createMessageQueueDispatcher(deps), runtime, log, get value() { return value }, set value(next: QueueItemDTO | undefined) { value = next }, capture }
}

test("按 acquire、sending、POST、confirm、notify 顺序确认", async () => {
  const h = harness(); expect(await h.dispatcher.dispatch(id)).toBe("confirmed")
  expect(h.log).toEqual(["acquire", "transition", "post", "confirm", "notify"])
})

test("materialize 抛错返回 failed 且 POST 为零", async () => {
  const h = harness(); h.runtime.acquireSendPayload = async () => { throw Error("blob") }
  expect(await h.dispatcher.dispatch(id)).toBe("failed"); expect(h.log).toEqual([])
})

test("sending transition failed 清理 token 且 POST 为零", async () => {
  const h = harness(); h.runtime.transition = async () => ({ status: "failed", errors: [], cleanupErrors: [] })
  expect(await h.dispatcher.dispatch(id)).toBe("failed"); expect(h.log).toEqual(["acquire", "release"])
})

test("sending transition throw 清理 token", async () => {
  const h = harness(); h.runtime.transition = async () => { throw Error("write") }
  expect(await h.dispatcher.dispatch(id)).toBe("failed"); expect(h.log).toEqual(["acquire", "release"])
})

test("deferred callback 使 dispatch 等待 confirmation", async () => {
  const wait = deferred<void>(), h = harness({ post: async (_scope, _payload, options) => { h.log.push("post"); options.onSendConfirmed(id.messageID) }, notifyConfirmed: () => { h.log.push("notify") } })
  h.runtime.confirm = async () => { h.log.push("confirm"); await wait.promise; h.value = undefined; return { status: "committed", errors: [], cleanupErrors: [] } }
  const work = h.dispatcher.dispatch(id); await new Promise((resolve) => setTimeout(resolve, 1)); expect(h.log).toEqual(["acquire", "transition", "post", "confirm"])
  wait.resolve(); expect(await work).toBe("confirmed")
})

test("callback confirmation failed 释放本次 token", async () => {
  const h = harness(); h.runtime.confirm = async () => ({ status: "failed", errors: [], cleanupErrors: [] })
  expect(await h.dispatcher.dispatch(id)).toBe("failed"); expect(h.log).toEqual(["acquire", "transition", "post", "release"])
})

test("callback confirmation stale 释放本次 token", async () => {
  const h = harness(); h.runtime.confirm = async () => ({ status: "stale", errors: [], cleanupErrors: [] })
  expect(await h.dispatcher.dispatch(id)).toBe("stale"); expect(h.log).toEqual(["acquire", "transition", "post", "release"])
})

test("callback 后 POST reject 采用 confirmation 结果", async () => {
  const h = harness({ post: async (_scope, _payload, options) => { options.onSendConfirmed(id.messageID); throw Error("late") } })
  h.runtime.confirm = async () => ({ status: "failed", errors: [], cleanupErrors: [] })
  expect(await h.dispatcher.dispatch(id)).toBe("failed"); expect(h.log.filter((entry) => entry === "release")).toHaveLength(1)
})

test("重复 callback 与错误 ID 只确认一次", async () => {
  const h = harness({ post: async (_scope, _payload, options) => { options.onSendConfirmed("wrong"); options.onSendConfirmed(id.messageID); options.onSendConfirmed(id.messageID) } })
  expect(await h.dispatcher.dispatch(id)).toBe("confirmed"); expect(h.log.filter((entry) => entry === "confirm")).toHaveLength(1)
})

test("同 identity dispatch 共享 promise 和一个 POST", async () => {
  const hold = deferred<void>(), h = harness({ post: async (_scope, _payload, options) => { h.log.push("post"); options.onSendConfirmed(id.messageID); await hold.promise } })
  const first = h.dispatcher.dispatch(id), second = h.dispatcher.dispatch(id); expect(first).toBe(second); hold.resolve()
  expect(await first).toBe("confirmed"); expect(h.log.filter((entry) => entry === "post")).toHaveLength(1)
})

test("dispatch 与 reconcile 共享 identity flight", async () => {
  const hold = deferred<void>(), h = harness({ post: async (_scope, _payload, options) => { options.onSendConfirmed(id.messageID); await hold.promise } })
  const first = h.dispatcher.dispatch(id), second = h.dispatcher.reconcile(id); expect(first).toBe(second); hold.resolve(); await first
})

test("pre-dispatch、definitive、ambiguous 返回各自状态并释放", async () => {
  for (const [kind, result] of [["pre-dispatch", "pending"], ["definitive-rejection", "failed"], ["ambiguous-dispatched", "pending"]] as const) {
    const h = harness({ post: async () => { throw Error("post") }, classifyFailure: () => kind })
    expect(await h.dispatcher.dispatch(id)).toBe(result); expect(h.log.filter((entry) => entry === "release")).toHaveLength(1)
  }
})

test("classify、delay、attempt overflow 都返回 failed 并释放", async () => {
  const classify = harness({ post: async () => { throw Error("post") }, classifyFailure: () => { throw Error("classify") } }); expect(await classify.dispatcher.dispatch(id)).toBe("failed"); expect(classify.log).toContain("release")
  const delay = harness({ post: async () => { throw Error("post") }, retryDelayMs: () => { throw Error("delay") } }); expect(await delay.dispatcher.dispatch(id)).toBe("failed"); expect(delay.log).toContain("release")
  const overflow = harness(); overflow.value!.attemptCount = Number.MAX_SAFE_INTEGER; expect(await overflow.dispatcher.dispatch(id)).toBe("failed"); expect(overflow.log).toContain("release")
})

test("ambiguous deadline overflow 返回 failed 且仅释放一次", async () => {
  const h = harness({ now: () => Number.MAX_SAFE_INTEGER, post: async () => { throw Error("post") }, classifyFailure: () => "ambiguous-dispatched", reconciliationDeadlineMs: 1 })
  expect(await h.dispatcher.dispatch(id)).toBe("failed"); expect(h.log.filter((entry) => entry === "release")).toHaveLength(1)
})

test("capture.isCurrent 抛错返回 skipped 或 stale 且公开方法不 reject", async () => {
  const h = harness(); h.capture.isCurrent = () => { throw Error("switch") }
  expect(await h.dispatcher.dispatch(id)).toBe("skipped")
})

test("reconcile confirmed、unavailable、query throw 保持结构化结果", async () => {
  const h = harness({ now: () => 10 }); h.value!.status = "reconciling"; h.value!.failureKind = "ambiguous-dispatch"; h.value!.reconciliationStartedAt = 1; h.value!.reconciliationDeadlineAt = 100; h.value!.reconciliationChecks = 0; h.value!.reconciliationNextCheckAt = 1
  expect(await h.dispatcher.reconcile(id)).toBe("pending")
  const thrower = harness({ now: () => 10, query: async () => { throw Error("GET") } }); thrower.value!.status = "reconciling"; thrower.value!.failureKind = "ambiguous-dispatch"; thrower.value!.reconciliationStartedAt = 1; thrower.value!.reconciliationDeadlineAt = 100; thrower.value!.reconciliationChecks = 0; thrower.value!.reconciliationNextCheckAt = 1
  expect(await thrower.dispatcher.reconcile(id)).toBe("pending")
})

test("reconcile confirmed 移除队列并通知", async () => {
  const h = harness({ now: () => 10, query: async () => "confirmed" }); h.value!.status = "reconciling"; h.value!.failureKind = "ambiguous-dispatch"; h.value!.reconciliationStartedAt = 1; h.value!.reconciliationDeadlineAt = 100; h.value!.reconciliationChecks = 0; h.value!.reconciliationNextCheckAt = 1
  expect(await h.dispatcher.reconcile(id)).toBe("confirmed"); expect(h.log).toEqual(["confirm", "notify"])
})

test("recover 将 sending 转入 reconciling 且 POST 为零", async () => {
  const h = harness({ now: () => 10 }); h.value!.status = "sending"; h.value!.attemptCount = 1
  expect(await h.dispatcher.recover(id)).toBe("pending"); expect(h.log).toEqual(["transition"])
})

test("planner 覆盖 head、nearest wake、flight skip 与 sending recovery", () => {
  const sending = item(); sending.status = "sending"
  const retry = item("r"); retry.status = "retrying"; retry.failureKind = "pre-dispatch"; retry.nextAttemptAt = 30
  const reconciling = item("x"); reconciling.status = "reconciling"; reconciling.failureKind = "ambiguous-dispatch"; reconciling.reconciliationStartedAt = 1; reconciling.reconciliationDeadlineAt = 100; reconciling.reconciliationChecks = 0; reconciling.reconciliationNextCheckAt = 20
  const snapshot: QueueLedgerSnapshotV4 = { version: 4, queues: { a: [sending], b: [retry], c: [reconciling] }, migration: { v3State: "complete" } }
  const plan = planMessageQueueWork(snapshot, "t", 10); expect(plan.recover).toHaveLength(1); expect(plan.nextWakeAt).toBe(20); expect(plan.inspectedScopeCount).toBe(3)
})

test("notification throw 保留 confirmed 且不会重复 POST", async () => {
  const h = harness({ notifyConfirmed: () => { throw Error("toast") } }); expect(await h.dispatcher.dispatch(id)).toBe("confirmed"); expect(h.log.filter((entry) => entry === "post")).toHaveLength(1)
})

test("current:false 在 durable sending 后返回 stale、释放 token，恢复后只 recover", async () => {
  let writes = 0
  const h = realHarness(async () => { writes++; if (writes === 2) h.setCurrent(false); return { ok: true, value: undefined } })
  await h.controller.hydrate(null); expect((await h.controller.admit(item())).status).toBe("committed")
  let posts = 0
  const dispatcher = createMessageQueueDispatcher({ runtime: h.controller, post: async () => { posts++ }, query: async () => "unavailable", classifyFailure: () => "pre-dispatch", notifyConfirmed: () => {} })
  expect(await dispatcher.dispatch(id)).toBe("stale")
  expect(h.controller.getState().snapshot.queues[scopeKey]![0]!.status).toBe("sending")
  expect(h.releases).toBe(1); expect(posts).toBe(0)
  h.setCurrent(true); expect(await dispatcher.recover(id)).toBe("pending")
  expect(h.controller.getState().snapshot.queues[scopeKey]![0]!.status).toBe("reconciling"); expect(h.controller.getState().snapshot.queues[scopeKey]![0]!.reconciliationChecks).toBe(0)
  expect(posts).toBe(0)
})

test("authoritative miss 精确递增 checks 并写入 next-check", async () => {
  const h = harness({ now: () => 10, reconciliationDelayMs: () => 7, query: async () => "authoritative-miss" }); h.value = reconciling(h.value!)
  expect(await h.dispatcher.reconcile(id)).toBe("pending")
  expect(h.value!.reconciliationChecks).toBe(1); expect(h.value!.reconciliationNextCheckAt).toBe(17); expect(h.value!.status).toBe("reconciling")
  expect(h.log).toEqual(["transition"])
})

test("unavailable 和 query throw 保持 checks 并推进 next-check", async () => {
  for (const query of [async () => "unavailable" as const, async () => { throw Error("GET") }]) {
    const h = harness({ now: () => 10, reconciliationDelayMs: () => 7, query }); h.value = reconciling(h.value!, { reconciliationChecks: 2 })
    expect(await h.dispatcher.reconcile(id)).toBe("pending")
    expect(h.value!.reconciliationChecks).toBe(2); expect(h.value!.reconciliationNextCheckAt).toBe(17)
    expect(h.log).toEqual(["transition"])
  }
})

test("query 期间越过 deadline 与 maxChecks=1 的 miss 同轮 unresolved", async () => {
  let clock = 10
  const late = harness({ now: () => clock, query: async () => { clock = 100; return "unavailable" } }); late.value = reconciling(late.value!)
  expect(await late.dispatcher.reconcile(id)).toBe("unresolved"); expect(late.value!.status).toBe("unresolved"); expect(late.value!.reconciliationChecks).toBe(0)
  const exhausted = harness({ now: () => 10, maxReconciliationChecks: 1, query: async () => "authoritative-miss" }); exhausted.value = reconciling(exhausted.value!)
  expect(await exhausted.dispatcher.reconcile(id)).toBe("unresolved"); expect(exhausted.value!.status).toBe("unresolved"); expect(exhausted.value!.reconciliationChecks).toBe(1)
})

test("reconciliation transition failed、stale 与 throw 保持结构化结果且零 confirm/notify", async () => {
  for (const outcome of ["failed", "stale"] as const) {
    const h = harness({ now: () => 10, query: async () => "authoritative-miss" }); h.value = reconciling(h.value!); h.runtime.transition = async () => ({ status: outcome, errors: [], cleanupErrors: [] })
    expect(await h.dispatcher.reconcile(id)).toBe(outcome); expect(h.log).toEqual([])
  }
  const throwing = harness({ now: () => 10, query: async () => "authoritative-miss" }); throwing.value = reconciling(throwing.value!); throwing.runtime.transition = async () => { throw Error("transition") }
  expect(await throwing.dispatcher.reconcile(id)).toBe("failed"); expect(throwing.log).toEqual([])
})

test("query 完成后 runtime 切换时 verdict 不会写回", async () => {
  const wait = deferred<"authoritative-miss">(), h = harness({ now: () => 10, query: async () => wait.promise }); h.value = reconciling(h.value!)
  const work = h.dispatcher.reconcile(id); h.capture.isCurrent = () => false; wait.resolve("authoritative-miss")
  expect(await work).toBe("stale"); expect(h.value!.status).toBe("reconciling"); expect(h.value!.reconciliationChecks).toBe(0); expect(h.value!.reconciliationNextCheckAt).toBe(1); expect(h.log).toEqual([])
})

test("persisted sending recover 写入精确字段，flight 期间 plan 跳过并共享 identity", async () => {
  const h = harness({ now: () => 10, reconciliationDeadlineMs: 40 }); h.value!.status = "sending"; h.value!.attemptCount = 3
  expect(await h.dispatcher.recover(id)).toBe("pending")
  expect(h.value!.status).toBe("reconciling"); expect(h.value!.reconciliationStartedAt).toBe(10); expect(h.value!.reconciliationDeadlineAt).toBe(50); expect(h.value!.reconciliationChecks).toBe(0); expect(h.value!.reconciliationNextCheckAt).toBe(10)
  expect(h.log.filter((entry) => entry === "post")).toHaveLength(0)
  const hold = deferred<void>(), active = harness({ post: async (_scope, _payload, options) => { active.log.push("post"); options.onSendConfirmed(id.messageID); await hold.promise } })
  const dispatch = active.dispatcher.dispatch(id); expect(active.dispatcher.plan().recover).toEqual([]); expect(active.dispatcher.recover(id)).toBe(dispatch); expect(active.dispatcher.reconcile(id)).toBe(dispatch)
  hold.resolve(); await dispatch; expect(active.log.filter((entry) => entry === "post")).toHaveLength(1)
})

test("planner 只检查每 scope head，并计算唯一最近 wake", () => {
  const failed = item("failed"); failed.status = "failed"
  const unresolved = reconciling(item("unresolved"), { status: "unresolved" })
  const queued = item("queued"), later = item("later"); later.status = "retrying"; later.nextAttemptAt = 20
  const retry = item("retry"); retry.status = "retrying"; retry.nextAttemptAt = 30
  const snapshot: QueueLedgerSnapshotV4 = { version: 4, queues: { failed: [failed, queued], unresolved: [unresolved, queued], retry: [retry, later] }, migration: { v3State: "complete" } }
  const plan = planMessageQueueWork(snapshot, "t", 10); expect(plan.dispatch).toEqual([]); expect(plan.query).toEqual([]); expect(plan.resolve).toEqual([]); expect(plan.recover).toEqual([]); expect(plan.nextWakeAt).toBe(30); expect(plan.inspectedScopeCount).toBe(3)
})

test("GET confirmed 与 POST callback 同 identity flight 只 confirm/notify 一次", async () => {
  const entered = deferred<void>(), release = deferred<void>(), h = harness({ now: () => 10, query: async () => { entered.resolve(); await release.promise; return "confirmed" }, post: async (_scope, _payload, options) => { options.onSendConfirmed(id.messageID) } })
  h.value = reconciling(h.value!)
  const query = h.dispatcher.reconcile(id); await entered.promise
  const post = h.dispatcher.dispatch(id); expect(post).toBe(query)
  release.resolve(); expect(await query).toBe("confirmed")
  expect(h.log.filter((entry) => entry === "post")).toHaveLength(0)
  expect(h.log.filter((entry) => entry === "confirm")).toHaveLength(1)
  expect(h.log.filter((entry) => entry === "notify")).toHaveLength(1)
})
