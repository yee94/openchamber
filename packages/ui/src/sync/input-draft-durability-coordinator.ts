import type { DraftBlobError, DraftBlobValue, InputDraftBlobStore } from "./input-draft-blob-store"
import { parseInputDraftMetadataSnapshot, type InputDraftMetadataErrorCode, type InputDraftMetadataPersistenceCoordinator, type InputDraftMetadataSnapshot } from "./input-draft-metadata-store"
import { draftAttachmentRefID, draftKeyString, parseDraftRecord, type DraftAttachmentMetadata, type DraftAttachmentReference, type DraftKey, type DraftRecord } from "./input-draft-types"

type DurableState = Pick<InputDraftMetadataSnapshot, "drafts" | "tombstones" | "migration" | "legacy">
type BlobError = DraftBlobError | { code: "runtime-value-missing" | "reference-conflict" | "invalid-record" }

export type InputDraftDurabilityError = { phase: "blob"; error: BlobError; reference?: DraftAttachmentReference } | { phase: "metadata"; error: { code: InputDraftMetadataErrorCode } }
export type InputDraftDurabilityResult = {
  status: "committed" | "stale" | "memory-only" | "failed" | "unseeded" | "disabled"
  keys: string[]
  errors: InputDraftDurabilityError[]
  cleanupErrors: InputDraftDurabilityError[]
}

export type InputDraftDurabilityCommit = {
  /** Complete proposed durable maps. They are merged into the coordinator's durable baseline. */
  drafts?: ReadonlyMap<string, DraftRecord> | Readonly<Record<string, DraftRecord>>
  tombstones?: ReadonlyMap<string, number> | Readonly<Record<string, number>>
  /** Keys removed by this transaction, including a move source. */
  delete?: readonly (DraftKey | string)[]
  migration?: InputDraftMetadataSnapshot["migration"]
  legacy?: InputDraftMetadataSnapshot["legacy"]
  /** Revalidates memory revisions, epochs, destination absence, and runtime ownership immediately before persistence. */
  isCurrent: () => boolean | Promise<boolean>
  /** Supplies an in-memory value only when a blob locator needs materialization. */
  resolveBlobValue?: (reference: DraftAttachmentReference, attachment: DraftAttachmentMetadata) => DraftBlobValue | undefined | Promise<DraftBlobValue | undefined>
}

export type InputDraftDurabilityCoordinator = {
  seed: (snapshot: InputDraftMetadataSnapshot | null | undefined) => Promise<InputDraftDurabilityResult>
  commit: (candidate: InputDraftDurabilityCommit) => Promise<InputDraftDurabilityResult>
  reconcile: (legacyOwners?: readonly { transportIdentity: string; owner: DraftKey["owner"] }[]) => Promise<InputDraftDurabilityResult>
  retryCleanup: () => Promise<InputDraftDurabilityResult>
  flush: () => Promise<void>
  setEnabled: (enabled: boolean) => Promise<void>
}

