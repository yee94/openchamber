import { describe, expect, test } from 'bun:test';
import type { Session } from '@opencode-ai/sdk/v2';

import { buildSessionNodeWithChildren, buildSessionTree } from './sessionTree';

const session = (
  id: string,
  options: { parentID?: string | null; created?: number; archived?: number } = {},
): Session =>
  ({
    id,
    title: id,
    time: {
      created: options.created ?? 1,
      ...(options.archived ? { archived: options.archived } : {}),
    },
    ...(options.parentID ? { parentID: options.parentID } : {}),
  }) as Session;

describe('buildSessionTree', () => {
  test('attaches children before omitting pinned roots from the project forest', () => {
    const parent = session('parent', { created: 20 });
    const child = session('child', { parentID: 'parent', created: 30 });
    const sibling = session('sibling', { created: 10 });

    const forest = buildSessionTree([parent, child, sibling], {
      pinnedSessionIds: new Set(['parent']),
      omitPinnedSessions: true,
    });

    expect(forest.map((node) => node.session.id)).toEqual(['sibling']);
    expect(forest[0]?.children).toEqual([]);
  });

  test('does not promote children of pinned parents into project roots', () => {
    const parent = session('parent');
    const child = session('child', { parentID: 'parent' });

    const forest = buildSessionTree([parent, child], {
      pinnedSessionIds: new Set(['parent']),
      omitPinnedSessions: true,
    });

    expect(forest).toEqual([]);
  });

  test('keeps unpinned parent/child trees intact', () => {
    const parent = session('parent');
    const child = session('child', { parentID: 'parent' });

    const forest = buildSessionTree([parent, child], {
      pinnedSessionIds: new Set(),
      omitPinnedSessions: true,
    });

    expect(forest).toHaveLength(1);
    expect(forest[0]?.session.id).toBe('parent');
    expect(forest[0]?.children.map((node) => node.session.id)).toEqual(['child']);
  });
});

describe('buildSessionNodeWithChildren', () => {
  test('builds the full subagent tree for a pinned parent', () => {
    const parent = session('parent');
    const child = session('child', { parentID: 'parent', created: 2 });
    const grand = session('grand', { parentID: 'child', created: 3 });

    const node = buildSessionNodeWithChildren(parent, [parent, child, grand]);

    expect(node.session.id).toBe('parent');
    expect(node.children).toHaveLength(1);
    expect(node.children[0]?.session.id).toBe('child');
    expect(node.children[0]?.children.map((item) => item.session.id)).toEqual(['grand']);
  });

  test('includes newly created subagents of a pinned parent', () => {
    const parent = session('parent');
    const existing = session('child-a', { parentID: 'parent', created: 2 });
    const created = session('child-b', { parentID: 'parent', created: 3 });

    const node = buildSessionNodeWithChildren(parent, [parent, existing, created], {
      pinnedSessionIds: new Set(['parent']),
    });

    expect(node.children.map((item) => item.session.id)).toEqual(['child-b', 'child-a']);
  });
});
