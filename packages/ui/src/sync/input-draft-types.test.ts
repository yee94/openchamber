import { describe, expect, test } from "bun:test"
import { cloneDraftRecord, draftAttachmentRefID, draftKeyString, draftRootAttachmentOccurrenceRefID, draftSyntheticPartAttachmentOccurrenceRefID, isDraftRecordPersistable, parseDraftRecord, type DraftRecord } from "./input-draft-types"

const record = (): DraftRecord => ({
  version: 1,
  key: { transportIdentity: "runtime-a", owner: { kind: "session", ownerID: "same" } },
  revision: 1,
  text: "draft",
  attachments: [{ attachmentID: "root-a", attachmentRefID: draftRootAttachmentOccurrenceRefID("root-a"), filename: "a.txt", mimeType: "text/plain", size: 1, locator: { kind: "blob", blobID: "blob-a" }, source: "local" }],
  syntheticParts: [{ partID: "part-a", text: "part", attachments: [{ attachmentID: "part-a", attachmentRefID: draftSyntheticPartAttachmentOccurrenceRefID("part-a", "part-a"), filename: "a.txt", mimeType: "text/plain", size: 1, locator: { kind: "url", url: "https://example.test/a" }, source: "server", serverPath: "/server/a" }] }],
  mentions: [{ kind: "file", value: "file-a", path: "/a", label: "a", range: { start: 0, end: 1 } }, { kind: "agent", value: "agent-a", path: "agent/a", label: "Agent A", range: { start: 1, end: 2 } }],
})

