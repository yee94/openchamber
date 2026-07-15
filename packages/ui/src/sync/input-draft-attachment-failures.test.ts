import { describe, expect, test } from "bun:test"
import { createInputDraftBlobStore, MemoryInputDraftBlobDriver, type InputDraftBlobStore } from "./input-draft-blob-store"
import { createInputDraftMetadataStorageSink, type InputDraftMetadataSink } from "./input-draft-metadata-store"
import { draftKeyString, type DraftAttachmentReference, type DraftKey } from "./input-draft-types"
import { createInputStore } from "./input-store"

class TestFileReader {
  result: string | ArrayBuffer | null = null
  onload: ((event: ProgressEvent<FileReader>) => unknown) | null = null
  onerror: ((event: ProgressEvent<FileReader>) => unknown) | null = null
  onabort: ((event: ProgressEvent<FileReader>) => unknown) | null = null
  readAsDataURL() { this.result = "data:text/plain;base64,eA=="; queueMicrotask(() => this.onload?.({} as ProgressEvent<FileReader>)) }
}

globalThis.FileReader = TestFileReader as unknown as typeof FileReader

class MemoryStorage {
  values = new Map<string, string>()
  get length() { return this.values.size }
  key(index: number) { return [...this.values.keys()][index] ?? null }
  getItem(key: string) { return this.values.get(key) ?? null }
  setItem(key: string, value: string) { this.values.set(key, value) }
  removeItem(key: string) { this.values.delete(key) }
}

const key = (): DraftKey => ({ transportIdentity: "runtime", owner: { kind: "session", ownerID: "session" } })
const reference = (attachmentRefID: string): DraftAttachmentReference => ({ transportIdentity: "runtime", owner: key().owner, attachmentOccurrenceRefID: attachmentRefID })

const failingSink = (storage: MemoryStorage) => {
  const base = createInputDraftMetadataStorageSink(storage as unknown as Storage)
  let failures = 0
  const sink: InputDraftMetadataSink = {
    ...base,
    write: async (name, value) => {
      if (failures > 0) {
        failures -= 1
        return { ok: false, error: { code: "quota" } }
      }
      return base.write(name, value)
    },
  }
  return { sink, failNext: () => { failures += 1 } }
}

const createFixture = async (options: { blobStore?: InputDraftBlobStore } = {}) => {
  const storage = new MemoryStorage()
  const driver = new MemoryInputDraftBlobDriver()
  const blobs = options.blobStore ?? createInputDraftBlobStore(driver)
  const metadata = failingSink(storage)
  let id = 0
  const store = createInputStore({ sink: metadata.sink, blobStore: blobs, createID: () => `id-${++id}`, runtimeCapture: () => ({ transportIdentity: "runtime", generation: 1 }) })
  await store.getState().hydrateDraftMetadata("runtime")
  await store.getState().flushDraftPersistence()
  return { store, storage, driver, blobs, metadata }
}

