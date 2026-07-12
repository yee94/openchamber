import { afterEach, describe, expect, test } from 'bun:test';

import {
  beginSessionStartupBarrier,
  isSessionStartupBarrierActive,
  releaseSessionStartupBarrier,
} from '@/lib/session-startup-barrier';

import { runSessionStartup } from './runSessionStartup';

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
