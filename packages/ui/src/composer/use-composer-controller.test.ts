import { describe, expect, test } from "bun:test"
import { draftKeyString, type DraftKey, type DraftRecord } from "@/sync/input-draft-types"
import { applyBrowserComposerEdit, classifyComposerRecordUpdate, composerDocumentFingerprint, composerKeyMatchesRequest, enterComposerHistoryPreview, exitComposerHistoryPreview, normalizeComposerMentionsForCommit, planComposerRecovery, rebaseComposerMentions, resolveComposerKeyBinding } from "./use-composer-controller"

const key: DraftKey = { transportIdentity: "runtime", owner: { kind: "session", ownerID: "session" } }
const record = (revision: number, text: string, mentions: DraftRecord["mentions"] = []): DraftRecord => ({ version: 1, key, revision, text, attachments: [], syntheticParts: [], mentions })
const cursor = (appliedRevision = 0) => ({ keyID: draftKeyString(key), epoch: 1, appliedRevision })

describe("composer controller record classification", () => {
  test("guards commands with the requested draft key before the layout switch", () => {
    const sameSessionOtherTransport: DraftKey = { transportIdentity: "other-runtime", owner: { kind: "session", ownerID: "session" } }
    expect(composerKeyMatchesRequest(key, draftKeyString(key))).toBe(true)
    expect(composerKeyMatchesRequest(key, draftKeyString(sameSessionOtherTransport))).toBe(false)
    expect(composerKeyMatchesRequest(sameSessionOtherTransport, draftKeyString(sameSessionOtherTransport))).toBe(true)
    expect(composerKeyMatchesRequest(key, "other-key")).toBe(false)
    expect(composerKeyMatchesRequest(key, null)).toBe(false)
    expect(composerKeyMatchesRequest(null, draftKeyString(key))).toBe(false)
    expect(composerKeyMatchesRequest(null, null)).toBe(false)
  })

  test("binds each transport's document for the same session", () => {
    const keyA: DraftKey = { transportIdentity: "runtime-a", owner: { kind: "session", ownerID: "session" } }
    const keyB: DraftKey = { transportIdentity: "runtime-b", owner: { kind: "session", ownerID: "session" } }
    const drafts: Record<string, DraftRecord> = {
      [draftKeyString(keyA)]: { version: 1, key: keyA, revision: 1, text: "A doc", attachments: [], syntheticParts: [], mentions: [] },
      [draftKeyString(keyB)]: { version: 1, key: keyB, revision: 1, text: "B doc", attachments: [], syntheticParts: [], mentions: [] },
    }
    const getDraft = (draftKey: DraftKey) => drafts[draftKeyString(draftKey)]
    const bindingA = resolveComposerKeyBinding(keyA, new Map(), getDraft)
    const bindingB = resolveComposerKeyBinding(keyB, new Map(), getDraft)
    expect(bindingA.document).toEqual({ text: "A doc", references: [] })
    expect(bindingA.mentions).toEqual([])
    expect(bindingA.revision).toBe(1)
    expect(bindingA.keyID).toBe(draftKeyString(keyA))
    expect(bindingB.document).toEqual({ text: "B doc", references: [] })
    expect(bindingB.mentions).toEqual([])
    expect(bindingB.revision).toBe(1)
    expect(bindingB.keyID).toBe(draftKeyString(keyB))
    expect(bindingA.key).toEqual(keyA)
    expect(bindingA.key).not.toBe(keyA)
    expect(bindingB.key).toEqual(keyB)
    expect(bindingB.key).not.toBe(keyB)
  })
  test("keeps input mode and history ownership for a local revision echo", () => {
    const document = { text: "local", references: [] }
    expect(classifyComposerRecordUpdate(document, record(2, "local"), { keyID: draftKeyString(key), revision: 2, fingerprint: composerDocumentFingerprint(document) }, cursor(1))).toBe("local-echo")
  })

  test("treats mention-only revisions as metadata and hydration documents as external", () => {
    const document = { text: "@src/a.ts", references: [] }
    const mention = { kind: "file" as const, value: "src/a.ts", path: "src/a.ts", label: "src/a.ts", range: { start: 0, end: 9 } }
    expect(classifyComposerRecordUpdate(document, record(3, document.text, [mention]), undefined, cursor(2))).toBe("same-document-metadata")
    expect(classifyComposerRecordUpdate(document, record(4, "hydrated"), undefined, cursor(3))).toBe("external-document")
  })

  test("ignores stale external records after a newer local revision", () => {
    expect(classifyComposerRecordUpdate({ text: "new", references: [] }, record(4, "old"), undefined, cursor(5))).toBe("ignore")
  })
})

