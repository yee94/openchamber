/**
 * App-wide single-flight coordinator for OpenCode session message pages.
 *
 * Session selection can start an imperative fetch before React commits while
 * the reactive sync hook requests the same page immediately afterwards.  Keep
 * the coordinator transport-agnostic so both paths share the exact promise.
 */

type LoadSessionMessagePageInput<T> = {
  runtimeKey: string
  directory: string
  sessionID: string
  limit: number
  before?: string
  request: () => Promise<T>
}

type LoadSessionMessageInput<T> = {
  runtimeKey: string
  directory: string
  sessionID: string
  messageID: string
  request: () => Promise<T>
}

export type SessionMessageRecord<TInfo extends { id: string; parentID?: string | null } = { id: string; parentID?: string | null }> = {
  info: TInfo
  parts?: unknown[]
}

export const MAX_ASSISTANT_TAIL_PARENT_LOADS = 8

const inflight = new Map<string, Promise<unknown>>()

const pageKey = (input: Pick<LoadSessionMessagePageInput<unknown>, "runtimeKey" | "directory" | "sessionID" | "limit" | "before">) =>
  `page\n${input.runtimeKey}\n${input.directory}\n${input.sessionID}\n${input.limit}\n${input.before ?? "tail"}`

const messageKey = (input: Pick<LoadSessionMessageInput<unknown>, "runtimeKey" | "directory" | "sessionID" | "messageID">) =>
  `message\n${input.runtimeKey}\n${input.directory}\n${input.sessionID}\n${input.messageID}`

function singleFlight<T>(key: string, request: () => Promise<T>): Promise<T> {
  const existing = inflight.get(key)
  if (existing) return existing as Promise<T>

  const pending = request()
  inflight.set(key, pending)
  void pending.finally(() => {
    if (inflight.get(key) === pending) inflight.delete(key)
  }).catch(() => {})
  return pending
}

export function loadSessionMessagePage<T>(input: LoadSessionMessagePageInput<T>): Promise<T> {
  return singleFlight(pageKey(input), input.request)
}

/** Shares exact parent-message requests across imperative and reactive loads. */
export function loadSessionMessage<T>(input: LoadSessionMessageInput<T>): Promise<T> {
  return singleFlight(messageKey(input), input.request)
}

function isRole(record: SessionMessageRecord, role: string): boolean {
  const info = record.info as typeof record.info & { role?: unknown; clientRole?: unknown }
  return info.role === role || info.clientRole === role
}

export function findMissingAssistantParentUserIDs(records: SessionMessageRecord[]): string[] {
  if (records.some((record) => isRole(record, "user"))) return []
  const present = new Set(records.map((record) => record.info.id))
  const parentIDs: string[] = []
  const seen = new Set<string>()
  for (const record of records) {
    if (!isRole(record, "assistant")) continue
    const parentID = record.info.parentID
    if (!parentID || present.has(parentID) || seen.has(parentID)) continue
    seen.add(parentID)
    parentIDs.push(parentID)
    if (parentIDs.length === MAX_ASSISTANT_TAIL_PARENT_LOADS) break
  }
  return parentIDs
}

export async function recoverAssistantTailBoundary<T extends SessionMessageRecord>(input: {
  records: T[]
  complete: boolean
  requestMessage: (messageID: string) => Promise<T>
}): Promise<{ records: T[]; boundaryFound: boolean; partial: boolean }> {
  const initialBoundaryFound = input.records.some((record) => isRole(record, "user"))
  if (initialBoundaryFound || input.complete) {
    return { records: input.records, boundaryFound: initialBoundaryFound, partial: false }
  }

  const parentIDs = findMissingAssistantParentUserIDs(input.records)
  if (parentIDs.length === 0) {
    return { records: input.records, boundaryFound: false, partial: true }
  }

  const parents = await Promise.all(parentIDs.map(input.requestMessage))
  const byID = new Map<string, T>()
  for (const record of [...input.records, ...parents]) byID.set(record.info.id, record)
  const records = [...byID.values()].sort((a, b) => a.info.id.localeCompare(b.info.id))
  const boundaryFound = records.some((record) => isRole(record, "user"))
  return { records, boundaryFound, partial: !boundaryFound }
}
