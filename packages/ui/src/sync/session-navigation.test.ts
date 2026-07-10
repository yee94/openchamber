import { describe, expect, test, beforeEach } from 'bun:test';
import type { Session } from '@opencode-ai/sdk/v2';

import {
  getNavigableRootSessions,
  isSubtaskSession,
  resolveAdjacentRootSession,
  resolveRootSessionId,
} from './session-navigation';
import { setSyncRefs } from './sync-refs';
import { ChildStoreManager } from './child-store';
import { INITIAL_STATE } from './types';
import { useSessionPinnedStore } from '@/stores/useSessionPinnedStore';
import { useGlobalSessionsStore } from '@/stores/useGlobalSessionsStore';
import { useProjectsStore } from '@/stores/useProjectsStore';

const makeSession = (
  id: string,
  options: {
    parentID?: string | null;
    archived?: boolean;
    updated?: number;
    directory?: string;
  } = {},
): Session =>
  ({
    id,
    parentID: options.parentID ?? null,
    directory: options.directory,
    time: {
      created: options.updated ?? 1,
      updated: options.updated ?? 1,
      archived: options.archived ? Date.now() : undefined,
    },
  }) as Session;

const bootstrapSessions = (sessions: Session[], directory = '/workspace/project') => {
  const childStores = new ChildStoreManager();
  const store = childStores.ensureChild(directory, { bootstrap: false });
  store.getState().replace({
    ...INITIAL_STATE,
    status: 'complete',
    session: sessions,
    sessionTotal: sessions.filter((session) => !session.parentID).length,
    limit: Math.max(sessions.length, INITIAL_STATE.limit),
  });
  setSyncRefs({} as never, childStores, directory);
};

describe('session-navigation', () => {
  beforeEach(() => {
    useSessionPinnedStore.setState({ ids: new Set() });
    useGlobalSessionsStore.setState({
      activeSessions: [],
      archivedSessions: [],
      sessionsByDirectory: new Map(),
      reviewTransferBySessionId: new Map(),
      hasLoaded: false,
      status: 'idle',
    });
    useProjectsStore.setState({
      projects: [],
      activeProjectId: null,
    });
  });

  test('isSubtaskSession detects child sessions', () => {
    expect(isSubtaskSession(makeSession('child', { parentID: 'parent' }))).toBe(true);
    expect(isSubtaskSession(makeSession('parent'))).toBe(false);
  });

  test('resolveRootSessionId walks up to the parent session', () => {
    const sessions = [
      makeSession('parent'),
      makeSession('child', { parentID: 'parent' }),
    ];

    expect(resolveRootSessionId('child', sessions)).toBe('parent');
    expect(resolveRootSessionId('parent', sessions)).toBe('parent');
  });

  test('getNavigableRootSessions follows project tree order, not global recent order', () => {
    useProjectsStore.setState({
      projects: [
        { id: 'p1', path: '/workspace/alpha', label: 'alpha' },
        { id: 'p2', path: '/workspace/beta', label: 'beta' },
      ] as never,
      activeProjectId: 'p1',
    });

    // Global recency would put beta-new first (updated=300), then alpha-old (200),
    // then alpha-older (100). Project-tree order must keep alpha sessions together
    // ahead of beta, matching the sidebar below Recent.
    useGlobalSessionsStore.setState({
      activeSessions: [
        makeSession('beta-new', { updated: 300, directory: '/workspace/beta' }),
        makeSession('alpha-old', { updated: 200, directory: '/workspace/alpha' }),
        makeSession('alpha-older', { updated: 100, directory: '/workspace/alpha' }),
        makeSession('child', { parentID: 'alpha-old', updated: 400, directory: '/workspace/alpha' }),
        makeSession('archived', { updated: 500, archived: true, directory: '/workspace/alpha' }),
      ],
      archivedSessions: [],
      sessionsByDirectory: new Map(),
      reviewTransferBySessionId: new Map(),
      hasLoaded: true,
      status: 'ready',
    });

    expect(getNavigableRootSessions().map((session) => session.id)).toEqual([
      'alpha-old',
      'alpha-older',
      'beta-new',
    ]);
  });

  test('resolveAdjacentRootSession cycles only root sessions in project order', () => {
    useProjectsStore.setState({
      projects: [
        { id: 'p1', path: '/workspace/project', label: 'project' },
      ] as never,
      activeProjectId: 'p1',
    });
    useGlobalSessionsStore.setState({
      activeSessions: [
        makeSession('root-a', { updated: 100, directory: '/workspace/project' }),
        makeSession('root-b', { updated: 200, directory: '/workspace/project' }),
        makeSession('child', { parentID: 'root-a', updated: 300, directory: '/workspace/project' }),
      ],
      archivedSessions: [],
      sessionsByDirectory: new Map(),
      reviewTransferBySessionId: new Map(),
      hasLoaded: true,
      status: 'ready',
    });

    // Within a project, pinned+time still applies: root-b (200) before root-a (100).
    expect(resolveAdjacentRootSession(1, 'root-b')?.id).toBe('root-a');
    expect(resolveAdjacentRootSession(-1, 'root-a')?.id).toBe('root-b');
    // From a subsession, navigate relative to its root parent (root-a).
    // With only two roots, both directions from root-a land on root-b.
    expect(resolveAdjacentRootSession(1, 'child')?.id).toBe('root-b');
    expect(resolveAdjacentRootSession(-1, 'child')?.id).toBe('root-b');
  });

  test('resolveAdjacentRootSession respects pinned ordering within a project', () => {
    useSessionPinnedStore.setState({ ids: new Set(['root-a']) });
    useProjectsStore.setState({
      projects: [
        { id: 'p1', path: '/workspace/project', label: 'project' },
      ] as never,
      activeProjectId: 'p1',
    });
    useGlobalSessionsStore.setState({
      activeSessions: [
        makeSession('root-a', { updated: 100, directory: '/workspace/project' }),
        makeSession('root-b', { updated: 200, directory: '/workspace/project' }),
      ],
      archivedSessions: [],
      sessionsByDirectory: new Map(),
      reviewTransferBySessionId: new Map(),
      hasLoaded: true,
      status: 'ready',
    });

    expect(resolveAdjacentRootSession(1, 'root-a')?.id).toBe('root-b');
    expect(resolveAdjacentRootSession(-1, 'root-b')?.id).toBe('root-a');
  });

  test('falls back to sync sessions when global store is empty', () => {
    bootstrapSessions([
      makeSession('root-a', { updated: 100 }),
      makeSession('root-b', { updated: 200 }),
    ]);

    expect(getNavigableRootSessions().map((session) => session.id)).toEqual([
      'root-b',
      'root-a',
    ]);
  });
});
