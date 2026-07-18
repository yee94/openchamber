import { describe, expect, mock, test } from 'bun:test';

mock.module('react', () => ({
  default: {
    useCallback: <T,>(callback: T) => callback,
    useEffect: () => undefined,
    useRef: <T,>(value: T) => ({ current: value }),
    useState: <T,>(value: T) => [value, () => undefined],
  },
}));
mock.module('@/components/ui', () => ({
  toast: { error: () => undefined, success: () => undefined },
}));
mock.module('@/lib/clipboard', () => ({ copyTextToClipboard: async () => ({ ok: true }) }));
mock.module('@/lib/i18n', () => ({ useI18n: () => ({ t: (key: string) => key }) }));
mock.module('@/lib/sessionMutationUndo', () => ({
  deleteSessionsWithUndo: async () => ({ archivedIds: [], deletedIds: [], failedIds: [] }),
  showArchivedSessionsUndoToast: () => undefined,
}));

const { useSessionActions } = await import('./useSessionActions');

const createArgs = () => {
  const activeMainTabCalls: string[] = [];
  const currentSessionCalls: Array<[string | null, string | null | undefined]> = [];

  return {
  activeProjectId: 'project-1',
  currentDirectory: '/repo',
  currentSessionId: 'session-1',
  mobileVariant: false,
  allowReselect: false,
  isSessionSearchOpen: false,
  sessionSearchQuery: '',
  setSessionSearchQuery: () => undefined,
  setIsSessionSearchOpen: () => undefined,
  setActiveProjectIdOnly: () => undefined,
  setDirectory: () => undefined,
  setActiveMainTab: (tab: string) => {
    activeMainTabCalls.push(tab);
    return true;
  },
  setSessionSwitcherOpen: () => undefined,
  setCurrentSession: (sessionId: string | null, directory?: string | null) => {
    currentSessionCalls.push([sessionId, directory]);
  },
  updateSessionTitle: async () => undefined,
  shareSession: async () => null,
  unshareSession: async () => null,
  archiveSession: async () => true,
  archiveSessions: async () => ({ archivedIds: [], failedIds: [] }),
  childrenMap: new Map(),
  showDeletionDialog: true,
  setDeleteSessionConfirm: () => undefined,
  deleteSessionConfirm: null,
  setEditingId: () => undefined,
  setEditTitle: () => undefined,
  editingId: null,
  editTitle: '',
  activeMainTabCalls,
  currentSessionCalls,
  };
};

describe('useSessionActions', () => {
  test('switches desktop navigation to chat before selecting a session', () => {
    const args = createArgs();
    const actions = useSessionActions(args);

    actions.handleSessionSelect('session-2', '/repo', 'project-1');

    expect(args.activeMainTabCalls).toEqual(['chat']);
    expect(args.currentSessionCalls).toEqual([['session-2', '/repo']]);
  });

  test('keeps the current session when navigation is declined', () => {
    const args = createArgs();
    args.setActiveMainTab = () => false;
    const actions = useSessionActions(args);

    actions.handleSessionSelect('session-2', '/repo', 'project-1');

    expect(args.currentSessionCalls).toEqual([]);
  });
});
