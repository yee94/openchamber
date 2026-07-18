export const CURRENT_SESSION_ENTITY_CACHE_TTL_MS = 2_000

type CurrentSessionEntity = {
  id: string
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
