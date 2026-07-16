import { describe, expect, mock, test } from 'bun:test';

let preloadCalls = 0;
let scheduledCallbacks: Array<() => void> = [];

mock.module('react', () => ({
  default: {
    useCallback: <T,>(callback: T) => callback,
    useEffect: (effect: () => void | (() => void)) => effect(),
    useMemo: <T,>(factory: () => T) => factory(),
    useRef: <T,>(value: T) => ({ current: value }),
    useState: <T,>(value: T) => [value, () => undefined],
  },
}));

const sessionUIState = { currentSessionId: null, isLoading: false };
const globalSessionsState = { activeSessions: [], hasLoadedFullCatalog: false };
const uiState = {
  autoDeleteEnabled: true,
  autoDeleteAfterDays: 30,
  sessionRetentionAction: 'delete' as const,
  autoDeleteLastRunAt: null,
  setAutoDeleteLastRunAt: () => undefined,
};

mock.module('@/stores/useGlobalSessionsStore', () => ({
  ensureFullGlobalSessionsLoaded: () => {
    preloadCalls += 1;
    return Promise.resolve({ activeSessions: [] });
  },
  resolveGlobalSessionDirectory: () => null,
  useGlobalSessionsStore: Object.assign(
    <T,>(selector: (state: typeof globalSessionsState) => T) => selector(globalSessionsState),
    { getState: () => ({ archiveSessions: () => undefined, removeSessions: () => undefined }) },
  ),
}));
mock.module('@/sync/session-ui-store', () => ({
  useSessionUIStore: <T,>(selector: (state: typeof sessionUIState) => T) => selector(sessionUIState),
}));
mock.module('@/stores/useUIStore', () => ({
  useUIStore: <T,>(selector: (state: typeof uiState) => T) => selector(uiState),
}));
mock.module('@/sync/sync-refs', () => ({ getAllSyncSessions: () => [] }));
mock.module('@/lib/opencode/client', () => ({ opencodeClient: {} }));

const { useSessionAutoCleanup } = await import('./useSessionAutoCleanup');

describe('useSessionAutoCleanup', () => {
  test('skips the delayed full catalog preload when autoRun is disabled', () => {
    preloadCalls = 0;
    scheduledCallbacks = [];
    globalThis.window = {
      setTimeout: (callback: () => void) => {
        scheduledCallbacks.push(callback);
        return 1;
      },
      clearTimeout: () => undefined,
    } as unknown as Window & typeof globalThis;

    useSessionAutoCleanup({ autoRun: false });
    scheduledCallbacks.forEach((callback) => callback());

    expect(scheduledCallbacks).toEqual([]);
    expect(preloadCalls).toBe(0);
  });
});
