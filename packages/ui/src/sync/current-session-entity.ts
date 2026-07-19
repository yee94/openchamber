export const CURRENT_SESSION_ENTITY_CACHE_TTL_MS = 2_000

type CurrentSessionEntity = {
  id: string
}

type ParentSessionEntity = CurrentSessionEntity & {
  parentID?: string | null
  directory?: string | null
}

export type ParentSessionTarget<T extends ParentSessionEntity> = {
  id: string
  directory: string | null
  session: T | null
}

export function resolveCurrentSessionEntity<T extends CurrentSessionEntity>(
  sessionID: string | null | undefined,
  liveSession: T | null | undefined,
  globalActiveSession: T | null | undefined,
): T | null {
  if (!sessionID) return null
  const matchingLiveSession = liveSession?.id === sessionID ? liveSession : null
  const matchingGlobalActiveSession = globalActiveSession?.id === sessionID ? globalActiveSession : null
  return matchingLiveSession ?? matchingGlobalActiveSession
}

export function resolveParentSessionTarget<T extends ParentSessionEntity>(
  sessionID: string | null | undefined,
  currentSession: T | null | undefined,
  parentSession: T | null | undefined,
  fallbackDirectory: string | null | undefined,
): ParentSessionTarget<T> | null {
  if (!currentSession || currentSession.id !== sessionID || !currentSession.parentID) return null

  const parentID = currentSession.parentID
  const matchingParent = parentSession?.id === parentID ? parentSession ?? null : null
  return {
    id: parentID,
    directory: matchingParent?.directory ?? currentSession.directory ?? fallbackDirectory ?? null,
    session: matchingParent,
  }
}
