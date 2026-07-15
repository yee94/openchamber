import { describe, expect, test } from 'bun:test';

import { executeLeaderCompact } from './useKeyboardShortcuts';

describe('executeLeaderCompact', () => {
  test('keeps a current directory from compacting when the authoritative directory is missing', async () => {
    const currentDirectory = '/current-directory';
    let summarizeCalls = 0;
    let compactFailedCalls = 0;

    await executeLeaderCompact({
      sessionId: 'session-1',
      currentProviderId: 'provider-1',
      currentModelId: 'model-1',
      waitForConnectionOrThrow: async () => undefined,
      getAuthoritativeDirectoryForSession: () => {
        expect(currentDirectory).toBe('/current-directory');
        return null;
      },
      summarizeSession: async () => {
        summarizeCalls += 1;
      },
      onCompactFailed: () => {
        compactFailedCalls += 1;
      },
    });

    expect(summarizeCalls).toBe(0);
    expect(compactFailedCalls).toBe(1);
  });

  test('compacts with the authoritative session directory', async () => {
    const summarizeCalls: Array<[string, string, string, string | null | undefined]> = [];

    await executeLeaderCompact({
      sessionId: 'session-1',
      currentProviderId: 'provider-1',
      currentModelId: 'model-1',
      waitForConnectionOrThrow: async () => undefined,
      getAuthoritativeDirectoryForSession: () => '/authoritative-directory',
      summarizeSession: async (sessionId, providerId, modelId, directory) => {
        summarizeCalls.push([sessionId, providerId, modelId, directory]);
      },
      onCompactFailed: () => {
        throw new Error('compact should succeed');
      },
    });

    expect(summarizeCalls).toEqual([
      ['session-1', 'provider-1', 'model-1', '/authoritative-directory'],
    ]);
  });
});
