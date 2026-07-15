import { describe, expect, test } from "bun:test"
import { createInputDraftMetadataRepository, createInputDraftMetadataStorageSink, type InputDraftMetadataPersistenceCoordinator } from "./input-draft-metadata-store"
import { draftKeyString, type DraftKey } from "./input-draft-types"
import { createInputDraftBlobStore, MemoryInputDraftBlobDriver, type InputDraftBlobDriver, type InputDraftBlobTransaction } from "./input-draft-blob-store"
import { createInputStore } from "./input-store"

class MemoryStorage {
  values = new Map<string, string>()
  quota = false
  get length() { return this.values.size }
  key(index: number) { return [...this.values.keys()][index] ?? null }
  getItem(key: string) { return this.values.get(key) ?? null }
  setItem(key: string, value: string) { if (this.quota) throw new DOMException("quota", "QuotaExceededError"); this.values.set(key, value) }
  removeItem(key: string) { this.values.delete(key) }
}

const key = (transportIdentity: string, ownerID = "session"): DraftKey => ({ transportIdentity, owner: { kind: "session", ownerID } })
const tick = () => new Promise((resolve) => setTimeout(resolve, 0))
const blobStore = () => createInputDraftBlobStore(new MemoryInputDraftBlobDriver())
const deferred = <T,>() => {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((next) => { resolve = next })
  return { promise, resolve }
}

