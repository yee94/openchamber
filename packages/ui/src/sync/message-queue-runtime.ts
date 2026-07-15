import { createDefaultQueueLedgerSink, createQueueLedgerRepository, type QueueLedgerDetailedRead, type QueueLedgerSnapshotV4 } from "@/stores/message-queue-ledger"
import { migrateLegacyMessageQueue } from "@/stores/message-queue-migration"
import { getRuntimeGeneration, getRuntimeTransportIdentity } from "@/lib/runtime-switch"
import { createInputDraftBlobStore } from "./input-draft-blob-store"
import { createMessageQueueRuntimeController, type MessageQueueRuntimeController, type MessageQueueRuntimeResult } from "./message-queue-runtime-controller"
import { createQueueAttachmentCoordinator, type QueueRuntime } from "./queue-attachment-coordinator"

export type MessageQueueRuntime = MessageQueueRuntimeController
export type MessageQueueRuntimeFactory = () => { controller: MessageQueueRuntimeController; migrate: () => Promise<{ status: "committed" | "degraded" | "recovery-required" | "failed"; snapshot?: QueueLedgerSnapshotV4; issues?: Array<{ path: string; reason: string; scopeKey?: string }> }> }

const defaultFactory: MessageQueueRuntimeFactory = () => {
  const sink = createDefaultQueueLedgerSink()
  const repository = createQueueLedgerRepository(sink)
  const blobs = createInputDraftBlobStore()
  const runtime = (): QueueRuntime => {
    const transportIdentity = getRuntimeTransportIdentity(), generation = getRuntimeGeneration()
    return { transportIdentity, generation, isCurrent: () => getRuntimeTransportIdentity() === transportIdentity && getRuntimeGeneration() === generation }
  }
  return { controller: createMessageQueueRuntimeController(createQueueAttachmentCoordinator(blobs, repository), runtime), migrate: async () => migrateLegacyMessageQueue(sink, blobs) }
}

export const createMessageQueueRuntime = (factory: MessageQueueRuntimeFactory = defaultFactory): MessageQueueRuntime => {
  let instance: ReturnType<MessageQueueRuntimeFactory> | undefined
  let hydration: Promise<MessageQueueRuntimeResult> | undefined
  const controller = (): ReturnType<MessageQueueRuntimeFactory>["controller"] => (instance ??= factory()).controller
  return {
    subscribe: (listener) => controller().subscribe(listener),
    getState: () => controller().getState(),
    captureRuntime: () => controller().captureRuntime(),
    hydrate: (source?: QueueLedgerSnapshotV4 | QueueLedgerDetailedRead | null): Promise<MessageQueueRuntimeResult> => hydration ??= (async () => {
      const created = instance ??= factory()
      if (source !== undefined) return created.controller.hydrate(source)
      const migrated = await created.migrate()
      if (migrated.status === "committed") return created.controller.hydrate(migrated.snapshot!)
      if (migrated.status === "degraded") return created.controller.hydrate({ raw: null, snapshot: migrated.snapshot!, status: "partial", issues: migrated.issues ?? [{ path: "$.migration", reason: "degraded" }], degradedScopeKeys: [] })
      return created.controller.hydrate({ raw: null, snapshot: null, status: "corrupt", issues: migrated.issues ?? [{ path: "$", reason: migrated.status }], degradedScopeKeys: [] })
    })().finally(() => { hydration = undefined }),
    flush: () => controller().flush(),
    setEnabled: (enabled) => controller().setEnabled(enabled),
    admit: (item, resolve, capture) => controller().admit(item, resolve, capture),
    materializeForEdit: (identity, capture) => controller().materializeForEdit(identity, capture),
    releaseEditReservation: (identity, token, capture) => controller().releaseEditReservation(identity, token, capture),
    removeEditReservation: (identity, token, capture) => controller().removeEditReservation(identity, token, capture),
    remove: (identity, capture) => controller().remove(identity, capture),
    reorder: (scopeKey, ids, capture) => controller().reorder(scopeKey, ids, capture),
    bind: (identity, owner, capture) => controller().bind(identity, owner, capture),
    bindMany: (identities, owner, capture) => controller().bindMany(identities, owner, capture),
    transition: (identity, expected, update, capture) => controller().transition(identity, expected, update, capture),
    confirm: (identity, capture) => controller().confirm(identity, capture),
    acquireSendPayload: (identity, capture) => controller().acquireSendPayload(identity, capture),
    releaseSend: (identity, token, capture) => controller().releaseSend(identity, token, capture),
  }
}

let defaultRuntime: MessageQueueRuntime | undefined
export const getMessageQueueRuntime = (): MessageQueueRuntime => defaultRuntime ??= createMessageQueueRuntime()