const emptyState = (): DurableState => ({ drafts: {}, tombstones: {}, migration: { complete: false, claimedTransportIdentity: "", captured: false, markerCommitted: false, cleanupComplete: false }, legacy: { entries: {} } })
const snapshotFor = (state: DurableState): InputDraftMetadataSnapshot => ({ version: 1, drafts: state.drafts, tombstones: state.tombstones, migration: state.migration, legacy: state.legacy })
const cloneState = (state: DurableState): DurableState => {
  const parsed = snapshotFor(state)
  const valid = JSON.parse(JSON.stringify(parsed)) as unknown
  const snapshot = parseSnapshot(valid)
  return { drafts: snapshot.drafts, tombstones: snapshot.tombstones, migration: snapshot.migration, legacy: snapshot.legacy }
}
const parseSnapshot = (value: unknown): InputDraftMetadataSnapshot => {
  const snapshot = parseInputDraftMetadataSnapshot(value)
  if (!snapshot) throw new Error("invalid draft snapshot")
  return snapshot
}
const entries = <T>(value: ReadonlyMap<string, T> | Readonly<Record<string, T>> | undefined): Array<[string, T]> => value instanceof Map ? [...value.entries()] : Object.entries(value ?? {})
const keyString = (key: DraftKey | string): string => typeof key === "string" ? key : draftKeyString(key)
const attachmentReferences = (record: DraftRecord): Array<{ reference: DraftAttachmentReference; attachment: DraftAttachmentMetadata }> => {
  const attachments = [...record.attachments, ...record.syntheticParts.flatMap((part) => part.attachments)]
  return attachments.flatMap((attachment) => attachment.locator.kind === "blob" ? [{ reference: { transportIdentity: record.key.transportIdentity, owner: record.key.owner, attachmentOccurrenceRefID: attachment.attachmentRefID }, attachment }] : [])
}
const refMap = (drafts: Record<string, DraftRecord>): Map<string, { reference: DraftAttachmentReference; attachment: DraftAttachmentMetadata }> => {
  const refs = new Map<string, { reference: DraftAttachmentReference; attachment: DraftAttachmentMetadata }>()
  for (const record of Object.values(drafts)) for (const item of attachmentReferences(record)) refs.set(draftAttachmentRefID(item.reference), item)
  return refs
}
const blobError = (error: BlobError, reference?: DraftAttachmentReference): InputDraftDurabilityError => ({ phase: "blob", error, ...(reference ? { reference } : {}) })
const emptyResult = (status: InputDraftDurabilityResult["status"], keys: string[] = []): InputDraftDurabilityResult => ({ status, keys, errors: [], cleanupErrors: [] })
const itemBlobID = (item: { attachment: DraftAttachmentMetadata } | undefined): string => item?.attachment.locator.kind === "blob" ? item.attachment.locator.blobID : ""

