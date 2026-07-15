import { draftRootAttachmentOccurrenceRefID, isDurableURL, type DraftAttachmentReference } from "@/sync/input-draft-types"
import type { InputDraftBlobStore } from "@/sync/input-draft-blob-store"
import { LEGACY_MESSAGE_QUEUE_KEY, QUEUE_LEDGER_LIMITS, emptyQueueLedgerSnapshot, parseQueueLedgerScopeKey, queueLedgerScopeKey, readQueueLedgerSnapshotDetailed, type QueueAttachmentIssueDTO, type QueueAttachmentRefDTO, type QueueItemDTO, type QueueLedgerMetadataErrorCode, type QueueLedgerMetadataSink, type QueueLedgerScope, type QueueLedgerSnapshotV4, writeQueueLedgerSnapshot } from "./message-queue-ledger"

export type QueueMigrationIssue = { scopeKey: string; queueItemID: string; path: string; reason: string }
export type QueueMigrationCleanupError = { scopeKey: string; queueItemID: string; path: string; reason: string }
export type QueueMigrationResult =
  | { status: "committed" | "degraded"; snapshot: QueueLedgerSnapshotV4; issues: QueueMigrationIssue[]; cleanupErrors: QueueMigrationCleanupError[] }
  | { status: "recovery-required"; issues: QueueMigrationIssue[]; cleanupErrors: QueueMigrationCleanupError[] }
  | { status: "failed"; error: { code: QueueLedgerMetadataErrorCode }; issues: QueueMigrationIssue[]; cleanupErrors: QueueMigrationCleanupError[] }

const MAX_STRING = QUEUE_LEDGER_LIMITS.string, MAX_DATA_URL = QUEUE_LEDGER_LIMITS.dataURL, MAX_BYTES = QUEUE_LEDGER_LIMITS.bytes
const plain = (value: unknown): value is Record<string, unknown> => value !== null && typeof value === "object" && !Array.isArray(value)
const text = (value: unknown, fallback: string, allowEmpty = false): string => typeof value === "string" && value.length <= MAX_STRING && (allowEmpty || value.length > 0) ? value : fallback
const integer = (value: unknown, fallback = 0): number => typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : fallback
const sameScope = (left: QueueLedgerScope, right: QueueLedgerScope): boolean => queueLedgerScopeKey(left) === queueLedgerScopeKey(right)
const migrationIssue = (scopeKey: string, queueItemID: string, path: string, reason: string): QueueMigrationIssue => ({ scopeKey, queueItemID, path, reason })
const legacyID = async (prefix: string, seed: string): Promise<string> => {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(seed))
  return `${prefix}-${[...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("")}`
}
const validID = (value: unknown): value is string => typeof value === "string" && value.length > 0 && value.length <= MAX_STRING
const physicalScope = (key: string): QueueLedgerScope | undefined => parseQueueLedgerScopeKey(key) ?? (validID(key) ? { state: "unbound-legacy", sessionID: key } : undefined)
const rowOwner = (value: unknown): QueueLedgerScope | undefined => {
  if (!plain(value)) return undefined
  if (value.state === "bound" && validID(value.transportIdentity) && validID(value.directory) && validID(value.sessionID)) return { state: "bound", transportIdentity: value.transportIdentity, directory: value.directory, sessionID: value.sessionID }
  if (value.state === "unbound-legacy" && validID(value.sessionID)) return { state: "unbound-legacy", sessionID: value.sessionID }
  return undefined
}
const decodeDataURL = (value: string): Blob | undefined => {
  if (value.length > MAX_DATA_URL) return undefined
  const match = /^data:([^,]*),(.*)$/s.exec(value)
  if (!match) return undefined
  const parts = match[1].split(";"), base64 = parts.at(-1)?.toLowerCase() === "base64", mimeType = (base64 ? parts.slice(0, -1) : parts).join(";") || "application/octet-stream", payload = match[2]
  try {
    let bytes: Uint8Array
    if (base64) {
      if (!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(payload)) return undefined
      const decoded = atob(payload); if (decoded.length > MAX_BYTES) return undefined
      bytes = Uint8Array.from(decoded, (character) => character.charCodeAt(0))
    } else {
      bytes = new TextEncoder().encode(decodeURIComponent(payload)); if (bytes.byteLength > MAX_BYTES) return undefined
    }
    const buffer = new ArrayBuffer(bytes.byteLength); new Uint8Array(buffer).set(bytes)
    return new Blob([buffer], { type: mimeType })
  } catch { return undefined }
}
const sendConfig = (value: unknown): QueueItemDTO["sendConfig"] | undefined => plain(value) && validID(value.providerID) && validID(value.modelID) && (value.agent === undefined || validID(value.agent)) && (value.variant === undefined || validID(value.variant)) ? { providerID: value.providerID, modelID: value.modelID, ...(value.agent === undefined ? {} : { agent: value.agent }), ...(value.variant === undefined ? {} : { variant: value.variant }) } : undefined

