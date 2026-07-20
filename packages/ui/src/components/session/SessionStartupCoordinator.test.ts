import { afterEach, describe, expect, test } from 'bun:test';

import {
  beginSessionStartupBarrier,
  isSessionStartupBarrierActive,
  releaseSessionStartupBarrier,
} from '@/lib/session-startup-barrier';

import {
  collectSessionStartupDirectories,
  runSessionStartup,
  runSessionStartupAfterSettingsHydration,
} from './runSessionStartup';

describe('runSessionStartup', () => {
  afterEach(() => {
    releaseSessionStartupBarrier();
  });

  test('passes known project directories to the shared startup flow', async () => {
    const calls: string[][] = [];
    const start = async (directories: Iterable<string>) => {
      calls.push([...directories]);
      return { activeSessions: [], archivedSessions: [] };
    };

    await runSessionStartup(['/repo/a', '/repo/b'], start);

    expect(calls).toEqual([['/repo/a', '/repo/b']]);
  });

  test('collects persisted worktree directories for registered projects', () => {
    const directories = collectSessionStartupDirectories(
      ['/repo/a/', '/repo/b'],
      new Map([
        ['/repo/a', [{ path: '/repo/a-feature/' }, { path: '/repo/a-feature' }]],
        ['/stale', [{ path: '/stale/feature' }]],
      ]),
    );

    expect(directories).toEqual(['/repo/a', '/repo/a-feature', '/repo/b']);
  });

  test('reads project directories after settings hydration completes', async () => {
    let releaseSettings: (() => void) | undefined;
    const settingsHydration = new Promise<void>((resolve) => { releaseSettings = resolve; });
    let directories = [] as string[];
    const calls: string[][] = [];
    const startup = runSessionStartupAfterSettingsHydration(
      settingsHydration,
      () => directories,
      async (nextDirectories) => {
        calls.push([...nextDirectories]);
        return { activeSessions: [], archivedSessions: [] };
      },
    );

    directories = ['/repo/restored'];
    expect(calls).toEqual([]);
    releaseSettings?.();
    await startup;

    expect(calls).toEqual([['/repo/restored']]);
  });

  test('releases the startup barrier after success', async () => {
    beginSessionStartupBarrier();

    await runSessionStartup([], async () => ({ activeSessions: [], archivedSessions: [] }));

    expect(isSessionStartupBarrierActive()).toBe(false);
  });

  test('releases the startup barrier after failure', async () => {
    beginSessionStartupBarrier();
    const originalWarn = console.warn;
    console.warn = () => undefined;

    try {
      await runSessionStartup([], async () => {
        throw new Error('unavailable');
      });
    } finally {
      console.warn = originalWarn;
    }

    expect(isSessionStartupBarrierActive()).toBe(false);
  });
});