describe("keyed input draft state", () => {
  test("isolates runtimes and applies monotonic CAS, mentions, and synthetic consumption", () => {
    const store = createInputStore({ persistenceEnabled: false })
    const first = key("one")
    const second = key("two")
    expect(store.getState().setDraftText(first, "@src/a.ts").revision).toBe(2)
    expect(store.getState().setDraftText(second, "other").revision).toBe(2)
    expect(store.getState().replaceDraft(first, 1, { text: "stale", attachments: [], syntheticParts: [], mentions: [] })).toBe(undefined)
    const mention = { kind: "file" as const, value: "src/a.ts", path: "src/a.ts", label: "src/a.ts", range: { start: 0, end: 9 } }
    expect(store.getState().addDraftMention(first, mention)?.revision).toBe(3)
    store.getState().setDraftSyntheticParts(first, [{ partID: "p", text: "context", attachments: [] }])
    expect(store.getState().consumeDraftSyntheticParts(first)).toEqual([{ partID: "p", text: "context", attachments: [] }])
    expect(store.getState().getDraft(second)?.text).toBe("other")
    store.getState().setPendingInputText("legacy", "append")
    expect(store.getState().consumePendingInputText()).toEqual({ text: "legacy", mode: "append" })
    expect(store.getState().draftPersistence).toEqual({})
  })

  test("preserves memory edits across slow hydration and keeps metadata for moves", async () => {
    const storage = new MemoryStorage()
    const sink = createInputDraftMetadataStorageSink(storage as unknown as Storage)
    const draft = { version: 1 as const, key: key("runtime"), revision: 1, text: "disk", attachments: [], syntheticParts: [], mentions: [] }
    storage.values.set("openchamber_input_draft_metadata_v1", JSON.stringify({ version: 1, drafts: { [draftKeyString(draft.key)]: draft }, tombstones: {}, migration: { complete: true, claimedTransportIdentity: "runtime", captured: true, markerCommitted: true, cleanupComplete: true }, legacy: { entries: {} } }))
    let release: (() => void) | undefined
    const originalRead = sink.read
    sink.read = async (name) => {
      if (name === "openchamber_input_draft_metadata_v1" && !release) await new Promise<void>((resolve) => { release = resolve })
      return originalRead(name)
    }
    const store = createInputStore({ sink })
    const loading = store.getState().hydrateDraftMetadata("runtime")
    await tick()
    store.getState().setDraftText(key("runtime"), "memory")
    release?.()
    await loading
    expect(store.getState().getDraft(key("runtime"))?.text).toBe("memory")
    const attachment = { attachmentID: "a", attachmentRefID: '["root","a"]', filename: "a", mimeType: "text/plain", size: 1, locator: { kind: "url" as const, url: "file:///a" }, source: "local" as const }
    store.getState().setDraftAttachments(key("runtime"), [attachment])
    const moved = store.getState().moveDraft(key("runtime"), key("runtime", "destination"))
    expect(moved?.attachments).toEqual([attachment])
    expect(store.getState().tombstones[draftKeyString(key("runtime"))]).toBe(moved?.revision)
  })

  test("retains editable memory on quota and ignores older persistence completion", async () => {
    const pending: Array<(value: { ok: true; value: undefined }) => void> = []
    const coordinator: InputDraftMetadataPersistenceCoordinator = { persist: async () => new Promise((resolve) => pending.push(resolve)) }
    const store = createInputStore({ coordinator, sink: createInputDraftMetadataStorageSink(new MemoryStorage() as unknown as Storage), blobStore: blobStore(), runtimeCapture: () => ({ transportIdentity: "runtime", generation: 1 }) })
    const hydrated = store.getState().hydrateDraftMetadata("runtime")
    await tick()
    pending.shift()?.({ ok: true, value: undefined })
    await hydrated
    store.getState().setDraftText(key("runtime"), "one")
    store.getState().setDraftText(key("runtime"), "two")
    await tick()
    pending[0]({ ok: true, value: undefined })
    await tick()
    expect(store.getState().draftPersistence[draftKeyString(key("runtime"))]?.status).toBe("saved")
    for (const resolve of pending.slice(1)) resolve({ ok: true, value: undefined })
    await tick()
    expect(store.getState().draftPersistence[draftKeyString(key("runtime"))]?.status).toBe("saved")

    const storage = new MemoryStorage()
    const quotaStore = createInputStore({ sink: createInputDraftMetadataStorageSink(storage as unknown as Storage), blobStore: blobStore(), runtimeCapture: () => ({ transportIdentity: "quota", generation: 1 }) })
    await quotaStore.getState().hydrateDraftMetadata("quota")
    storage.quota = true
    quotaStore.getState().setDraftText(key("quota"), "editable")
    await tick()
    expect(quotaStore.getState().getDraft(key("quota"))?.text).toBe("editable")
    expect(quotaStore.getState().draftPersistence[draftKeyString(key("quota"))]?.errorCode).toBe("quota")
  })

  test("imports legacy sessions once, stages new until claimed, and honors destination and tombstones", async () => {
    const storage = new MemoryStorage()
    storage.values.set("openchamber_chat_input_draft_session", "@src/a.ts hello")
    storage.values.set("openchamber_chat_confirmed_mentions_session", JSON.stringify(["src/a.ts"]))
    storage.values.set("openchamber_chat_input_draft_new", "new")
    storage.values.set("openchamber_chat_confirmed_mentions_new", "{")
    const store = createInputStore({ sink: createInputDraftMetadataStorageSink(storage as unknown as Storage), blobStore: blobStore(), runtimeCapture: () => ({ transportIdentity: "runtime", generation: 1 }) })
    await store.getState().hydrateDraftMetadata("runtime")
    const imported = store.getState().getDraft(key("runtime"))
    expect(imported?.mentions[0]).toEqual({ kind: "file", value: "src/a.ts", path: "src/a.ts", label: "src/a.ts", range: { start: 0, end: 9 } })
    expect(store.getState().legacyNewDraft?.text).toBe("new")
    expect((await store.getState().claimLegacyNewDraft(key("runtime", "new-draft")))?.text).toBe("new")
    expect((await store.getState().claimLegacyNewDraft(key("runtime", "new-draft")))?.text).toBe("new")
    expect(store.getState().deleteDraft(key("runtime"), imported?.revision)).toBe(true)
    await store.getState().hydrateDraftMetadata("runtime")
    expect(store.getState().getDraft(key("runtime"))).toBe(undefined)
  })

  test("stores parser clones, clears stale mentions, and rejects blob-backed moves", () => {
    const store = createInputStore({ persistenceEnabled: false })
    const draftKey = key("runtime")
    const mention = { kind: "file" as const, value: "src/a.ts", path: "src/a.ts", label: "src/a.ts", range: { start: 0, end: 9 } }
    const attachment = { attachmentID: "a", attachmentRefID: '["root","a"]', filename: "a", mimeType: "text/plain", size: 1, locator: { kind: "url" as const, url: "file:///a" }, source: "local" as const }
    store.getState().ensureDraft(draftKey)
    store.getState().replaceDraft(draftKey, 1, { text: "@src/a.ts", attachments: [attachment], syntheticParts: [], mentions: [mention] })
    attachment.locator.url = "file:///mutated"
    mention.range.start = 1
    expect(store.getState().getDraft(draftKey)?.attachments[0]?.locator).toEqual({ kind: "url", url: "file:///a" })
    expect(store.getState().getDraft(draftKey)?.mentions[0]?.range.start).toBe(0)
    store.getState().setDraftText(draftKey, "plain")
    expect(store.getState().getDraft(draftKey)?.mentions).toEqual([])
    const blob = { ...attachment, attachmentID: "blob", attachmentRefID: '["root","blob"]', locator: { kind: "blob" as const, blobID: "blob" } }
    store.getState().setDraftAttachments(draftKey, [blob])
    expect(store.getState().moveDraft(draftKey, key("runtime", "destination"))).toBe(undefined)
  })

  test("keeps local revision 2 edit ahead of a slow disk revision 100 hydrate", async () => {
    const storage = new MemoryStorage()
    const disk = { version: 1 as const, key: key("runtime"), revision: 100, text: "disk", attachments: [], syntheticParts: [], mentions: [] }
    storage.values.set("openchamber_input_draft_metadata_v1", JSON.stringify({ version: 1, drafts: { [draftKeyString(disk.key)]: disk }, tombstones: {}, migration: { complete: true, claimedTransportIdentity: "runtime", captured: true, markerCommitted: true, cleanupComplete: true }, legacy: { entries: {} } }))
    const sink = createInputDraftMetadataStorageSink(storage as unknown as Storage)
    const gate = deferred<void>()
    const read = sink.read
    sink.read = async (name) => { if (name === "openchamber_input_draft_metadata_v1") await gate.promise; return read(name) }
    const store = createInputStore({ sink, runtimeCapture: () => ({ transportIdentity: "runtime", generation: 1 }) })
    const loading = store.getState().hydrateDraftMetadata("runtime")
    await tick()
    store.getState().setDraftText(key("runtime"), "local")
    gate.resolve()
    await loading
    expect(store.getState().getDraft(key("runtime"))?.text).toBe("local")
    expect(store.getState().getDraft(key("runtime"))?.revision).toBe(2)
  })

  test("keeps a local delete ahead of a slow disk revision 100 hydrate", async () => {
    const storage = new MemoryStorage()
    const disk = { version: 1 as const, key: key("runtime"), revision: 100, text: "disk", attachments: [], syntheticParts: [], mentions: [] }
    storage.values.set("openchamber_input_draft_metadata_v1", JSON.stringify({ version: 1, drafts: { [draftKeyString(disk.key)]: disk }, tombstones: {}, migration: { complete: true, claimedTransportIdentity: "runtime", captured: true, markerCommitted: true, cleanupComplete: true }, legacy: { entries: {} } }))
    const sink = createInputDraftMetadataStorageSink(storage as unknown as Storage)
    const gate = deferred<void>()
    const read = sink.read
    sink.read = async (name) => { if (name === "openchamber_input_draft_metadata_v1") await gate.promise; return read(name) }
    const store = createInputStore({ sink, runtimeCapture: () => ({ transportIdentity: "runtime", generation: 1 }) })
    store.getState().setDraftText(key("runtime"), "local")
    const loading = store.getState().hydrateDraftMetadata("runtime")
    await tick()
    store.getState().deleteDraft(key("runtime"))
    gate.resolve()
    await loading
    expect(store.getState().getDraft(key("runtime"))).toBe(undefined)
    expect(store.getState().tombstones[draftKeyString(key("runtime"))]).toBe(3)
  })

  test("hydrates disabled persistence into memory, then seeds and persists after enabling", async () => {
    const storage = new MemoryStorage()
    const id = draftKeyString(key("runtime"))
    const durableKey = key("runtime", "durable")
    const durableID = draftKeyString(durableKey)
    const durableDraft = { version: 1 as const, key: durableKey, revision: 2, text: "durable", attachments: [], syntheticParts: [], mentions: [] }
    storage.values.set("openchamber_input_draft_metadata_v1", JSON.stringify({ version: 1, drafts: { [durableID]: durableDraft }, tombstones: { [id]: 100 }, migration: { complete: true, claimedTransportIdentity: "runtime", captured: true, markerCommitted: true, cleanupComplete: true }, legacy: { entries: {} } }))
    const base = new MemoryInputDraftBlobDriver()
    let transactions = 0
    const driver: InputDraftBlobDriver = { transaction: async <T>(action: (transaction: InputDraftBlobTransaction) => Promise<T>): Promise<T> => { transactions += 1; return base.transaction(action) } }
    const store = createInputStore({ sink: createInputDraftMetadataStorageSink(storage as unknown as Storage), blobStore: createInputDraftBlobStore(driver), persistenceEnabled: false, runtimeCapture: () => ({ transportIdentity: "runtime", generation: 1 }) })
    store.getState().ensureDraft(key("runtime"))
    await store.getState().hydrateDraftMetadata("runtime")
    expect(transactions).toBe(0)
    expect(store.getState().getDraft(key("runtime"))).toBe(undefined)
    expect(store.getState().tombstones[id]).toBe(100)
    expect(store.getState().getDraft(durableKey)?.text).toBe("durable")
    store.getState().setDraftText(durableKey, "memory")
    await store.getState().setDraftPersistenceEnabled(true)
    expect(transactions).toBeGreaterThan(0)
    const persisted = JSON.parse(storage.values.get("openchamber_input_draft_metadata_v1") ?? "{}")
    expect(persisted.drafts[durableID]?.text).toBe("memory")
    expect(persisted.tombstones[id]).toBe(100)
  })

  test("skips hydrate ownership and writeback for a non-active transport", async () => {
    const storage = new MemoryStorage()
    storage.values.set("openchamber_chat_input_draft_session", "legacy")
    const store = createInputStore({ sink: createInputDraftMetadataStorageSink(storage as unknown as Storage), blobStore: blobStore(), runtimeCapture: () => ({ transportIdentity: "active", generation: 1 }) })
    await store.getState().hydrateDraftMetadata("stale")
    expect(storage.values.has("openchamber_input_draft_metadata_v1")).toBe(false)
    expect(storage.values.has("openchamber_input_draft_metadata_migration_v1")).toBe(false)
  })

  test("claims legacy data once across transports and ignores an older same-transport completion", async () => {
    const storage = new MemoryStorage()
    storage.values.set("openchamber_chat_input_draft_session", "legacy")
    let capture = { transportIdentity: "one", generation: 1 }
    const store = createInputStore({ sink: createInputDraftMetadataStorageSink(storage as unknown as Storage), blobStore: blobStore(), runtimeCapture: () => capture })
    const first = store.getState().hydrateDraftMetadata("one")
    capture = { transportIdentity: "two", generation: 2 }
    await store.getState().hydrateDraftMetadata("two")
    await first
    expect(store.getState().migration.claimedTransportIdentity).toBe("one")
    expect(store.getState().getDraft(key("two"))).toBe(undefined)
  })

  test("does not revive staged legacy new after hydrate-time claim", async () => {
    const storage = new MemoryStorage()
    storage.values.set("openchamber_chat_input_draft_new", "legacy new")
    const store = createInputStore({ sink: createInputDraftMetadataStorageSink(storage as unknown as Storage), blobStore: blobStore(), runtimeCapture: () => ({ transportIdentity: "runtime", generation: 1 }) })
    await store.getState().hydrateDraftMetadata("runtime")
    await store.getState().claimLegacyNewDraft(key("runtime", "claimed"))
    await store.getState().hydrateDraftMetadata("runtime")
    expect(store.getState().legacyNewDraft).toBe(undefined)
    expect(store.getState().getDraft(key("runtime", "claimed"))?.text).toBe("legacy new")
  })

  test("runtime generation changes suppress persist completion writeback", async () => {
    const pending = deferred<{ ok: true; value: undefined }>()
    let capture = { transportIdentity: "runtime", generation: 1 }
    const coordinator: InputDraftMetadataPersistenceCoordinator = { persist: async () => pending.promise }
    const store = createInputStore({ coordinator, sink: createInputDraftMetadataStorageSink(new MemoryStorage() as unknown as Storage), blobStore: blobStore(), runtimeCapture: () => capture })
    store.getState().setDraftText(key("runtime"), "draft")
    capture = { transportIdentity: "runtime", generation: 2 }
    pending.resolve({ ok: true, value: undefined })
    await tick()
    expect(store.getState().draftPersistence[draftKeyString(key("runtime"))]?.status).toBe("saving")
  })

  test("limits slow persist status completion to its touched key", async () => {
    const pending: Array<ReturnType<typeof deferred<{ ok: true; value: undefined }>>> = []
    const coordinator: InputDraftMetadataPersistenceCoordinator = { persist: async () => { const next = deferred<{ ok: true; value: undefined }>(); pending.push(next); return next.promise } }
    const store = createInputStore({ coordinator, sink: createInputDraftMetadataStorageSink(new MemoryStorage() as unknown as Storage), blobStore: blobStore(), runtimeCapture: () => ({ transportIdentity: "runtime", generation: 1 }) })
    const hydrated = store.getState().hydrateDraftMetadata("runtime")
    await tick()
    pending.shift()!.resolve({ ok: true, value: undefined })
    await hydrated
    store.getState().ensureDraft(key("runtime", "A"))
    store.getState().ensureDraft(key("runtime", "B"))
    await tick()
    pending[0]!.resolve({ ok: true, value: undefined })
    await tick(); await tick()
    expect(store.getState().draftPersistence[draftKeyString(key("runtime", "A"))]?.status).toBe("saved")
    pending[1]!.resolve({ ok: true, value: undefined })
    await tick(); await tick(); await tick()
    expect(store.getState().draftPersistence[draftKeyString(key("runtime", "B"))]?.status).toBe("saved")
  })

  test("limits failed persist status completion to its touched key", async () => {
    const pending: Array<ReturnType<typeof deferred<{ ok: true; value: undefined } | { ok: false; error: { code: "quota" } }>>> = []
    const coordinator: InputDraftMetadataPersistenceCoordinator = { persist: async () => { const next = deferred<{ ok: true; value: undefined } | { ok: false; error: { code: "quota" } }>(); pending.push(next); return next.promise } }
    const store = createInputStore({ coordinator, sink: createInputDraftMetadataStorageSink(new MemoryStorage() as unknown as Storage), blobStore: blobStore(), runtimeCapture: () => ({ transportIdentity: "runtime", generation: 1 }) })
    const hydrated = store.getState().hydrateDraftMetadata("runtime")
    await tick()
    pending.shift()!.resolve({ ok: true, value: undefined })
    await hydrated
    store.getState().ensureDraft(key("runtime", "A"))
    store.getState().ensureDraft(key("runtime", "B"))
    await tick()
    pending[0]!.resolve({ ok: false, error: { code: "quota" } })
    await tick(); await tick()
    expect(store.getState().draftPersistence[draftKeyString(key("runtime", "A"))]?.status).toBe("error")
    pending[1]!.resolve({ ok: false, error: { code: "quota" } })
    await tick(); await tick(); await tick()
    expect(store.getState().draftPersistence[draftKeyString(key("runtime", "B"))]?.status).toBe("error")
  })

  test("disable waits for entered work and blocks stale completion state and later writes", async () => {
    const storage = new MemoryStorage()
    const sink = createInputDraftMetadataStorageSink(storage as unknown as Storage)
    const repository = createInputDraftMetadataRepository(sink)
    const pending = deferred<{ ok: true; value: undefined }>()
    const coordinator: InputDraftMetadataPersistenceCoordinator = { persist: async () => pending.promise, setEnabled: async () => {}, flush: async () => {} }
    const store = createInputStore({ repository, coordinator, runtimeCapture: () => ({ transportIdentity: "runtime", generation: 1 }) })
    store.getState().setDraftText(key("runtime"), "draft")
    const disabling = store.getState().setDraftPersistenceEnabled(false)
    pending.resolve({ ok: true, value: undefined })
    await disabling
    const storedKeys = storage.values.size
    store.getState().setDraftText(key("runtime"), "later")
    await tick()
    expect(store.getState().draftPersistence).toEqual({})
    expect(storage.values.size).toBe(storedKeys)
  })
})
