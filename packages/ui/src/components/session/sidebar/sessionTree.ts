import type { Session } from '@opencode-ai/sdk/v2';
import type { WorktreeMetadata } from '@/types/worktree';
import type { SessionNode } from './types';
import { compareSessionsByPinnedAndTime, dedupeSessionsById } from './utils';

const isArchivedSession = (session: Session): boolean => Boolean(session.time?.archived);

const getParentID = (session: Session): string | null => {
  const parentID = (session as Session & { parentID?: string | null }).parentID;
  return typeof parentID === 'string' && parentID.trim() ? parentID : null;
};

export type BuildSessionTreeOptions = {
  pinnedSessionIds?: Set<string>;
  /**
   * When true, omit pinned sessions from the returned forest (project area).
   * Tree structure is still built with pinned parents present so children attach.
   */
  omitPinnedSessions?: boolean;
  getWorktree?: (session: Session) => WorktreeMetadata | null;
};

/**
 * Build a parent/child session forest.
 *
 * Pinned filtering happens after attachment. Project callers omit pinned roots
 * from the visible forest; children of those roots stay hidden only while the
 * parent is pinned (flat pin rows). Unpinning rebuilds the normal parent/child tree.
 */
export const buildSessionTree = (
  sessions: Session[],
  options: BuildSessionTreeOptions = {},
): SessionNode[] => {
  const pinnedSessionIds = options.pinnedSessionIds ?? new Set<string>();
  const omitPinnedSessions = options.omitPinnedSessions === true;
  const getWorktree = options.getWorktree ?? (() => null);

  const sortedSessions = dedupeSessionsById(sessions)
    .sort((a, b) => compareSessionsByPinnedAndTime(a, b, pinnedSessionIds));

  const sessionMap = new Map(sortedSessions.map((session) => [session.id, session]));
  const childrenMap = new Map<string, Session[]>();

  sortedSessions.forEach((session) => {
    const parentID = getParentID(session);
    if (!parentID) return;
    const parentSession = sessionMap.get(parentID);
    if (!parentSession || isArchivedSession(parentSession) !== isArchivedSession(session)) {
      return;
    }
    const collection = childrenMap.get(parentID) ?? [];
    collection.push(session);
    childrenMap.set(parentID, collection);
  });
  childrenMap.forEach((list) => list.sort((a, b) => compareSessionsByPinnedAndTime(a, b, pinnedSessionIds)));

  const buildNode = (session: Session): SessionNode => {
    const children = (childrenMap.get(session.id) ?? [])
      .filter((child) => !(omitPinnedSessions && pinnedSessionIds.has(child.id)))
      .map((child) => buildNode(child));
    return {
      session,
      children,
      worktree: getWorktree(session),
    };
  };

  const roots = sortedSessions.filter((session) => {
    if (omitPinnedSessions && pinnedSessionIds.has(session.id)) {
      return false;
    }
    const parentID = getParentID(session);
    if (!parentID) return true;
    const parentSession = sessionMap.get(parentID);
    if (!parentSession) return true;
    // Parent is pinned and omitted from the project forest; pinned rows stay flat
    // and do not render nested subagents. Keep those children hidden entirely.
    if (omitPinnedSessions && pinnedSessionIds.has(parentID)) {
      return false;
    }
    return isArchivedSession(parentSession) !== isArchivedSession(session);
  });

  return roots.map((session) => buildNode(session));
};
