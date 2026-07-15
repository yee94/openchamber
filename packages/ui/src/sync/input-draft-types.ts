export type DraftOwner =
  | { kind: "session"; ownerID: string }
  | { kind: "draft"; ownerID: string }

export type DraftAttachmentOwner = DraftOwner
  | { kind: "queue"; ownerID: string }
  | { kind: "send"; ownerID: string }

export type DraftKey = {
  transportIdentity: string
  owner: DraftOwner
}

export type DraftAttachmentReference = {
  transportIdentity: string
  owner: DraftAttachmentOwner
  attachmentOccurrenceRefID: string
}

const MAX_DURABLE_URL_LENGTH = 8_192

export const isDurableURL = (value: unknown): value is string => {
  if (typeof value !== "string" || value.length === 0 || value.length > MAX_DURABLE_URL_LENGTH) return false
  try {
    const protocol = new URL(value).protocol
    return protocol === "http:" || protocol === "https:" || protocol === "file:"
  } catch {
    return false
  }
}

export const draftKeyString = (key: DraftKey): string => JSON.stringify([
  key.transportIdentity,
  key.owner.kind,
  key.owner.ownerID,
])

export const draftAttachmentRefID = (reference: DraftAttachmentReference): string => JSON.stringify([
  reference.transportIdentity,
  reference.owner.kind,
  reference.owner.ownerID,
  reference.attachmentOccurrenceRefID,
])

export const draftRootAttachmentOccurrenceRefID = (attachmentRefID: string): string => JSON.stringify(["root", attachmentRefID])

export const draftSyntheticPartAttachmentOccurrenceRefID = (partID: string, attachmentRefID: string): string => JSON.stringify(["part", partID, attachmentRefID])

export type DraftAttachmentLocator =
  | { kind: "blob"; blobID: string }
  | { kind: "url"; url: string }

export type DraftAttachmentMetadata = {
  attachmentID: string
  attachmentRefID: string
  filename: string
  mimeType: string
  size: number
  locator: DraftAttachmentLocator
  source: "local" | "vscode" | "server"
  serverPath?: string
  vscodePath?: string
  vscodeSource?: "file" | "selection"
}

export type DraftSyntheticPart = {
  partID: string
  text: string
  attachments: DraftAttachmentMetadata[]
  synthetic?: boolean
}

export type DraftMention = {
  kind: "file" | "agent"
  value: string
  path: string
  label: string
  range: { start: number; end: number }
}

export type DraftRecord = {
  version: 1
  key: DraftKey
  revision: number
  text: string
  attachments: DraftAttachmentMetadata[]
  syntheticParts: DraftSyntheticPart[]
  mentions: DraftMention[]
}

const isPlainObject = (value: unknown): value is Record<string, unknown> => {
  if (value === null || typeof value !== "object") return false
  const prototype = Object.getPrototypeOf(value)
  return prototype === Object.prototype || prototype === null
}

const hasOnlyKeys = (value: Record<string, unknown>, keys: readonly string[]): boolean => Object.keys(value).every((key) => keys.includes(key))

const isString = (value: unknown): value is string => typeof value === "string" && value.length > 0
const isStringValue = (value: unknown): value is string => typeof value === "string"
const isNonNegativeInteger = (value: unknown): value is number => typeof value === "number" && Number.isSafeInteger(value) && value >= 0

const isSafeValue = (value: unknown, seen: Set<object>): boolean => {
  if (value === null || ["string", "number", "boolean", "undefined"].includes(typeof value)) return true
  if (typeof value !== "object" || value instanceof Blob || (typeof File !== "undefined" && value instanceof File) || (!Array.isArray(value) && !isPlainObject(value))) return false
  if (seen.has(value)) return false
  seen.add(value)
  const safe = Object.values(value).every((child) => isSafeValue(child, seen))
  seen.delete(value)
  return safe
}

const parseOwner = (value: unknown): DraftOwner | undefined => {
  if (!isPlainObject(value) || !hasOnlyKeys(value, ["kind", "ownerID"]) || !isString(value.ownerID)) return undefined
  if (value.kind === "session" || value.kind === "draft") return { kind: value.kind, ownerID: value.ownerID }
  return undefined
}

const parseKey = (value: unknown): DraftKey | undefined => {
  if (!isPlainObject(value) || !hasOnlyKeys(value, ["transportIdentity", "owner"]) || !isString(value.transportIdentity)) return undefined
  const owner = parseOwner(value.owner)
  return owner ? { transportIdentity: value.transportIdentity, owner } : undefined
}

const parseLocator = (value: unknown): DraftAttachmentLocator | undefined => {
  if (!isPlainObject(value) || !isString(value.kind)) return undefined
  if (value.kind === "blob" && hasOnlyKeys(value, ["kind", "blobID"]) && isString(value.blobID)) return { kind: "blob", blobID: value.blobID }
  if (value.kind !== "url" || !hasOnlyKeys(value, ["kind", "url"]) || !isDurableURL(value.url)) return undefined
  return { kind: "url", url: value.url }
}

