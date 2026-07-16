import { describe, expect, mock, test } from 'bun:test';

type EffectSlot = {
  cleanup?: () => void;
  deps?: readonly unknown[];
};

const dependenciesChanged = (previous: readonly unknown[] | undefined, next: readonly unknown[]) =>
  !previous
  || previous.length !== next.length
  || previous.some((dependency, index) => dependency !== next[index]);

const createHookHarness = () => {
  const stateSlots: unknown[] = [];
  const memoSlots: Array<{ value: unknown; deps: readonly unknown[] }> = [];
  const effectSlots: EffectSlot[] = [];
  let hookIndex = 0;
  let mounted = false;
  let renderHook: (() => void) | null = null;

  const react = {
    useCallback: <T,>(callback: T, deps: readonly unknown[]) => {
      const index = hookIndex++;
      const previous = memoSlots[index];
      if (!previous || dependenciesChanged(previous.deps, deps)) {
        memoSlots[index] = { value: callback, deps };
      }
      return memoSlots[index].value as T;
    },
    useEffect: (effect: () => void | (() => void), deps: readonly unknown[]) => {
      const index = hookIndex++;
      const slot = effectSlots[index] ?? {};
      if (dependenciesChanged(slot.deps, deps)) {
        slot.cleanup?.();
        slot.deps = deps;
        effectSlots[index] = slot;
        const cleanup = effect();
        slot.cleanup = typeof cleanup === 'function' ? cleanup : undefined;
      }
    },
    useMemo: <T,>(factory: () => T, deps: readonly unknown[]) => {
      const index = hookIndex++;
      const previous = memoSlots[index];
      if (!previous || dependenciesChanged(previous.deps, deps)) {
        memoSlots[index] = { value: factory(), deps };
      }
      return memoSlots[index].value as T;
    },
    useRef: <T,>(value: T) => {
      const index = hookIndex++;
      if (!(index in stateSlots)) {
        stateSlots[index] = { current: value };
      }
      return stateSlots[index] as { current: T };
    },
    useState: <T,>(initial: T | (() => T)) => {
      const index = hookIndex++;
      if (!(index in stateSlots)) {
        stateSlots[index] = typeof initial === 'function' ? (initial as () => T)() : initial;
      }
      const setState = (value: T) => {
        stateSlots[index] = value;
        if (mounted) {
          renderHook?.();
        }
      };
      return [stateSlots[index] as T, setState] as const;
    },
  };

  return {
    react,
    render(callback: () => void) {
      renderHook = () => {
        hookIndex = 0;
        callback();
      };
      mounted = true;
      renderHook();
    },
  };
};

const harness = createHookHarness();
const sessionSubscribers = new Set<(state: typeof sessionState) => void>();
const uiSubscribers = new Set<(state: typeof uiState) => void>();

const sessionState = {
  currentSessionId: 'session-1' as string | null,
  currentSessionDirectory: '/repo' as string | null,
  setCurrentSession: () => undefined,
};
const uiState = {
  activeMainTab: 'chat' as const,
  isSettingsDialogOpen: false,
  settingsPage: 'home',
  pendingDiffFile: null as string | null,
  setActiveMainTab: () => undefined,
  setSettingsDialogOpen: (isOpen: boolean) => {
    uiState.isSettingsDialogOpen = isOpen;
  },
  setSettingsPage: (path: string) => {
    uiState.settingsPage = path;
  },
  navigateToDiff: () => undefined,
};
let globalSessionsState = {
  hasLoaded: true,
  activeSessions: [{ id: 'session-1' }],
  archivedSessions: [] as Array<{ id: string }>,
};
let urlRoute = {
  sessionId: 'session-1' as string | null,
  tab: null as 'chat' | null,
  settingsPath: null as string | null,
  diffFile: null as string | null,
};

mock.module('react', () => ({ default: harness.react }));
mock.module('@/sync/session-ui-store', () => ({
  useSessionUIStore: Object.assign(
    <T,>(selector: (state: typeof sessionState) => T) => selector(sessionState),
    {
      getState: () => sessionState,
      subscribe: (subscriber: (state: typeof sessionState) => void) => {
        sessionSubscribers.add(subscriber);
        return () => sessionSubscribers.delete(subscriber);
      },
    },
  ),
}));
mock.module('@/stores/useUIStore', () => ({
  useUIStore: Object.assign(
    <T,>(selector: (state: typeof uiState) => T) => selector(uiState),
    {
      getState: () => uiState,
      subscribe: (subscriber: (state: typeof uiState) => void) => {
        uiSubscribers.add(subscriber);
        return () => uiSubscribers.delete(subscriber);
      },
    },
  ),
}));
mock.module('@/stores/useGlobalSessionsStore', () => ({
  resolveGlobalSessionDirectory: () => '/repo',
  useGlobalSessionsStore: Object.assign(
    <T,>(selector: (state: typeof globalSessionsState) => T) => selector(globalSessionsState),
    { getState: () => globalSessionsState },
  ),
}));
mock.module('@/lib/router', () => ({
  parseRoute: () => ({ ...urlRoute }),
  hasRouteParams: () => true,
  updateBrowserURL: (state: {
    sessionId: string | null;
    isSettingsOpen: boolean;
    settingsPath: string;
  }) => {
    urlRoute = {
      sessionId: state.sessionId,
      tab: null,
      settingsPath: state.isSettingsOpen ? state.settingsPath : null,
      diffFile: null,
    };
  },
}));
mock.module('@/lib/settings/metadata', () => ({ resolveSettingsSlug: (path: string) => path }));
mock.module('@/components/layout/contextPanelEmbeddedChat', () => ({ isEmbeddedSessionChat: () => false }));

const { useRouter } = await import('./useRouter');

describe('useRouter', () => {
  test('keeps Settings open when session summaries update after Settings opens', async () => {
    harness.render(useRouter);
    await Promise.resolve();

    uiState.settingsPage = 'appearance';
    uiState.isSettingsDialogOpen = true;
    uiSubscribers.forEach((subscriber) => subscriber(uiState));

    globalSessionsState = {
      ...globalSessionsState,
      activeSessions: [{ id: 'session-1' }],
    };
    harness.render(useRouter);

    expect(uiState.isSettingsDialogOpen).toBe(true);
  });
});
