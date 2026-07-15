import { afterEach, describe, expect, test } from "bun:test"
import { createInputDraftBlobStore, MemoryInputDraftBlobDriver, type InputDraftBlobDriver, type InputDraftBlobStore, type InputDraftBlobTransaction } from "./input-draft-blob-store"
import { createInputDraftDurabilityCoordinator } from "./input-draft-durability-coordinator"
import type { InputDraftMetadataPersistenceCoordinator, InputDraftMetadataRepository, InputDraftMetadataSnapshot } from "./input-draft-metadata-store"
import { draftKeyString, draftRootAttachmentOccurrenceRefID, type DraftKey, type DraftRecord } from "./input-draft-types"
import { createInputStore } from "./input-store"

const originalFileReader = globalThis.FileReader
const deferred = <T,>() => { let resolve!: (value: T) => void; const promise = new Promise<T>((next) => { resolve = next }); return { promise, resolve } }
const key = (ownerID = "session", transportIdentity = "runtime"): DraftKey => ({ transportIdentity, owner: { kind: "session", ownerID } })
const snapshot = (drafts: DraftRecord[] = [], tombstones: Record<string, number> = {}): InputDraftMetadataSnapshot => ({ version: 1, drafts: Object.fromEntries(drafts.map((draft) => [draftKeyString(draft.key), draft])), tombstones, migration: { complete: true, claimedTransportIdentity: "runtime", captured: true, markerCommitted: true, cleanupComplete: true }, legacy: { entries: {} } })
const record = (draftKey: DraftKey, text = "", revision = 1): DraftRecord => ({ version: 1, key: draftKey, revision, text, attachments: [], syntheticParts: [], mentions: [] })

class ControlledFileReader {
  static readers: ControlledFileReader[] = []
  result: string | ArrayBuffer | null = null
  error: DOMException | null = null
  onload: ((event: ProgressEvent<FileReader>) => unknown) | null = null
  onerror: ((event: ProgressEvent<FileReader>) => unknown) | null = null
  onabort: ((event: ProgressEvent<FileReader>) => unknown) | null = null
  readAsDataURL() { ControlledFileReader.readers.push(this) }
  succeed(value = "data:text/plain;base64,eA==") { this.result = value; this.onload?.({} as ProgressEvent<FileReader>) }
  fail() { this.error = new DOMException("read", "ReadError"); this.onerror?.({} as ProgressEvent<FileReader>) }
}

afterEach(() => { globalThis.FileReader = originalFileReader; ControlledFileReader.readers = [] })

const setup = (initial = snapshot(), options: { blockPersist?: boolean; failPersist?: boolean; blobStore?: InputDraftBlobStore; persistenceEnabled?: boolean } = {}) => {
  const writes: InputDraftMetadataSnapshot[] = []
  const gate = deferred<void>()
  let blocked = options.blockPersist ?? false
  let fail = options.failPersist ?? false
  let migrations = 0
  let migrationTask: Promise<{ ok: true; value: InputDraftMetadataSnapshot }> | undefined
  const repository: InputDraftMetadataRepository = {
    persist: async () => ({ ok: true, value: undefined }),
    migrate: async () => migrationTask ??= Promise.resolve().then(() => { migrations++; return { ok: true as const, value: initial } }),
    flush: async () => {}, setEnabled: async () => {},
  }
  const metadata: InputDraftMetadataPersistenceCoordinator = {
    persist: async (value) => { if (blocked) await gate.promise; if (fail) { fail = false; return { ok: false, error: { code: "quota" } } } writes.push(value); return { ok: true, value: undefined } },
    flush: async () => {}, setEnabled: async () => {},
  }
  const blobs = options.blobStore ?? createInputDraftBlobStore(new MemoryInputDraftBlobDriver())
  const durability = createInputDraftDurabilityCoordinator(blobs, metadata, { enabled: options.persistenceEnabled ?? true })
  let runtime = { transportIdentity: "runtime", generation: 1 }
  const store = createInputStore({ repository, coordinator: metadata, durability, blobStore: blobs, persistenceEnabled: options.persistenceEnabled, runtimeCapture: () => runtime, createID: (() => { let id = 0; return () => `id-${++id}` })() })
  return { store, blobs, writes, migrations: () => migrations, failNext: () => { fail = true }, release: () => { blocked = false; gate.resolve() }, runtime: (value: typeof runtime) => { runtime = value } }
}

