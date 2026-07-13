import type { SessionFolder } from '@/stores/useSessionFoldersStore';

type SessionNodeLike = { session: { id: string } };

type Args = {
  folders: Array<{ folder: SessionFolder; nodes: SessionNodeLike[] }>;
  visibleUngroupedNodes: SessionNodeLike[];
  collapsedFolderIds: ReadonlySet<string>;
  hasSessionSearchQuery: boolean;
};

export type VisibleSortableSessionOrder = {
  sessionIds: string[];
  folderIdBySessionId: Map<string, string | null>;
};

/** Mirrors the folder-first DOM order used by SessionGroupSection. */
export const buildVisibleSortableSessionOrder = ({
  folders,
  visibleUngroupedNodes,
  collapsedFolderIds,
  hasSessionSearchQuery,
}: Args): VisibleSortableSessionOrder => {
  const folderById = new Map(folders.map((entry) => [entry.folder.id, entry]));
  const childrenByParentId = new Map<string | null, string[]>();
  folders.forEach(({ folder }) => {
    const parentId = folder.parentId ?? null;
    const children = childrenByParentId.get(parentId) ?? [];
    children.push(folder.id);
    childrenByParentId.set(parentId, children);
  });

  const sessionIds: string[] = [];
  const folderIdBySessionId = new Map<string, string | null>();
  const appendFolder = (folderId: string): void => {
    const entry = folderById.get(folderId);
    if (!entry) return;
    if (!hasSessionSearchQuery && collapsedFolderIds.has(folderId)) return;
    (childrenByParentId.get(folderId) ?? []).forEach(appendFolder);
    entry.nodes.forEach((node) => {
      sessionIds.push(node.session.id);
      folderIdBySessionId.set(node.session.id, folderId);
    });
  };

  (childrenByParentId.get(null) ?? []).forEach(appendFolder);
  visibleUngroupedNodes.forEach((node) => {
    sessionIds.push(node.session.id);
    folderIdBySessionId.set(node.session.id, null);
  });
  return { sessionIds, folderIdBySessionId };
};

export const canReorderVisibleSessions = (
  activeSessionId: string,
  overSessionId: string,
  folderIdBySessionId: ReadonlyMap<string, string | null>,
): boolean => folderIdBySessionId.get(activeSessionId) === folderIdBySessionId.get(overSessionId);
