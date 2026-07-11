import { afterEach, beforeEach, describe, expect, test } from 'bun:test';
import type { OpencodeClient, Session } from '@opencode-ai/sdk/v2';

import { resolveGlobalSessionDirectory, mergeLiveSessionWithGlobalSession, useGlobalSessionsStore } from './useGlobalSessionsStore';
import { opencodeClient } from '@/lib/opencode/client';

type SessionExtra = Partial<Session> & {
  directory?: string | null;
  project?: { worktree?: string | null } | null;
};

const buildSession = (shareUrl: string, extra: SessionExtra = {}): Session => ({
  id: 'ses_1',
  title: 'Shared session',
  time: { created: 1, updated: 2 },
  share: { url: shareUrl },
  ...extra,
} as Session);

describe('useGlobalSessionsStore', () => {
  let restoreGetSdkClient: (() => void) | null = null;

  beforeEach(() => {
    useGlobalSessionsStore.setState({
      activeSessions: [],
      archivedSessions: [],
      sessionsByDirectory: new Map(),
      loadedDirectories: new Set(),
      loadingDirectories: new Set(),
      refreshingDirectories: new Set(),
      archivedLoadedDirectories: new Set(),
      archivedLoadingDirectories: new Set(),
      activePaginationByDirectory: new Map(),
      hasLoadedFullCatalog: false,
      hasLoaded: false,
      status: 'idle',
    });
  });

  afterEach(() => {
    restoreGetSdkClient?.();
    restoreGetSdkClient = null;
  });

  test('coalesces overlapping active refreshes by directory and keeps a cached snapshot visible', async () => {
    type ListResult = { data?: Session[]; error?: { message: string }; response: Response };
    let resolveList: (value: ListResult) => void = () => undefined;
    const calls: Array<Record<string, unknown>> = [];
    const list = (input: Record<string, unknown>) => new Promise<ListResult>((resolve) => {
      calls.push(input);
      resolveList = resolve;
    });
    const sdk = { experimental: { session: { list } } } as unknown as OpencodeClient;
    const originalGetSdkClient = opencodeClient.getSdkClient;
    opencodeClient.getSdkClient = () => sdk;
    restoreGetSdkClient = () => { opencodeClient.getSdkClient = originalGetSdkClient; };

    const cached = buildSession('https://share.example/a', { directory: '/repo/app' });
    useGlobalSessionsStore.setState({
      activeSessions: [cached],
      sessionsByDirectory: new Map([['/repo/app', [cached]]]),
      loadedDirectories: new Set(['/repo/app']),
      hasLoaded: true,
      status: 'ready',
    });

    const first = useGlobalSessionsStore.getState().refreshSessionsForDirectories(['/repo/app']);
    const second = useGlobalSessionsStore.getState().refreshSessionsForDirectories(['/repo/app']);

    expect(calls.length).toBe(1);
    expect(calls[0]).toEqual({ directory: '/repo/app', archived: false, roots: true, limit: 20 });
    expect(useGlobalSessionsStore.getState().activeSessions[0]?.id).toBe('ses_1');
    expect(useGlobalSessionsStore.getState().loadingDirectories.has('/repo/app')).toBe(false);
    expect(useGlobalSessionsStore.getState().refreshingDirectories.has('/repo/app')).toBe(true);

    resolveList({
      data: [{ ...cached, title: 'Fresh session', time: { created: 1, updated: 3 } }],
      error: undefined,
      response: new Response(null, { status: 200 }),
    });
    await Promise.all([first, second]);

    expect(calls.length).toBe(1);
    expect(useGlobalSessionsStore.getState().activeSessions[0]?.title).toBe('Fresh session');
    expect(useGlobalSessionsStore.getState().refreshingDirectories.has('/repo/app')).toBe(false);
  });

  test('loads archived sessions through the independent lazy path', async () => {
    const archived = buildSession('https://share.example/a', {
      directory: '/repo/app',
      time: { created: 1, updated: 2, archived: 3 },
    });
    const calls: Array<Record<string, unknown>> = [];
    const list = async (input: Record<string, unknown>) => {
      calls.push(input);
      return {
      data: [archived],
      error: undefined,
      response: new Response(null, { status: 200 }),
      };
    };
    const sdk = { experimental: { session: { list } } } as unknown as OpencodeClient;
    const originalGetSdkClient = opencodeClient.getSdkClient;
    opencodeClient.getSdkClient = () => sdk;
    restoreGetSdkClient = () => { opencodeClient.getSdkClient = originalGetSdkClient; };

    await useGlobalSessionsStore.getState().refreshArchivedSessionsForDirectories(['/repo/app']);

    expect(calls.length).toBe(1);
    expect(calls[0]).toEqual({ directory: '/repo/app', archived: true, roots: true, limit: 20 });
    expect(useGlobalSessionsStore.getState().archivedSessions[0]?.id).toBe('ses_1');
    expect(useGlobalSessionsStore.getState().archivedLoadedDirectories.has('/repo/app')).toBe(true);
    expect(useGlobalSessionsStore.getState().archivedLoadingDirectories.has('/repo/app')).toBe(false);
  });

  test('preserves cached active sessions and clears refresh state after a fetch failure', async () => {
    const cached = buildSession('https://share.example/a', { directory: '/repo/app' });
    const list = async () => ({
      data: undefined,
      error: { message: 'bad request' },
      response: new Response(null, { status: 400 }),
    });
    const sdk = { experimental: { session: { list } } } as unknown as OpencodeClient;
    const originalGetSdkClient = opencodeClient.getSdkClient;
    opencodeClient.getSdkClient = () => sdk;
    restoreGetSdkClient = () => { opencodeClient.getSdkClient = originalGetSdkClient; };
    useGlobalSessionsStore.setState({
      activeSessions: [cached],
      sessionsByDirectory: new Map([['/repo/app', [cached]]]),
      loadedDirectories: new Set(['/repo/app']),
      hasLoaded: true,
      status: 'ready',
    });

    await useGlobalSessionsStore.getState().refreshSessionsForDirectories(['/repo/app']);

    expect(useGlobalSessionsStore.getState().activeSessions).toEqual([cached]);
    expect(useGlobalSessionsStore.getState().loadingDirectories.has('/repo/app')).toBe(false);
    expect(useGlobalSessionsStore.getState().refreshingDirectories.has('/repo/app')).toBe(false);
  });

  test('loads the next 20 root sessions from the stored cursor and appends them', async () => {
    const calls: Array<Record<string, unknown>> = [];
    const makePage = (start: number) => Array.from({ length: 20 }, (_, index) => ({
      id: `ses_${start + index}`,
      title: `Session ${start + index}`,
      directory: '/repo/app',
      time: { created: 100 - start - index, updated: 100 - start - index },
    } as Session));
    const list = async (input: Record<string, unknown>) => {
      calls.push(input);
      return {
        data: input.cursor === undefined ? makePage(0) : makePage(20),
        error: undefined,
        response: new Response(null, { status: 200 }),
      };
    };
    const sdk = { experimental: { session: { list } } } as unknown as OpencodeClient;
    const originalGetSdkClient = opencodeClient.getSdkClient;
    opencodeClient.getSdkClient = () => sdk;
    restoreGetSdkClient = () => { opencodeClient.getSdkClient = originalGetSdkClient; };

    await useGlobalSessionsStore.getState().refreshSessionsForDirectories(['/repo/app']);
    await useGlobalSessionsStore.getState().loadMoreSessionsForDirectory('/repo/app');

    expect(calls.length).toBe(2);
    expect(calls[1]).toEqual({
      directory: '/repo/app',
      archived: false,
      roots: true,
      cursor: 81,
      limit: 20,
    });
    expect(useGlobalSessionsStore.getState().sessionsByDirectory.get('/repo/app')?.length).toBe(40);
    expect(useGlobalSessionsStore.getState().activePaginationByDirectory.get('/repo/app')).toEqual({
      cursor: 61,
      hasMore: true,
      loadingMore: false,
    });
  });

  test('aborts an in-flight directory request on runtime reset', async () => {
    let requestSignal: AbortSignal | undefined;
    const list = (_input: Record<string, unknown>, options?: { signal?: AbortSignal }) => {
      requestSignal = options?.signal;
      return new Promise((_resolve, reject) => {
        options?.signal?.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')), { once: true });
      });
    };
    const sdk = { experimental: { session: { list } } } as unknown as OpencodeClient;
    const originalGetSdkClient = opencodeClient.getSdkClient;
    opencodeClient.getSdkClient = () => sdk;
    restoreGetSdkClient = () => { opencodeClient.getSdkClient = originalGetSdkClient; };

    const refresh = useGlobalSessionsStore.getState().refreshSessionsForDirectories(['/repo/app']);
    useGlobalSessionsStore.getState().resetForRuntimeSwitch();
    await refresh;

    expect(requestSignal?.aborted).toBe(true);
    expect(useGlobalSessionsStore.getState().status).toBe('idle');
    expect(useGlobalSessionsStore.getState().activeSessions).toEqual([]);
  });

  test('updates an existing session when the share URL changes', () => {
    useGlobalSessionsStore.getState().upsertSession(buildSession('https://share.example/a'));
    useGlobalSessionsStore.getState().upsertSession(buildSession('https://share.example/b'));

    expect(useGlobalSessionsStore.getState().activeSessions[0]?.share?.url).toBe('https://share.example/b');
  });

  test('preserves directory metadata when a live update omits it', () => {
    useGlobalSessionsStore.getState().upsertSession(buildSession('https://share.example/a', { directory: '/repo/app' }));
    useGlobalSessionsStore.getState().upsertSession(buildSession('https://share.example/b', {
      time: { created: 1, updated: 3 },
    }));

    const session = useGlobalSessionsStore.getState().activeSessions[0];
    expect(resolveGlobalSessionDirectory(session)).toBe('/repo/app');
    expect(useGlobalSessionsStore.getState().sessionsByDirectory.get('/repo/app')?.[0]?.id).toBe('ses_1');
  });

  test('preserves raw directory metadata when a live update only has project worktree', () => {
    useGlobalSessionsStore.getState().upsertSession(buildSession('https://share.example/a', { directory: '/repo/app' }));
    useGlobalSessionsStore.getState().upsertSession(buildSession('https://share.example/b', {
      project: { worktree: '/repo/app' },
      time: { created: 1, updated: 3 },
    }));

    const session = useGlobalSessionsStore.getState().activeSessions[0] as Session & { directory?: string | null };
    expect(session.directory).toBe('/repo/app');
    expect(resolveGlobalSessionDirectory(session)).toBe('/repo/app');
  });

  test('trusts explicit incoming raw directory metadata', () => {
    useGlobalSessionsStore.getState().upsertSession(buildSession('https://share.example/a', { directory: '/repo/app' }));
    useGlobalSessionsStore.getState().upsertSession(buildSession('https://share.example/b', {
      directory: '/repo/app-worktree',
      time: { created: 1, updated: 3 },
    }));

    expect(resolveGlobalSessionDirectory(useGlobalSessionsStore.getState().activeSessions[0])).toBe('/repo/app-worktree');
    expect(useGlobalSessionsStore.getState().sessionsByDirectory.get('/repo/app')).toBe(undefined);
    expect(useGlobalSessionsStore.getState().sessionsByDirectory.get('/repo/app-worktree')?.[0]?.id).toBe('ses_1');
  });

  test('preserves directory metadata when moving a session to archived', () => {
    useGlobalSessionsStore.getState().upsertSession(buildSession('https://share.example/a', { directory: '/repo/app' }));
    useGlobalSessionsStore.getState().upsertSession(buildSession('https://share.example/b', {
      time: { created: 1, updated: 3, archived: 4 },
    }));

    expect(useGlobalSessionsStore.getState().activeSessions).toEqual([]);
    expect(resolveGlobalSessionDirectory(useGlobalSessionsStore.getState().archivedSessions[0])).toBe('/repo/app');
  });
});

describe('mergeLiveSessionWithGlobalSession', () => {
  test('preserves global share over live share', () => {
    const live = buildSession('https://live.example/s', { time: { created: 1, updated: 5 } });
    const global = buildSession('https://global.example/s', { time: { created: 1, updated: 3 } });

    const merged = mergeLiveSessionWithGlobalSession(live, global);
    expect(merged.share?.url).toBe('https://global.example/s');
    expect(merged.time?.updated).toBe(5);
  });

  test('preserves directory from global when live omits it', () => {
    const live = buildSession('https://live.example/s', { time: { created: 1, updated: 5 } });
    const global = buildSession('https://global.example/s', { directory: '/repo/app' });

    const merged = mergeLiveSessionWithGlobalSession(live, global);
    expect(resolveGlobalSessionDirectory(merged)).toBe('/repo/app');
  });

  test('live directory takes precedence over global when present', () => {
    const live = buildSession('https://live.example/s', { directory: '/repo/worktree' });
    const global = buildSession('https://global.example/s', { directory: '/repo/app' });

    const merged = mergeLiveSessionWithGlobalSession(live, global);
    expect(resolveGlobalSessionDirectory(merged)).toBe('/repo/worktree');
  });
});
