import { beforeEach, describe, expect, mock, test } from 'bun:test';

const refreshError = new Error('GitHub status unavailable');
let refreshImpl: () => Promise<null> = async () => null;

mock.module('@/lib/queryRuntime', () => ({
  queryClient: {
    cancelQueries: async () => undefined,
  },
  queryKeys: {
    github: {
      auth: (transport: string) => [transport, 'github', 'auth'],
    },
  },
}));
mock.module('@/lib/runtime-switch', () => ({
  getRuntimeTransportIdentity: () => 'transport-a',
}));
mock.module('@/queries/githubAuthQueries', () => ({
  refreshGitHubAuthQuery: () => refreshImpl(),
  setGitHubAuthSnapshot: () => undefined,
}));

const { useGitHubAuthStore } = await import('./useGitHubAuthStore');

describe('useGitHubAuthStore refreshStatus', () => {
  beforeEach(() => {
    refreshImpl = async () => null;
  });

  test('propagates refresh failures to the caller', async () => {
    refreshImpl = async () => { throw refreshError; };

    await expect(useGitHubAuthStore.getState().refreshStatus()).rejects.toThrow('GitHub status unavailable');
  });
});