const hasExpectedAttachmentOccurrence = (value: string, attachmentID: string, partID?: string): boolean => {
  try {
    const parsed: unknown = JSON.parse(value)
    if (!Array.isArray(parsed)) return false
    if (partID === undefined) return parsed.length === 2 && parsed[0] === "root" && parsed[1] === attachmentID
    return parsed.length === 3 && parsed[0] === "part" && parsed[1] === partID && parsed[2] === attachmentID
  } catch {
    return false
  }
}

const parseAttachment = (value: unknown, partID?: string): DraftAttachmentMetadata | undefined => {
  if (!isPlainObject(value) || !hasOnlyKeys(value, ["attachmentID", "attachmentRefID", "filename", "mimeType", "size", "locator", "source", "serverPath", "vscodePath", "vscodeSource"])) return undefined
  if (!isString(value.attachmentID) || !isString(value.attachmentRefID) || !hasExpectedAttachmentOccurrence(value.attachmentRefID, value.attachmentID, partID) || !isString(value.filename) || !isStringValue(value.mimeType) || !isNonNegativeInteger(value.size)) return undefined
  if (value.source !== "local" && value.source !== "vscode" && value.source !== "server") return undefined
  if ((value.serverPath !== undefined && !isString(value.serverPath)) || (value.vscodePath !== undefined && !isString(value.vscodePath)) || (value.vscodeSource !== undefined && value.vscodeSource !== "file" && value.vscodeSource !== "selection")) return undefined
  if (value.source === "server" && !isString(value.serverPath)) return undefined
  if (value.source === "vscode" && (!isString(value.vscodePath) || (value.vscodeSource !== "file" && value.vscodeSource !== "selection"))) return undefined
  const locator = parseLocator(value.locator)
  if (!locator) return undefined
  return { attachmentID: value.attachmentID, attachmentRefID: value.attachmentRefID, filename: value.filename, mimeType: value.mimeType, size: value.size, locator, source: value.source, ...(value.serverPath === undefined ? {} : { serverPath: value.serverPath }), ...(value.vscodePath === undefined ? {} : { vscodePath: value.vscodePath }), ...(value.vscodeSource === undefined ? {} : { vscodeSource: value.vscodeSource }) }
}

const parseMention = (value: unknown, text: string): DraftMention | undefined => {
  if (!isPlainObject(value) || !hasOnlyKeys(value, ["kind", "value", "path", "label", "range"]) || (value.kind !== "file" && value.kind !== "agent") || !isString(value.value) || !isString(value.path) || !isString(value.label) || !isPlainObject(value.range) || !hasOnlyKeys(value.range, ["start", "end"]) || !isNonNegativeInteger(value.range.start) || !isNonNegativeInteger(value.range.end) || value.range.start >= value.range.end || value.range.end > text.length) return undefined
  return { kind: value.kind, value: value.value, path: value.path, label: value.label, range: { start: value.range.start, end: value.range.end } }
}

export const parseDraftRecord = (value: unknown): DraftRecord | undefined => {
  if (!isSafeValue(value, new Set()) || !isPlainObject(value) || !hasOnlyKeys(value, ["version", "key", "revision", "text", "attachments", "syntheticParts", "mentions"]) || value.version !== 1 || !isNonNegativeInteger(value.revision) || value.revision < 1 || typeof value.text !== "string" || !Array.isArray(value.attachments) || !Array.isArray(value.syntheticParts) || !Array.isArray(value.mentions)) return undefined
  const text = value.text
  const key = parseKey(value.key)
  const attachments = value.attachments.map((attachment) => parseAttachment(attachment))
  const syntheticParts = value.syntheticParts.map((part) => {
    if (!isPlainObject(part) || !hasOnlyKeys(part, ["partID", "text", "attachments", "synthetic"]) || !isString(part.partID) || typeof part.text !== "string" || !Array.isArray(part.attachments) || (part.synthetic !== undefined && typeof part.synthetic !== "boolean")) return undefined
    const partID = part.partID
    const partText = part.text
    const partAttachments = part.attachments.map((attachment) => parseAttachment(attachment, partID))
    return partAttachments.every(Boolean) ? { partID, text: partText, attachments: partAttachments as DraftAttachmentMetadata[], ...(part.synthetic === undefined ? {} : { synthetic: part.synthetic }) } : undefined
  })
  const mentions = value.mentions.map((mention) => parseMention(mention, text))
  if (!key || !attachments.every(Boolean) || !syntheticParts.every(Boolean) || !mentions.every(Boolean)) return undefined
  const parsedAttachments = attachments as DraftAttachmentMetadata[]
  const parsedParts = syntheticParts as DraftSyntheticPart[]
  const attachmentRefIDs = new Set<string>()
  for (const attachment of [...parsedAttachments, ...parsedParts.flatMap((part) => part.attachments)]) {
    if (attachmentRefIDs.has(attachment.attachmentRefID)) return undefined
    attachmentRefIDs.add(attachment.attachmentRefID)
  }
  if (new Set(parsedParts.map((part) => part.partID)).size !== parsedParts.length) return undefined
  return { version: 1, key, revision: value.revision, text, attachments: parsedAttachments, syntheticParts: parsedParts, mentions: mentions as DraftMention[] }
}

export const cloneDraftRecord = (record: DraftRecord): DraftRecord | undefined => parseDraftRecord(record)

export const isDraftRecordPersistable = (record: unknown): record is DraftRecord => parseDraftRecord(record) !== undefined