export const createInputDraftDurabilityCoordinator = (blobStore: InputDraftBlobStore, metadata: InputDraftMetadataPersistenceCoordinator, options: { enabled?: boolean } = {}): InputDraftDurabilityCoordinator => {
  let durable = emptyState()
  let enabled = options.enabled ?? true
  let enabledGeneration = 0
  let seeded = false
  let tail = Promise.resolve()
  const cleanup = new Map<string, { reference: DraftAttachmentReference; expectedBlobID: string; generation: number; reason: string }>()
  const run = <T>(work: () => Promise<T>): Promise<T> => {
    const next = tail.then(work, work)
    tail = next.then(() => undefined, () => undefined)
    return next
  }
  const cleanupPending = async (drafts = durable.drafts): Promise<InputDraftDurabilityError[]> => {
    const errors: InputDraftDurabilityError[] = []
    const desired = new Map([...refMap(drafts)].map(([id, item]) => [id, item.attachment.locator.kind === "blob" ? item.attachment.locator.blobID : ""]))
    for (const [id, entry] of cleanup) {
      if (desired.get(id) === entry.expectedBlobID) { cleanup.delete(id); continue }
      const result = await blobStore.releaseIfMatches(entry.reference, entry.expectedBlobID)
      if (result.ok) cleanup.delete(id)
      else errors.push(blobError(result.error, entry.reference))
    }
    return errors
  }
  const release = async (reference: DraftAttachmentReference, expectedBlobID: string, errors: InputDraftDurabilityError[], reason: string): Promise<void> => {
    const result = await blobStore.releaseIfMatches(reference, expectedBlobID)
    if (result.ok) return
    cleanup.set(draftAttachmentRefID(reference), { reference, expectedBlobID, generation: enabledGeneration, reason })
    errors.push(blobError(result.error, reference))
  }
  const ensure = async (item: { reference: DraftAttachmentReference; attachment: DraftAttachmentMetadata }, resolve: InputDraftDurabilityCommit["resolveBlobValue"]): Promise<{ acquired: boolean; error?: InputDraftDurabilityError }> => {
    const blobID = item.attachment.locator.kind === "blob" ? item.attachment.locator.blobID : ""
    const existing = await blobStore.readReference(item.reference)
    if (!existing.ok) return { acquired: false, error: blobError(existing.error, item.reference) }
    if (existing.value && existing.value !== blobID) return { acquired: false, error: blobError({ code: "reference-conflict" }, item.reference) }
    if (existing.value === blobID) {
      const present = await blobStore.read(blobID)
      if (present.ok) return { acquired: false }
      if (present.error.code !== "missing-blob") return { acquired: false, error: blobError(present.error, item.reference) }
      const value = await resolve?.(item.reference, item.attachment)
      if (value === undefined) return { acquired: false, error: blobError({ code: "runtime-value-missing" }, item.reference) }
      const repaired = await blobStore.putAndRetain(item.reference, blobID, value)
      return repaired.ok ? { acquired: true } : { acquired: false, error: blobError(repaired.error, item.reference) }
    }
    const present = await blobStore.read(blobID)
    if (present.ok) {
      const retained = await blobStore.retain(item.reference, blobID)
      return retained.ok ? { acquired: true } : { acquired: false, error: blobError(retained.error, item.reference) }
    }
    if (present.error.code !== "missing-blob") return { acquired: false, error: blobError(present.error, item.reference) }
    const value = await resolve?.(item.reference, item.attachment)
    if (value === undefined) return { acquired: false, error: blobError({ code: "runtime-value-missing" }, item.reference) }
    const put = await blobStore.putAndRetain(item.reference, blobID, value)
    return put.ok ? { acquired: true } : { acquired: false, error: blobError(put.error, item.reference) }
  }
  return {
    seed: (snapshot) => run(async () => {
      if (!enabled) return emptyResult("disabled")
      if (seeded) return { ...emptyResult("failed"), errors: [blobError({ code: "invalid-record" })] }
      let baseline: DurableState
      try {
        if (!snapshot) baseline = emptyState()
        else {
          const parsed = parseSnapshot(JSON.parse(JSON.stringify(snapshot)))
          baseline = { drafts: parsed.drafts, tombstones: parsed.tombstones, migration: parsed.migration, legacy: parsed.legacy }
        }
      } catch {
        return { ...emptyResult("failed"), errors: [blobError({ code: "invalid-record" })] }
      }
      const baselineRefs = refMap(baseline.drafts)
      const reconciled = await blobStore.reconcileReferences(new Map([...baselineRefs].map(([id, item]) => [id, itemBlobID(item)])), { ownerKinds: ["session", "draft"] })
      if (!reconciled.ok) return { ...emptyResult("failed"), errors: [blobError(reconciled.error)] }
      durable = baseline
      seeded = true
      return { ...emptyResult("committed"), errors: reconciled.value.missing.map((id) => blobError({ code: "missing-blob" }, baselineRefs.get(id)?.reference)) }
    }),
    commit: (candidate) => {
      const keys = [...entries(candidate.drafts).map(([key]) => key), ...(candidate.delete ?? []).map(keyString)]
      if (!enabled) return Promise.resolve(emptyResult("disabled", keys))
      return run(async () => {
        if (!seeded) return emptyResult("unseeded", keys)
        if (!enabled) return emptyResult("disabled", keys)
        const generation = enabledGeneration
        let cleanupErrors: InputDraftDurabilityError[] = []
        const next = cloneState(durable)
        try {
          for (const [key, record] of entries(candidate.drafts)) {
            const parsed = parseDraftRecord(record)
            if (!parsed || key !== draftKeyString(parsed.key)) throw new Error("invalid draft record")
            next.drafts[key] = parsed
            delete next.tombstones[key]
          }
        } catch {
          return { ...emptyResult("failed", keys), errors: [blobError({ code: "invalid-record" })], cleanupErrors }
        }
        for (const key of candidate.delete ?? []) delete next.drafts[keyString(key)]
        for (const [key, revision] of entries(candidate.tombstones)) next.tombstones[key] = revision
        if (candidate.migration) next.migration = candidate.migration
        if (candidate.legacy) next.legacy = candidate.legacy
        const oldRefs = refMap(durable.drafts)
        const nextRefs = refMap(next.drafts)
        cleanupErrors = await cleanupPending(next.drafts)
        const acquired: DraftAttachmentReference[] = []
        for (const [id, item] of nextRefs) {
          const old = oldRefs.get(id)
          const oldBlobID = old?.attachment.locator.kind === "blob" ? old.attachment.locator.blobID : undefined
          const nextBlobID = item.attachment.locator.kind === "blob" ? item.attachment.locator.blobID : undefined
          if (oldBlobID === nextBlobID) continue
          const ensured = await ensure(item, candidate.resolveBlobValue)
          if (ensured.error) {
            for (const reference of acquired.reverse()) await release(reference, itemBlobID(nextRefs.get(draftAttachmentRefID(reference))), cleanupErrors, "acquire-failed")
            return { ...emptyResult("failed", keys), errors: [ensured.error], cleanupErrors }
          }
          if (ensured.acquired) acquired.push(item.reference)
        }
        if (!await candidate.isCurrent()) {
          for (const reference of acquired.reverse()) await release(reference, itemBlobID(nextRefs.get(draftAttachmentRefID(reference))), cleanupErrors, "stale")
          return { ...emptyResult("stale", keys), cleanupErrors }
        }
        if (!enabled || generation !== enabledGeneration) {
          for (const reference of acquired.reverse()) await release(reference, itemBlobID(nextRefs.get(draftAttachmentRefID(reference))), cleanupErrors, "disabled")
          return { ...emptyResult("disabled", keys), cleanupErrors }
        }
        const persisted = await metadata.persist(snapshotFor(next))
        if (!persisted.ok) {
          for (const reference of acquired.reverse()) await release(reference, itemBlobID(nextRefs.get(draftAttachmentRefID(reference))), cleanupErrors, "metadata-failed")
          return { ...emptyResult("failed", keys), errors: [{ phase: "metadata", error: persisted.error }], cleanupErrors }
        }
        durable = next
        for (const [id, old] of oldRefs) if (!nextRefs.has(id)) await release(old.reference, old.attachment.locator.kind === "blob" ? old.attachment.locator.blobID : "", cleanupErrors, "metadata-committed")
        return { ...emptyResult("committed", keys), cleanupErrors }
      })
    },
    reconcile: () => run(async () => {
      if (!seeded) return emptyResult("unseeded")
      if (!enabled) return emptyResult("disabled")
      const cleanupErrors = await cleanupPending()
      const desired = new Map([...refMap(durable.drafts)].map(([id, item]) => [id, item.attachment.locator.kind === "blob" ? item.attachment.locator.blobID : ""]))
      const result = await blobStore.reconcileReferences(desired, { ownerKinds: ["session", "draft"] })
      const errors = result.ok ? result.value.missing.map((id) => blobError({ code: "missing-blob" }, refMap(durable.drafts).get(id)?.reference)) : [blobError(result.error)]
      return { status: result.ok ? "committed" : "failed", keys: [], errors, cleanupErrors }
    }),
    retryCleanup: () => run(async () => ({ ...emptyResult("committed"), cleanupErrors: await cleanupPending() })),
    flush: () => tail,
    setEnabled: async (nextEnabled) => {
      if (!nextEnabled) { enabled = false; enabledGeneration += 1; metadata.cancelPending?.(); await metadata.setEnabled?.(false); await tail; await metadata.flush?.(); return }
      await metadata.setEnabled?.(true); enabled = true; enabledGeneration += 1
    },
  }
}