describe("input draft types", () => {
  test("serializes transport-scoped attachment references and distinguishes occurrences", () => {
    const reference = { transportIdentity: "runtime-a", owner: { kind: "session", ownerID: "same" } as const, attachmentOccurrenceRefID: draftRootAttachmentOccurrenceRefID("attachment-a") }
    expect(draftKeyString(reference)).toBe('["runtime-a","session","same"]')
    expect(draftAttachmentRefID(reference)).toBe('["runtime-a","session","same","[\\"root\\",\\"attachment-a\\"]"]')
    expect(draftAttachmentRefID({ ...reference, transportIdentity: "runtime-b" })).not.toBe(draftAttachmentRefID(reference))
    expect(draftSyntheticPartAttachmentOccurrenceRefID("part-a", "attachment-a")).not.toBe(draftRootAttachmentOccurrenceRefID("attachment-a"))
  })

  test("parses and clones the complete frozen DTO", () => {
    const draft = record()
    const parsed = parseDraftRecord(draft)
    expect(parsed).toEqual(draft)
    const cloned = cloneDraftRecord(draft)
    expect(cloned).toEqual(draft)
    expect(cloned).not.toBe(draft)
    expect(cloned?.attachments[0]).not.toBe(draft.attachments[0])
    expect(isDraftRecordPersistable(draft)).toBe(true)
  })

  test("rejects unknown fields at every DTO depth", () => {
    const topLevel = { ...record(), extra: true }
    const synthetic = record()
    synthetic.syntheticParts[0] = { ...synthetic.syntheticParts[0]!, extra: true } as never
    const mention = record()
    mention.mentions[0] = { ...mention.mentions[0]!, extra: true } as never
    const nested = record()
    nested.attachments[0] = { ...nested.attachments[0]!, locator: { ...nested.attachments[0]!.locator, extra: true } } as never
    expect(parseDraftRecord(topLevel)).toBe(undefined)
    expect(parseDraftRecord(synthetic)).toBe(undefined)
    expect(parseDraftRecord(mention)).toBe(undefined)
    expect(parseDraftRecord(nested)).toBe(undefined)
  })

  test("rejects unsafe values and malformed DTO fields", () => {
    const cyclic = record() as DraftRecord & { cycle?: unknown }
    cyclic.cycle = cyclic
    expect(parseDraftRecord(cyclic)).toBe(undefined)
    expect(parseDraftRecord({ ...record(), revision: -1 })).toBe(undefined)
    expect(parseDraftRecord({ ...record(), revision: 0 })).toBe(undefined)
    expect(parseDraftRecord({ ...record(), attachments: [{ ...record().attachments[0]!, locator: { kind: "url", url: "blob:unsafe" } }] })).toBe(undefined)
    expect(parseDraftRecord({ ...record(), attachments: [{ ...record().attachments[0]!, locator: { kind: "url", url: "data:text/plain,unsafe" } }] })).toBe(undefined)
    expect(parseDraftRecord({ ...record(), mentions: [{ ...record().mentions[0]!, range: { start: 2, end: 2 } }] })).toBe(undefined)
    expect(parseDraftRecord({ ...record(), mentions: [{ ...record().mentions[0]!, range: { start: 0, end: 6 } }] })).toBe(undefined)
    expect(parseDraftRecord({ ...record(), attachments: [{ ...record().attachments[0]!, file: new File(["x"], "a.txt") }] })).toBe(undefined)
  })

  test("accepts durable file URLs and rejects queue and send draft keys", () => {
    const file = record()
    file.attachments[0] = { ...file.attachments[0]!, locator: { kind: "url", url: "file:///tmp/a.txt" } }
    expect(parseDraftRecord(file)).toEqual(file)
    for (const kind of ["queue", "send"]) {
      expect(parseDraftRecord({ ...record(), key: { transportIdentity: "runtime-a", owner: { kind, ownerID: "owner" } } })).toBe(undefined)
    }
  })

  test("validates occurrence structure and record-wide attachment and part identity", () => {
    const wrongRoot = record()
    wrongRoot.attachments[0] = { ...wrongRoot.attachments[0]!, attachmentRefID: draftSyntheticPartAttachmentOccurrenceRefID("part-a", "root-a") }
    const wrongPart = record()
    wrongPart.syntheticParts[0]!.attachments[0] = { ...wrongPart.syntheticParts[0]!.attachments[0]!, attachmentRefID: draftSyntheticPartAttachmentOccurrenceRefID("other-part", "part-a") }
    const duplicateRef = record()
    duplicateRef.syntheticParts[0]!.attachments[0] = { ...duplicateRef.syntheticParts[0]!.attachments[0]!, attachmentRefID: duplicateRef.attachments[0]!.attachmentRefID }
    const duplicatePart = record()
    duplicatePart.syntheticParts.push({ ...duplicatePart.syntheticParts[0]! })
    expect(parseDraftRecord(wrongRoot)).toBe(undefined)
    expect(parseDraftRecord(wrongPart)).toBe(undefined)
    expect(parseDraftRecord(duplicateRef)).toBe(undefined)
    expect(parseDraftRecord(duplicatePart)).toBe(undefined)
  })

  test("enforces source-specific attachment fields while allowing empty MIME types", () => {
    const emptyMime = record()
    emptyMime.attachments[0] = { ...emptyMime.attachments[0]!, mimeType: "" }
    const vscode = record()
    vscode.attachments[0] = { ...vscode.attachments[0]!, source: "vscode", vscodePath: "/vscode/a", vscodeSource: "selection" }
    const invalidVscodeSource = record()
    invalidVscodeSource.attachments[0] = { ...invalidVscodeSource.attachments[0]!, source: "vscode", vscodePath: "/vscode/a", vscodeSource: "workspace" as never }
    const missingVscodeFields = record()
    missingVscodeFields.attachments[0] = { ...missingVscodeFields.attachments[0]!, source: "vscode" }
    const missingServerPath = record()
    missingServerPath.syntheticParts[0]!.attachments[0] = { ...missingServerPath.syntheticParts[0]!.attachments[0]!, serverPath: undefined }
    expect(parseDraftRecord(emptyMime)).toEqual(emptyMime)
    expect(parseDraftRecord(vscode)).toEqual(vscode)
    expect(parseDraftRecord(invalidVscodeSource)).toBe(undefined)
    expect(parseDraftRecord(missingVscodeFields)).toBe(undefined)
    expect(parseDraftRecord(missingServerPath)).toBe(undefined)
  })
})