export const migrateLegacyMessageQueue = async (sink: QueueLedgerMetadataSink, blobs: InputDraftBlobStore): Promise<QueueMigrationResult> => {
  const current = await readQueueLedgerSnapshotDetailed(sink)
  if (!current.ok) return { status: "failed", error: current.error, issues: [], cleanupErrors: [] }
  if (current.value.status === "ok") {
    const snapshot = current.value.snapshot!
    return snapshot.migration.v3State === "degraded"
      ? { status: "degraded", snapshot, issues: [migrationIssue("", "", "$.migration.v3State", "existing-degraded")], cleanupErrors: [] }
      : { status: "committed", snapshot, issues: [], cleanupErrors: [] }
  }
  if (current.value.status === "partial" || current.value.status === "corrupt") return { status: "recovery-required", issues: current.value.issues.map((entry) => migrationIssue(entry.scopeKey ?? "", entry.queueItemID ?? "", entry.path, entry.reason)), cleanupErrors: [] }
  const raw = await sink.read(LEGACY_MESSAGE_QUEUE_KEY)
  if (!raw.ok) return { status: "failed", error: raw.error, issues: [], cleanupErrors: [] }
  const issues: QueueMigrationIssue[] = [], cleanupErrors: QueueMigrationCleanupError[] = []
  const rollback: Array<{ reference: DraftAttachmentReference; blobID: string; issue: QueueMigrationIssue }> = []
  const cleanup = async (): Promise<void> => { for (const entry of rollback.reverse()) { const released = await blobs.releaseIfMatches(entry.reference, entry.blobID); if (!released.ok) cleanupErrors.push({ ...entry.issue, reason: `rollback-${released.error.code}` }) } }
  if (raw.value === null) {
    const snapshot = { ...emptyQueueLedgerSnapshot(), migration: { v3State: "complete" as const } }
    const written = await writeQueueLedgerSnapshot(sink, snapshot)
    return written.ok ? { status: "committed", snapshot, issues, cleanupErrors } : { status: "failed", error: written.error, issues, cleanupErrors }
  }
  let parsed: unknown
  try { parsed = JSON.parse(raw.value) } catch { return { status: "failed", error: { code: "corrupt" }, issues: [migrationIssue("", "", "$", "legacy-json")], cleanupErrors } }
  const queues = plain(parsed) && plain(parsed.state) ? parsed.state.queuedMessages : plain(parsed) ? parsed.queuedMessages : undefined
  if (!plain(queues)) return { status: "failed", error: { code: "corrupt" }, issues: [migrationIssue("", "", "$.state.queuedMessages", "legacy-state")], cleanupErrors }
  const snapshot: QueueLedgerSnapshotV4 = { ...emptyQueueLedgerSnapshot(), migration: { v3State: "complete" } }, queueIDs = new Set<string>(), operationIDs = new Set<string>(), messageIDs = new Set<string>()
  let totalItems = 0
  const scopeEntries = Object.entries(queues)
  for (let scopeIndex = 0; scopeIndex < scopeEntries.length; scopeIndex++) {
    const [key, values] = scopeEntries[scopeIndex]!
    if (scopeIndex >= QUEUE_LEDGER_LIMITS.scopes) { issues.push(migrationIssue(key, "", `$.state.queuedMessages.${JSON.stringify(key)}`, "legacy-scope-limit")); break }
    const owner = physicalScope(key), scopeKey = owner ? queueLedgerScopeKey(owner) : key
    if (!owner || !Array.isArray(values)) { issues.push(migrationIssue(scopeKey, "", `$.state.queuedMessages.${JSON.stringify(key)}`, "legacy-queue")); continue }
    for (let index = 0; index < values.length; index++) {
      if (totalItems >= QUEUE_LEDGER_LIMITS.totalItems) { issues.push(migrationIssue(scopeKey, "", `$.state.queuedMessages.${JSON.stringify(key)}[${index}]`, "legacy-item-limit")); break }
      totalItems++
      const path = `$.state.queuedMessages.${JSON.stringify(key)}[${index}]`, row = plain(values[index]) ? values[index] : undefined
      if (!row || typeof row.content !== "string" || row.content.length > 131072) { issues.push(migrationIssue(scopeKey, "", path, "legacy-item")); continue }
      const declared = rowOwner(row.owner)
      if (row.owner !== undefined && (!declared || !sameScope(owner, declared))) { issues.push(migrationIssue(scopeKey, validID(row.queueItemID) ? row.queueItemID : "", path, "owner-conflict")); continue }
      const seed = JSON.stringify([key, index, row.content]), queueItemID = validID(row.queueItemID) ? row.queueItemID : validID(row.id) ? row.id : await legacyID("queue", seed), operationID = validID(row.operationID) ? row.operationID : await legacyID("operation", `${seed}:operation`), messageID = validID(row.messageID) ? row.messageID : await legacyID("message", `${seed}:message`)
      if (queueIDs.has(queueItemID) || operationIDs.has(operationID) || messageIDs.has(messageID)) { issues.push(migrationIssue(scopeKey, queueItemID, path, "duplicate-id")); continue }
      queueIDs.add(queueItemID); operationIDs.add(operationID); messageIDs.add(messageID)
      const attachments: QueueAttachmentRefDTO[] = [], attachmentIssues: QueueAttachmentIssueDTO[] = [], occurrences = new Set<string>(), listed = Array.isArray(row.attachments) ? row.attachments : []
      if (row.attachments !== undefined && !Array.isArray(row.attachments)) issues.push(migrationIssue(scopeKey, queueItemID, `${path}.attachments`, "legacy-attachments"))
      for (let attachmentIndex = 0; attachmentIndex < listed.length && attachmentIndex < QUEUE_LEDGER_LIMITS.attachmentsPerItem; attachmentIndex++) {
        const candidate = plain(listed[attachmentIndex]) ? listed[attachmentIndex] : undefined, attachmentPath = `${path}.attachments[${attachmentIndex}]`
        if (!candidate) { issues.push(migrationIssue(scopeKey, queueItemID, attachmentPath, "legacy-attachment")); continue }
        const attachmentID = validID(candidate.id) ? candidate.id : await legacyID("attachment", `${seed}:attachment:${attachmentIndex}`), occurrenceRefID = draftRootAttachmentOccurrenceRefID(attachmentID), filename = text(candidate.filename, attachmentID), mimeType = text(candidate.mimeType, "", true), size = integer(candidate.size)
        if (occurrences.has(occurrenceRefID)) { issues.push(migrationIssue(scopeKey, queueItemID, attachmentPath, "duplicate-attachment-occurrence")); continue }
        occurrences.add(occurrenceRefID)
        const sourceValid = candidate.source === "local" ? candidate.serverPath === undefined && candidate.vscodePath === undefined && candidate.vscodeSource === undefined : candidate.source === "server" ? validID(candidate.serverPath) && candidate.vscodePath === undefined && candidate.vscodeSource === undefined : candidate.source === "vscode" ? validID(candidate.vscodePath) && (candidate.vscodeSource === "file" || candidate.vscodeSource === "selection") && candidate.serverPath === undefined : false
        const source: QueueAttachmentRefDTO["source"] = sourceValid ? candidate.source : "local"
        const serverPath = source === "server" ? candidate.serverPath as string : undefined, vscodePath = source === "vscode" ? candidate.vscodePath as string : undefined, vscodeSource = source === "vscode" ? candidate.vscodeSource as "file" | "selection" : undefined
        const metadata: Omit<QueueAttachmentRefDTO, "version" | "locator"> = { attachmentID, occurrenceRefID, filename, mimeType, size, source, ...(serverPath ? { serverPath } : {}), ...(vscodePath ? { vscodePath } : {}), ...(vscodeSource ? { vscodeSource } : {}) }
        const addIssue = (reason: QueueAttachmentIssueDTO["reason"]): void => { attachmentIssues.push({ ...metadata, reason }); issues.push(migrationIssue(scopeKey, queueItemID, attachmentPath, reason)) }
        if (!sourceValid) { issues.push(migrationIssue(scopeKey, queueItemID, attachmentPath, candidate.source === "server" ? "server-metadata" : candidate.source === "vscode" ? "vscode-metadata" : "attachment-source")); addIssue("legacy-bytes-missing"); continue }
        const dataUrl = typeof candidate.dataUrl === "string" ? candidate.dataUrl : ""
        if (isDurableURL(dataUrl)) { attachments.push({ version: 1, ...metadata, locator: { kind: "url", url: dataUrl } }); continue }
        if (dataUrl.startsWith("blob:")) { addIssue("legacy-blob-url"); continue }
        if (!dataUrl.startsWith("data:")) { addIssue("legacy-bytes-missing"); continue }
        if (owner.state === "unbound-legacy") { addIssue("legacy-unbound-data"); continue }
        const blob = decodeDataURL(dataUrl)
        if (!blob) { addIssue("legacy-bytes-missing"); continue }
        const blobID = await legacyID("legacy-blob", `${queueItemID}:${attachmentID}`), reference = { transportIdentity: owner.transportIdentity, owner: { kind: "queue" as const, ownerID: queueItemID }, attachmentOccurrenceRefID: occurrenceRefID }, existing = await blobs.readReference(reference)
        if (!existing.ok || existing.value !== undefined && existing.value !== blobID) { await cleanup(); return { status: "failed", error: { code: "unavailable" }, issues, cleanupErrors } }
        const retained = await blobs.putAndRetain(reference, blobID, blob)
        if (!retained.ok) { await cleanup(); return { status: "failed", error: { code: "unavailable" }, issues, cleanupErrors } }
        if (existing.value === undefined) rollback.push({ reference, blobID, issue: migrationIssue(scopeKey, queueItemID, attachmentPath, "blob-retain") })
        attachments.push({ version: 1, ...metadata, mimeType: blob.type, size: blob.size, locator: { kind: "blob", blobID } })
      }
      if (listed.length > QUEUE_LEDGER_LIMITS.attachmentsPerItem) issues.push(migrationIssue(scopeKey, queueItemID, `${path}.attachments`, "legacy-attachment-limit"))
      const createdAt = integer(row.createdAt), requested = typeof row.status === "string" ? row.status : "queued", failureValue = plain(row.failure) ? row.failure.kind : row.failureKind, failureKind = failureValue === "pre-dispatch" || failureValue === "ambiguous-dispatch" || failureValue === "definitive" ? failureValue : undefined, retrying = requested === "retrying" || failureKind === "pre-dispatch", reconciling = requested === "sending" || requested === "reconciling" || failureKind === "ambiguous-dispatch", ambiguousUnresolved = requested === "unresolved" && attachmentIssues.length === 0, terminalAttachment = attachmentIssues.length > 0, started = integer(row.reconciliationStartedAt, createdAt), providedDeadline = integer(row.reconciliationDeadlineAt, -1), deadlineFallback = started > Number.MAX_SAFE_INTEGER - 30_000 ? started : started + 30_000, deadline = Math.max(started, providedDeadline >= 0 ? providedDeadline : deadlineFallback), checks = integer(row.reconciliationChecks), nextCheck = integer(row.reconciliationNextCheckAt, started)
      if (reconciling && providedDeadline < 0 && started > Number.MAX_SAFE_INTEGER - 30_000) issues.push(migrationIssue(scopeKey, queueItemID, `${path}.reconciliationDeadlineAt`, "reconciliation-deadline-overflow"))
      const status: QueueItemDTO["status"] = terminalAttachment ? "unresolved" : ambiguousUnresolved || (owner.state === "unbound-legacy" && reconciling) ? "unresolved" : retrying ? "retrying" : reconciling ? "reconciling" : requested === "failed" || failureKind === "definitive" ? "failed" : "queued"
      const needsReconciliation = status === "reconciling" || (status === "unresolved" && !terminalAttachment)
      const item: QueueItemDTO = { version: 1, queueItemID, operationID, messageID, owner, content: row.content, attachments, attachmentIssues, createdAt, ...(sendConfig(row.sendConfig) ? { sendConfig: sendConfig(row.sendConfig) } : {}), status, attemptCount: integer(row.attemptCount), ...(status === "retrying" ? { nextAttemptAt: integer(row.nextAttemptAt, createdAt), failureKind: "pre-dispatch" as const } : needsReconciliation ? { reconciliationStartedAt: started, reconciliationDeadlineAt: deadline, reconciliationChecks: checks, reconciliationNextCheckAt: nextCheck, failureKind: "ambiguous-dispatch" as const } : status === "failed" ? { failureKind: "definitive" as const } : {}) }
      ;(snapshot.queues[scopeKey] ??= []).push(item)
    }
  }
  if (issues.length) snapshot.migration.v3State = "degraded"
  const written = await writeQueueLedgerSnapshot(sink, snapshot)
  if (!written.ok) { await cleanup(); return { status: "failed", error: written.error, issues, cleanupErrors } }
  if (snapshot.migration.v3State === "complete") { const removed = await sink.remove(LEGACY_MESSAGE_QUEUE_KEY); if (!removed.ok) cleanupErrors.push({ scopeKey: "", queueItemID: "", path: "$", reason: `legacy-remove-${removed.error.code}` }) }
  return { status: snapshot.migration.v3State === "complete" ? "committed" : "degraded", snapshot, issues, cleanupErrors }
}
