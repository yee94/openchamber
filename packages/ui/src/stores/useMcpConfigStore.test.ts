import { beforeEach, describe, expect, mock, test } from 'bun:test';

const clearDiagnosticCalls: Array<[string, string | null, string]> = [];

mock.module('./utils/safeStorage', () => ({
  createDeferredSafeJSONStorage: () => ({
    getItem: () => null,
    setItem: () => undefined,
    removeItem: () => undefined,
  }),
}));
mock.module('@/lib/configUpdate', () => ({
  startConfigUpdate: () => undefined,
  finishConfigUpdate: () => undefined,
}));
mock.module('@/stores/useAgentsStore', () => ({
  refreshAfterOpenCodeRestart: async () => undefined,
}));
mock.module('@/stores/useProjectsStore', () => ({
  useProjectsStore: { getState: () => ({ getActiveProject: () => null }) },
}));
mock.module('@/lib/opencode/client', () => ({
  opencodeClient: { getDirectory: () => null },
}));
mock.module('@/lib/runtime-fetch', () => ({
  runtimeFetch: async () => new Response('{}'),
}));
mock.module('@/lib/queryRuntime', () => ({ queryClient: {} }));
mock.module('@/lib/runtime-switch', () => ({ getRuntimeTransportIdentity: () => 'current-transport' }));
mock.module('@/queries/mcpQueries', () => ({
  readMcpConfigsSnapshot: () => [],
  refreshMcpConfigsQuery: async () => [],
  refreshMcpStatusQuery: async () => ({}),
}));
mock.module('@/stores/useMcpStore', () => ({
  useMcpStore: {
    getState: () => ({
      clearDiagnostic: (name: string, directory: string | null, transport: string) => {
        clearDiagnosticCalls.push([name, directory, transport]);
      },
    }),
  },
}));

const { useMcpConfigStore } = await import('./useMcpConfigStore');

describe('useMcpConfigStore deleteMcp', () => {
  beforeEach(() => {
    clearDiagnosticCalls.length = 0;
    useMcpConfigStore.setState({ selectedMcpName: null });
  });

  test('clears the deleted server diagnostic with captured scope', async () => {
    const result = await useMcpConfigStore.getState().deleteMcp('server', {
      directory: ' /workspace/project/ ',
      transportIdentity: 'captured-transport',
    });

    expect(result.ok).toBe(true);
    expect(clearDiagnosticCalls).toEqual([['server', '/workspace/project/', 'captured-transport']]);
  });
});