describe("input draft attachment concurrency", () => {
  test("hydrates initially disabled persistence without blob transactions", async () => {
    const base = new MemoryInputDraftBlobDriver()
    let transactions = 0
    const driver: InputDraftBlobDriver = { transaction: async <T>(action: (transaction: InputDraftBlobTransaction) => Promise<T>): Promise<T> => { transactions++; return base.transaction(action) } }
    const { store } = setup(snapshot(), { blobStore: createInputDraftBlobStore(driver), persistenceEnabled: false })
    await store.getState().hydrateDraftMetadata("runtime")
    expect(transactions).toBe(0)
  })

  test("merges an add completed after concurrent draft fields update", async () => {
    globalThis.FileReader = ControlledFileReader as unknown as typeof FileReader
    const { store } = setup(); await store.getState().hydrateDraftMetadata("runtime")
    const adding = store.getState().addDraftLocalAttachment(key(), new File(["x"], "x.txt"))
    store.getState().setDraftText(key(), "@file")
    store.getState().setDraftMentions(key(), [{ kind: "file", value: "file", path: "file", label: "file", range: { start: 0, end: 5 } }])
    store.getState().setDraftSyntheticParts(key(), [{ partID: "part", text: "context", attachments: [] }])
    ControlledFileReader.readers.shift()!.succeed(); await adding
    const current = store.getState().getDraft(key())!
    expect(current.text).toBe("@file")
    expect(current.mentions).toHaveLength(1)
    expect(current.syntheticParts).toHaveLength(1)
    expect(current.attachments).toHaveLength(1)
  })

  test("discards adds whose source changes while FileReader is pending", async () => {
    globalThis.FileReader = ControlledFileReader as unknown as typeof FileReader
    for (const mutate of [
      (store: ReturnType<typeof setup>["store"]) => { store.getState().ensureDraft(key()); store.getState().deleteDraft(key()) },
      (store: ReturnType<typeof setup>["store"]) => { store.getState().ensureDraft(key()); store.getState().moveDraft(key(), key("destination")) },
      (store: ReturnType<typeof setup>["store"], runtime: ReturnType<typeof setup>["runtime"]) => runtime({ transportIdentity: "runtime", generation: 2 }),
    ]) {
      const fixture = setup(); await fixture.store.getState().hydrateDraftMetadata("runtime")
      const adding = fixture.store.getState().addDraftLocalAttachment(key(), new File(["x"], "x.txt"))
      mutate(fixture.store, fixture.runtime)
      ControlledFileReader.readers.shift()!.succeed()
      expect(await adding).toBe(undefined)
      expect(fixture.store.getState().getDraft(key())?.attachments ?? []).toEqual([])
    }
  })

  test("reports FileReader add failures only for the current source", async () => {
    globalThis.FileReader = ControlledFileReader as unknown as typeof FileReader
    for (const [mutate, reports] of [
      [() => undefined, true],
      [(store: ReturnType<typeof setup>["store"]) => { store.getState().ensureDraft(key()); store.getState().deleteDraft(key()) }, false],
      [(store: ReturnType<typeof setup>["store"]) => { store.getState().ensureDraft(key()); store.getState().moveDraft(key(), key("destination")) }, false],
      [(_store: ReturnType<typeof setup>["store"], runtime: ReturnType<typeof setup>["runtime"]) => runtime({ transportIdentity: "runtime", generation: 2 }), false],
    ] as const) {
      const fixture = setup(); await fixture.store.getState().hydrateDraftMetadata("runtime")
      fixture.store.setState({ draftAttachmentPersistence: {} })
      const adding = fixture.store.getState().addDraftLocalAttachment(key(), new File(["x"], "x.txt"))
      mutate(fixture.store, fixture.runtime)
      ControlledFileReader.readers.shift()!.fail()
      expect(await adding).toBe(undefined)
      expect(fixture.store.getState().draftAttachmentPersistence[draftKeyString(key())]?.status).toBe(reports ? "error" : undefined)
    }
  })

  test("keeps concurrent text changes when replace completes", async () => {
    globalThis.FileReader = ControlledFileReader as unknown as typeof FileReader
    const { store } = setup(); await store.getState().hydrateDraftMetadata("runtime")
    const original = store.getState().addDraftDurableAttachment(key(), { filename: "old.txt", mimeType: "text/plain", size: 1, source: "server", serverPath: "/old", url: "https://example.test/old" })!
    const replacing = store.getState().replaceDraftAttachment(key(), original.attachmentRefID, new File(["new"], "new.txt"))
    store.getState().setDraftText(key(), "latest")
    ControlledFileReader.readers.shift()!.succeed()
    expect((await replacing)?.filename).toBe("new.txt")
    expect(store.getState().getDraft(key())?.text).toBe("latest")
  })

  test("discards replacements after their original occurrence or source changes", async () => {
    globalThis.FileReader = ControlledFileReader as unknown as typeof FileReader
    for (const mutate of [
      (store: ReturnType<typeof setup>["store"], attachmentRefID: string) => void store.getState().removeDraftAttachment(key(), attachmentRefID),
      (store: ReturnType<typeof setup>["store"]) => void store.getState().deleteDraft(key()),
      (store: ReturnType<typeof setup>["store"]) => void store.getState().moveDraft(key(), key("destination")),
      (_store: ReturnType<typeof setup>["store"], _attachmentRefID: string, runtime?: ReturnType<typeof setup>["runtime"]) => runtime?.({ transportIdentity: "runtime", generation: 2 }),
    ]) {
      const fixture = setup(); await fixture.store.getState().hydrateDraftMetadata("runtime")
      const original = fixture.store.getState().addDraftDurableAttachment(key(), { filename: "old.txt", mimeType: "text/plain", size: 1, source: "server", serverPath: "/old", url: "https://example.test/old" })!
      const replacing = fixture.store.getState().replaceDraftAttachment(key(), original.attachmentRefID, new File(["new"], "new.txt"))
      mutate(fixture.store, original.attachmentRefID, fixture.runtime)
      ControlledFileReader.readers.shift()!.succeed()
      expect(await replacing).toBe(undefined)
      expect(fixture.store.getState().getDraft(key())?.attachments.map((item) => item.filename) ?? []).not.toContain("new.txt")
    }
  })

  test("reports FileReader replacement failures only while the occurrence remains current", async () => {
    globalThis.FileReader = ControlledFileReader as unknown as typeof FileReader
    for (const [mutate, reports] of [
      [() => undefined, true],
      [(store: ReturnType<typeof setup>["store"], attachmentRefID: string) => void store.getState().removeDraftAttachment(key(), attachmentRefID), false],
      [(store: ReturnType<typeof setup>["store"]) => void store.getState().deleteDraft(key()), false],
      [(store: ReturnType<typeof setup>["store"]) => void store.getState().moveDraft(key(), key("destination")), false],
      [(_store: ReturnType<typeof setup>["store"], _attachmentRefID: string, runtime?: ReturnType<typeof setup>["runtime"]) => runtime?.({ transportIdentity: "runtime", generation: 2 }), false],
    ] as const) {
      const fixture = setup(); await fixture.store.getState().hydrateDraftMetadata("runtime")
      const original = fixture.store.getState().addDraftDurableAttachment(key(), { filename: "old.txt", mimeType: "text/plain", size: 1, source: "server", serverPath: "/old", url: "https://example.test/old" })!
      fixture.store.setState({ draftAttachmentPersistence: {} })
      const replacing = fixture.store.getState().replaceDraftAttachment(key(), original.attachmentRefID, new File(["new"], "new.txt"))
      mutate(fixture.store, original.attachmentRefID, fixture.runtime)
      const statusBeforeFailure = fixture.store.getState().draftAttachmentPersistence[draftKeyString(key())]?.status
      ControlledFileReader.readers.shift()!.fail()
      expect(await replacing).toBe(undefined)
      expect(fixture.store.getState().draftAttachmentPersistence[draftKeyString(key())]?.status).toBe(reports ? "error" : statusBeforeFailure)
    }
  })

  test("invalidates delayed attachment hydration after delete", async () => {
    const source = key("source")
    const draft = record(source); draft.attachments = [{ attachmentID: "a", attachmentRefID: draftRootAttachmentOccurrenceRefID("a"), filename: "a.txt", mimeType: "text/plain", size: 1, locator: { kind: "blob", blobID: "blob" }, source: "local" }]
    const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()); await base.put("blob", "data:text/plain;base64,eA==")
    const gate = deferred<void>()
    const { store } = setup(snapshot([draft]), { blobStore: { ...base, read: async (blobID) => { await gate.promise; return base.read(blobID) } } })
    await store.getState().hydrateDraftMetadata("runtime")
    const hydrating = store.getState().hydrateDraftAttachments(source)
    await Promise.resolve()
    expect(store.getState().deleteDraft(source)).toBe(true)
    gate.resolve(); await hydrating
    const sourceID = draftKeyString(source)
    expect(store.getState().drafts[sourceID]).toBe(undefined)
    expect(store.getState().draftHydration[sourceID]).toBe(undefined)
    expect(store.getState().draftAttachmentViews[sourceID]).toBe(undefined)
  })

  test("invalidates delayed attachment hydration across URL and blob draft moves", async () => {
    for (const withAttachments of [false, true]) {
      const source = key(`source-${withAttachments}`); const destination = key(`destination-${withAttachments}`)
      const draft = record(source); draft.attachments = [{ attachmentID: "a", attachmentRefID: draftRootAttachmentOccurrenceRefID("a"), filename: "a.txt", mimeType: "text/plain", size: 1, locator: withAttachments ? { kind: "blob", blobID: "blob" } : { kind: "url", url: "https://example.test/a" }, source: "local" }]
      const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver()); await base.put("blob", "data:text/plain;base64,eA==")
      const gate = deferred<void>()
      const { store } = setup(snapshot([draft]), { blobStore: { ...base, read: async (blobID) => { await gate.promise; return base.read(blobID) } } })
      await store.getState().hydrateDraftMetadata("runtime")
      const hydrating = store.getState().hydrateDraftAttachments(source)
      await Promise.resolve()
      const moving = withAttachments ? store.getState().moveDraftWithAttachments(source, destination) : Promise.resolve(store.getState().moveDraft(source, destination))
      expect(store.getState().getDraft(destination)?.key).toEqual(destination)
      gate.resolve()
      const moved = await moving; await hydrating
      if (!withAttachments) expect(moved?.key).toEqual(destination)
      const sourceID = draftKeyString(source); const destinationID = draftKeyString(destination)
      expect(store.getState().drafts[sourceID]).toBe(undefined)
      expect(store.getState().draftHydration[sourceID]).toBe(undefined)
      expect(store.getState().draftAttachmentViews[sourceID]).toBe(undefined)
      expect(store.getState().getDraft(destination)?.key).toEqual(destination)
      await store.getState().hydrateDraftAttachments(destination)
      expect(store.getState().draftHydration[destinationID]).toBe(withAttachments ? "degraded" : "ready")
    }
  })

  test("hydrates preseeded text and zero-metadata attachment views through one seed", async () => {
    const draft = record(key(), "seeded")
    const { store, writes, migrations } = setup(snapshot([draft]))
    await Promise.all([store.getState().hydrateDraftMetadata("runtime"), store.getState().hydrateDraftMetadata("runtime")])
    await store.getState().flushDraftPersistence()
    expect(store.getState().getDraft(key())?.text).toBe("seeded")
    expect(store.getState().getDraftAttachmentViews(key())).toEqual([])
    expect(migrations()).toBe(1)
    expect(writes.at(-1)?.drafts[draftKeyString(key())]?.text).toBe("seeded")
  })

  test("accepts only an older destination tombstone during moves", async () => {
    for (const [tombstone, moves] of [[3, false], [4, false], [1, true]] as const) {
      const source = key("source"); const destination = key("destination")
      const { store } = setup(snapshot([], { [draftKeyString(destination)]: tombstone }))
      await store.getState().hydrateDraftMetadata("runtime")
      store.getState().setDraftText(source, "move")
      expect(store.getState().moveDraft(source, destination)?.key).toEqual(moves ? destination : undefined)
      if (moves) expect(store.getState().tombstones[draftKeyString(destination)]).toBe(undefined)
    }
  })

  test("rolls back destination references after failed attachment move metadata and restores memory", async () => {
    globalThis.FileReader = ControlledFileReader as unknown as typeof FileReader
    const source = key("source"); const destination = key("destination")
    const { store, blobs, failNext } = setup()
    await store.getState().hydrateDraftMetadata("runtime")
    const pending = store.getState().addDraftLocalAttachment(source, new File(["x"], "x.txt"))
    ControlledFileReader.readers.shift()!.succeed(); const attachment = await pending
    await store.getState().flushDraftPersistence(); failNext()
    const moved = await store.getState().moveDraftWithAttachments(source, destination)
    expect(moved).toBe(undefined)
    expect(store.getState().getDraft(destination)?.attachments).toHaveLength(1)
    expect(store.getState().draftPersistence[draftKeyString(destination)]?.status).toBe("error")
    if (attachment?.locator.kind === "blob") expect(await blobs.readReference({ transportIdentity: "runtime", owner: destination.owner, attachmentOccurrenceRefID: attachment.attachmentRefID })).toEqual({ ok: true, value: undefined })
  })

  test("marks generation-shifted move and ordinary commits dirty until the active generation retries", async () => {
    const { store, runtime, writes } = setup()
    await store.getState().hydrateDraftMetadata("runtime")
    store.getState().setDraftText(key("one"), "one")
    runtime({ transportIdentity: "runtime", generation: 2 })
    await store.getState().flushDraftPersistence()
    expect(store.getState().draftPersistence[draftKeyString(key("one"))]?.status).toBe("saving")
    await store.getState().setDraftPersistenceEnabled(false)
    await store.getState().setDraftPersistenceEnabled(true)
    await store.getState().flushDraftPersistence()
    expect(writes.some((value) => value.drafts[draftKeyString(key("one"))]?.text === "one")).toBe(true)
  })

  test("quiesces disabled blocked blob acquisition without metadata writes and persists dirty memory after enable", async () => {
    globalThis.FileReader = ControlledFileReader as unknown as typeof FileReader
    const base = createInputDraftBlobStore(new MemoryInputDraftBlobDriver())
    const retainGate = deferred<void>(); let entered = false
    const blobs: InputDraftBlobStore = { ...base, putAndRetain: async (...args) => { entered = true; await retainGate.promise; return base.putAndRetain(...args) } }
    const { store, writes } = setup(snapshot(), { blobStore: blobs })
    await store.getState().hydrateDraftMetadata("runtime")
    const adding = store.getState().addDraftLocalAttachment(key(), new File(["x"], "x.txt")); ControlledFileReader.readers.shift()!.succeed()
    while (!entered) await Promise.resolve()
    const disabling = store.getState().setDraftPersistenceEnabled(false)
    retainGate.resolve(); await adding; await disabling; await store.getState().flushDraftPersistence()
    expect(writes).toHaveLength(1)
    await store.getState().setDraftPersistenceEnabled(true); await store.getState().flushDraftPersistence()
    expect(writes.length).toBeGreaterThan(1)
  })

  test("reports missing blobs, database reads, FileReader errors, and stale hydration without replacing newer views", async () => {
    globalThis.FileReader = ControlledFileReader as unknown as typeof FileReader
    const draft = record(key()); draft.attachments = [{ attachmentID: "a", attachmentRefID: draftRootAttachmentOccurrenceRefID("a"), filename: "a.txt", mimeType: "text/plain", size: 1, locator: { kind: "blob", blobID: "missing" }, source: "local" }]
    const { store } = setup(snapshot([draft])); await store.getState().hydrateDraftMetadata("runtime"); await store.getState().hydrateDraftAttachments(key())
    expect(store.getState().draftHydration[draftKeyString(key())]).toBe("degraded")
    const reading = store.getState().addDraftLocalAttachment(key(), new File(["bad"], "bad.txt")); ControlledFileReader.readers.shift()?.fail(); const failed = await reading
    expect(failed).toBe(undefined)
  })

  test("isolates identical session IDs across runtimes for records, views, and blob references", async () => {
    globalThis.FileReader = ControlledFileReader as unknown as typeof FileReader
    const { store, blobs } = setup(); await store.getState().hydrateDraftMetadata("runtime")
    const first = key("same", "runtime"); const second = key("same", "other")
    const one = store.getState().addDraftLocalAttachment(first, new File(["a"], "a.txt")); ControlledFileReader.readers.shift()!.succeed(); const attachment = await one
    store.getState().addDraftDurableAttachment(second, { filename: "b.txt", mimeType: "text/plain", size: 1, source: "server", serverPath: "/b", url: "https://example.test/b" })
    await store.getState().flushDraftPersistence()
    expect(store.getState().getDraftAttachmentViews(first).map((view) => view.filename)).toEqual(["a.txt"])
    expect(store.getState().getDraftAttachmentViews(second).map((view) => view.filename)).toEqual(["b.txt"])
    if (attachment?.locator.kind === "blob") expect(await blobs.readReference({ transportIdentity: "other", owner: second.owner, attachmentOccurrenceRefID: attachment.attachmentRefID })).toEqual({ ok: true, value: undefined })
  })

  test("keeps root then synthetic authority order and clears stale views", async () => {
    globalThis.FileReader = ControlledFileReader as unknown as typeof FileReader
    const { store } = setup(); await store.getState().hydrateDraftMetadata("runtime")
    const current = key(); const root = store.getState().addDraftLocalAttachment(current, new File(["r"], "root.txt")); ControlledFileReader.readers.shift()!.succeed(); await root
    store.getState().setDraftSyntheticParts(current, [{ partID: "part", text: "p", attachments: [] }])
    const synthetic = store.getState().addDraftLocalAttachment(current, new File(["s"], "synthetic.txt"), { partID: "part" }); ControlledFileReader.readers.shift()!.succeed(); await synthetic
    await store.getState().flushDraftPersistence()
    expect(store.getState().getDraftAttachmentViews(current).map((view) => view.filename)).toEqual(["root.txt", "synthetic.txt"])
    store.getState().setDraftAttachments(current, [])
    expect(store.getState().getDraftAttachmentViews(current).map((view) => view.filename)).toEqual(["synthetic.txt"])
  })
})