describe("composer controller transitions", () => {
  test("sorts programmatic updater mentions for commit without changing the updater array", () => {
    const existingMention = { kind: "file" as const, value: "later.ts", path: "later.ts", label: "later.ts", range: { start: 10, end: 19 } }
    const addedMention = { kind: "file" as const, value: "first.ts", path: "first.ts", label: "first.ts", range: { start: 0, end: 9 } }
    const updaterResult = [existingMention, addedMention]

    const candidate = normalizeComposerMentionsForCommit(updaterResult)

    expect(candidate).toEqual([addedMention, existingMention])
    expect(updaterResult).toEqual([existingMention, addedMention])
    expect(candidate).not.toBe(updaterResult)
  })

  test("isolates history preview mentions and restores the durable composer state", () => {
    const mention = { kind: "file" as const, value: "file", path: "file", label: "file", range: { start: 0, end: 5 } }
    const entered = enterComposerHistoryPreview({ text: "@file", references: [] }, [mention], { text: "history", references: [{ id: "session", kind: "session", sessionId: "s", display: "history", start: 0, end: 7 }] })
    expect([entered.document, entered.mentions]).toEqual([{ text: "history", references: [] }, []])
    expect(exitComposerHistoryPreview(entered.preview)).toEqual({ document: { text: "@file", references: [] }, mentions: [mention] })
  })

  test("rebases mentions through reference expansion and removes touched ranges", () => {
    const document = { text: "start @file end", references: [] }
    const mention = { kind: "file" as const, value: "file", path: "file", label: "file", range: { start: 6, end: 11 } }
    expect(rebaseComposerMentions([mention], document, { oldStart: 7, oldEnd: 8, newEnd: 7 })).toEqual([])
    expect(rebaseComposerMentions([mention], { text: "x start @file end", references: [] }, { oldStart: 0, oldEnd: 0, newEnd: 2 })).toEqual([{ ...mention, range: { start: 8, end: 13 } }])
  })

  test("preserves and rebases file mentions through a browser edit", () => {
    const mention = { kind: "file" as const, value: "src/a.ts", path: "src/a.ts", label: "src/a.ts", range: { start: 5, end: 14 } }
    expect(applyBrowserComposerEdit({ text: "open @src/a.ts", references: [] }, [mention], "please open @src/a.ts", 7)).toEqual({
      document: { text: "please open @src/a.ts", references: [] }, mentions: [{ ...mention, range: { start: 12, end: 21 } }], selectionStart: 7, selectionEnd: 7,
      removedReferences: [],
    })
  })

  test("plans cross-runtime recovery at the captured key with failed mentions first", () => {
    const failedMention = { kind: "file" as const, value: "failed", path: "failed", label: "failed", range: { start: 0, end: 7 } }
    const currentMention = { kind: "agent" as const, value: "current", path: "current", label: "current", range: { start: 0, end: 8 } }
    const recovered = planComposerRecovery({ document: { text: "@failed", references: [] }, mentions: [failedMention] }, { text: "@current", composerReferences: [], mentions: [currentMention] })
    expect(recovered).toEqual({ document: { text: "@failed\n\n@current", references: [] }, mentions: [failedMention, { ...currentMention, range: { start: 9, end: 17 } }] })
  })

  test("keeps same-path recovery occurrences at distinct UTF-16 ranges", () => {
    const mention = { kind: "file" as const, value: "src/a.ts", path: "src/a.ts", label: "src/a.ts", range: { start: 0, end: 9 } }
    const recovered = planComposerRecovery({ document: { text: "@src/a.ts", references: [] }, mentions: [mention] }, { text: "@src/a.ts", composerReferences: [], mentions: [mention] })
    expect(recovered.mentions).toEqual([mention])
    const appended = planComposerRecovery({ document: { text: "@src/a.ts", references: [] }, mentions: [mention] }, { text: "@src/a.ts later", composerReferences: [], mentions: [{ ...mention, range: { start: 0, end: 9 } }] })
    expect(appended.mentions.map((item) => item.range)).toEqual([{ start: 0, end: 9 }, { start: 11, end: 20 }])
  })
})