describe("input draft attachment durability failures", () => {
  test("keeps an added attachment editable, rolls back its candidate reference, and saves on retry after metadata quota", async () => {
    const { store, blobs, metadata } = await createFixture()
    metadata.failNext()
    const attached = await store.getState().addDraftLocalAttachment(key(), new File(["one"], "one.txt", { type: "text/plain" }))
    await store.getState().flushDraftPersistence()
    if (!attached || attached.locator.kind !== "blob") throw new Error("attachment was not created")
    const id = draftKeyString(key())
    expect(store.getState().getDraftAttachmentViews(key())).toHaveLength(1)
    expect(store.getState().draftAttachmentPersistence[id]?.status).toBe("error")
    expect(store.getState().draftAttachmentPersistence[id]?.errorCode).toBe("quota")
    expect(await blobs.readReference(reference(attached.attachmentRefID))).toEqual({ ok: true, value: undefined })
    await store.getState().retryDraftAttachmentPersistence(key())
    await store.getState().flushDraftPersistence()
    expect(store.getState().draftAttachmentPersistence[id]?.status).toBe("saved")
    expect(await blobs.readReference(reference(attached.attachmentRefID))).toEqual({ ok: true, value: attached.locator.blobID })
  })

  test("retains the old durable reference through remove metadata failure and releases it after retry", async () => {
    const { store, blobs, metadata } = await createFixture()
    const attached = await store.getState().addDraftLocalAttachment(key(), new File(["one"], "one.txt"))
    await store.getState().flushDraftPersistence()
    if (!attached || attached.locator.kind !== "blob") throw new Error("attachment was not created")
    metadata.failNext()
    expect(await store.getState().removeDraftAttachment(key(), attached.attachmentRefID)).toBe(false)
    expect(await blobs.readReference(reference(attached.attachmentRefID))).toEqual({ ok: true, value: attached.locator.blobID })
    await store.getState().retryDraftAttachmentPersistence(key())
    await store.getState().flushDraftPersistence()
    expect(await blobs.readReference(reference(attached.attachmentRefID))).toEqual({ ok: true, value: undefined })
  })

  test("surfaces source release cleanup failure and releases it through the public retry", async () => {
    const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver())
    let failRelease = false
    const blobs: InputDraftBlobStore = { ...base, releaseIfMatches: async (ref, blobID) => failRelease ? { ok: false, error: { code: "transaction-failed" } } : base.releaseIfMatches(ref, blobID) }
    const { store } = await createFixture({ blobStore: blobs })
    const attached = await store.getState().addDraftLocalAttachment(key(), new File(["one"], "one.txt"))
    await store.getState().flushDraftPersistence()
    if (!attached || attached.locator.kind !== "blob") throw new Error("attachment was not created")
    failRelease = true
    expect(await store.getState().removeDraftAttachment(key(), attached.attachmentRefID)).toBe(true)
    await store.getState().flushDraftPersistence()
    const id = draftKeyString(key())
    expect(store.getState().draftAttachmentPersistence[id]?.status).toBe("error")
    expect(store.getState().draftAttachmentPersistence[id]?.errorCode).toBe("transaction-failed")
    expect(await base.readReference(reference(attached.attachmentRefID))).toEqual({ ok: true, value: attached.locator.blobID })
    failRelease = false
    await store.getState().retryDraftAttachmentPersistence(key())
    await store.getState().flushDraftPersistence()
    expect(store.getState().draftAttachmentPersistence[id]?.status).toBe("saved")
    expect(await base.readReference(reference(attached.attachmentRefID))).toEqual({ ok: true, value: undefined })
  })

  test("retains delete tombstone and old reference through metadata failure, then prevents resurrection after retry", async () => {
    const { store, storage, driver, blobs, metadata } = await createFixture()
    const attached = await store.getState().addDraftLocalAttachment(key(), new File(["one"], "one.txt"))
    await store.getState().flushDraftPersistence()
    if (!attached || attached.locator.kind !== "blob") throw new Error("attachment was not created")
    metadata.failNext()
    expect(store.getState().deleteDraft(key())).toBe(true)
    await store.getState().flushDraftPersistence()
    const id = draftKeyString(key())
    expect(store.getState().drafts[id]).toBe(undefined)
    expect(store.getState().tombstones[id]).toBeGreaterThan(0)
    expect(await blobs.readReference(reference(attached.attachmentRefID))).toEqual({ ok: true, value: attached.locator.blobID })
    await store.getState().retryDraftAttachmentPersistence(key())
    await store.getState().flushDraftPersistence()
    const restored = createInputStore({ sink: createInputDraftMetadataStorageSink(storage as unknown as Storage), blobStore: createInputDraftBlobStore(driver), runtimeCapture: () => ({ transportIdentity: "runtime", generation: 1 }) })
    await restored.getState().hydrateDraftMetadata("runtime")
    await restored.getState().flushDraftPersistence()
    expect(restored.getState().getDraft(key())).toBe(undefined)
    expect((await createInputDraftBlobStore(driver).read(attached.locator.blobID)).ok).toBe(false)
  })

  test("keeps the memory replacement while metadata failure preserves old durable state and rolls back the candidate", async () => {
    const { store, blobs, metadata } = await createFixture()
    const first = await store.getState().addDraftLocalAttachment(key(), new File(["one"], "one.txt"))
    await store.getState().flushDraftPersistence()
    if (!first || first.locator.kind !== "blob") throw new Error("attachment was not created")
    const revision = store.getState().getDraft(key())!.revision
    metadata.failNext()
    const replacement = await store.getState().replaceDraftAttachment(key(), first.attachmentRefID, new File(["two"], "two.txt"))
    await store.getState().flushDraftPersistence()
    const current = store.getState().getDraft(key())!
    const next = current.attachments[0]
    if (!next || next.locator.kind !== "blob") throw new Error("replacement was not retained in memory")
    expect(replacement).toBe(undefined)
    expect(current.revision).toBe(revision + 1)
    expect(next.filename).toBe("two.txt")
    expect(await blobs.readReference(reference(first.attachmentRefID))).toEqual({ ok: true, value: first.locator.blobID })
    expect(await blobs.readReference(reference(next.attachmentRefID))).toEqual({ ok: true, value: undefined })
    await store.getState().retryDraftAttachmentPersistence(key())
    await store.getState().flushDraftPersistence()
    expect(await blobs.readReference(reference(next.attachmentRefID))).toEqual({ ok: true, value: next.locator.blobID })
    expect(await blobs.readReference(reference(first.attachmentRefID))).toEqual({ ok: true, value: undefined })
  })

  test("classifies blob quota and database failures as attachment errors while preserving editable memory", async () => {
    const quotaBase = createInputDraftBlobStore(new MemoryInputDraftBlobDriver())
    let quotaFailure = false
    const quota: InputDraftBlobStore = { ...quotaBase, readReference: async (ref) => quotaFailure ? { ok: false, error: { code: "quota-exceeded" } } : quotaBase.readReference(ref) }
    const databaseBase = createInputDraftBlobStore(new MemoryInputDraftBlobDriver())
    const database: InputDraftBlobStore = { ...databaseBase, readReference: async () => ({ ok: false, error: { code: "database-unavailable" } }) }
    for (const [blobs, errorCode, activate] of [[quota, "quota-exceeded", () => { quotaFailure = true }], [database, "database-unavailable", () => {}]] as const) {
      const { store } = await createFixture({ blobStore: blobs })
      activate()
      const attached = await store.getState().addDraftLocalAttachment(key(), new File([errorCode], `${errorCode}.txt`))
      await store.getState().flushDraftPersistence()
      const id = draftKeyString(key())
      expect(attached).toBeDefined()
      expect(store.getState().getDraftAttachmentViews(key())).toHaveLength(1)
      expect(store.getState().draftAttachmentPersistence[id]?.status).toBe("error")
      expect(store.getState().draftAttachmentPersistence[id]?.errorCode).toBe(errorCode)
      expect(store.getState().setDraftText(key(), "still editable").text).toBe("still editable")
    }
  })
})
