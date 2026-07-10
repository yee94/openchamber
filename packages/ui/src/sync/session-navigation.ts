import type { Session } from '@opencode-ai/sdk/v2';

import {
  compareSessionsByPinnedAndTime,
  isSessionRelatedToProject,
  normalizePath,
} from '@/components/session/sidebar/utils';
import { useSessionPinnedStore } from '@/stores/useSessionPinnedStore';
import { resolveGlobalSessionDirectory, useGlobalSessionsStore } from '@/stores/useGlobalSessionsStore';
import { useProjectsStore } from '@/stores/useProjectsStore';

import { getAllSyncSessions, getSyncSessions } from './sync-refs';

type SessionWithParent = Session & { parentID?: string | null };

export const isSubtaskSession = (session: Session): boolean => {
  return Boolean((session as SessionWithParent).parentID);
};

export const resolveRootSessionId = (sessionId: string | null, sessions: Session[]): string | null => {
  if (!sessionId) {
    return null;
  }

  const byId = new Map(sessions.map((session) => [session.id, session]));
  let current = byId.get(sessionId);
  if (!current) {
    return sessionId;
  }

  while (current && isSubtaskSession(current)) {
    const parentID = (current as SessionWithParent).parentID;
    if (!parentID) {
      break;
    }
    const parent = byId.get(parentID);
    if (!parent) {
      return parentID;
    }
    current = parent;
  }

  return current?.id ?? sessionId;
};

/**
 * Build the next/prev session list from the sidebar project tree order.
 *
 * Intentionally ignores the top "Recent" activity section — that list is a
 * recency mirror of the same sessions and must not define switch order.
 * Walk projects in store order, then root (non-archived, non-subtask)
 * sessions under each project with the same pinned+time sort the sidebar uses.
 */
export const getNavigableRootSessions = (): Session[] => {
  const pinnedSessionIds = useSessionPinnedStore.getState().ids;
  const projects = useProjectsStore.getState().projects;

  // Prefer the global active list (matches the multi-project sidebar). Fall
  // back to sync child stores when global bootstrap has not landed yet.
  const globalActive = useGlobalSessionsStore.getState().activeSessions;
  const allSessions = globalActive.length > 0 ? globalActive : getAllSyncSessions();

  const seen = new Set<string>();
  const ordered: Session[] = [];

  const appendMatching = (candidates: Session[]) => {
    for (const session of candidates) {
      if (seen.has(session.id)) {
        continue;
      }
      seen.add(session.id);
      ordered.push(session);
    }
  };

  for (const project of projects) {
    const projectRoot = normalizePath(project.path);
    if (!projectRoot) {
      continue;
    }

    // Path-prefix matching covers project root + nested worktrees without
    // reading session-ui-store (avoids a circular import with setSessionOpener).
    const projectSessions = allSessions
      .filter((session) => !session.time?.archived)
      .filter((session) => !isSubtaskSession(session))
      .filter((session) => isSessionRelatedToProject(session, projectRoot))
      .sort((a, b) => compareSessionsByPinnedAndTime(a, b, pinnedSessionIds));

    appendMatching(projectSessions);
  }

  // Sessions that are not under any registered project stay reachable, but
  // trail the project tree so they never insert themselves ahead via Recent-
  // style global recency.
  const orphanSessions = allSessions
    .filter((session) => !session.time?.archived)
    .filter((session) => !isSubtaskSession(session))
    .filter((session) => !seen.has(session.id))
    .sort((a, b) => compareSessionsByPinnedAndTime(a, b, pinnedSessionIds));

  appendMatching(orphanSessions);

  return ordered;
};

export const resolveAdjacentRootSession = (
  direction: -1 | 1,
  currentSessionId: string | null,
): Session | null => {
  const globalActive = useGlobalSessionsStore.getState().activeSessions;
  const syncAll = getAllSyncSessions();
  const allSessions = globalActive.length > 0
    ? globalActive
    : (syncAll.length > 0 ? syncAll : getSyncSessions());
  const navigableSessions = getNavigableRootSessions();
  if (navigableSessions.length === 0) {
    return null;
  }

  const rootSessionId = resolveRootSessionId(currentSessionId, allSessions);
  const currentIndex = rootSessionId
    ? navigableSessions.findIndex((session) => session.id === rootSessionId)
    : -1;

  let nextIndex = direction > 0 ? 0 : navigableSessions.length - 1;
  if (currentIndex >= 0) {
    nextIndex = (currentIndex + direction + navigableSessions.length) % navigableSessions.length;
  }

  return navigableSessions[nextIndex] ?? null;
};

export const resolveAdjacentRootSessionDirectory = (session: Session): string | null => {
  return resolveGlobalSessionDirectory(session);
};
