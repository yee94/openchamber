import { describe, expect, test } from 'bun:test';
import type { SessionFolder } from '@/stores/useSessionFoldersStore';
import { buildVisibleSortableSessionOrder, canReorderVisibleSessions } from './sessionSortableOrder';

const folder = (id: string, parentId: string | null = null): SessionFolder => ({
  id,
  name: id,
  parentId,
  sessionIds: [],
  createdAt: 1,
});

const node = (id: string) => ({ session: { id } });

describe('buildVisibleSortableSessionOrder', () => {
  test('follows folder hierarchy, scope-local folder rank, then the visible ungrouped rows', () => {
    const result = buildVisibleSortableSessionOrder({
      folders: [
        { folder: folder('first'), nodes: [node('first-b'), node('first-a')] },
        { folder: folder('nested', 'first'), nodes: [node('nested-a')] },
        { folder: folder('second'), nodes: [node('second-a')] },
      ],
      visibleUngroupedNodes: [node('ungrouped-a')],
      collapsedFolderIds: new Set(),
      hasSessionSearchQuery: false,
    });

    expect(result.sessionIds).toEqual(['nested-a', 'first-b', 'first-a', 'second-a', 'ungrouped-a']);
  });

  test('excludes collapsed folders and rejects cross-folder reorder while retaining ungrouped reorder', () => {
    const result = buildVisibleSortableSessionOrder({
      folders: [
        { folder: folder('first'), nodes: [node('first-a')] },
        { folder: folder('second'), nodes: [node('second-a')] },
      ],
      visibleUngroupedNodes: [node('ungrouped-a'), node('ungrouped-b')],
      collapsedFolderIds: new Set(['first']),
      hasSessionSearchQuery: false,
    });

    expect(result.sessionIds).toEqual(['second-a', 'ungrouped-a', 'ungrouped-b']);
    expect(canReorderVisibleSessions('second-a', 'ungrouped-a', result.folderIdBySessionId)).toBe(false);
    expect(canReorderVisibleSessions('ungrouped-a', 'ungrouped-b', result.folderIdBySessionId)).toBe(true);
  });

  test('keeps collapsed-folder search results visible', () => {
    const result = buildVisibleSortableSessionOrder({
      folders: [{ folder: folder('first'), nodes: [node('first-a')] }],
      visibleUngroupedNodes: [],
      collapsedFolderIds: new Set(['first']),
      hasSessionSearchQuery: true,
    });

    expect(result.sessionIds).toEqual(['first-a']);
  });
});
