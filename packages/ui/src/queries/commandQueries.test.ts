import { beforeEach, describe, expect, mock, test } from 'bun:test';

let activeProjectPath = '/workspace/project';
let runtimeKey = 'runtime-a';
let listCalls = 0;
type RawCommand = { name: string; source?: string; template?: string };
let listImpl: () => Promise<RawCommand[]> = async () => [];
let metadataImpl: () => Promise<Response> = async () => new Response(JSON.stringify({ commands: {} }));

mock.module('@/lib/opencode/client', () => ({
  opencodeClient: {
    getDirectory: () => '/fallback/project',
    withDirectory: async (_directory: string | null, callback: () => Promise<unknown>) => callback(),
    listCommandsWithDetails: async () => {
      listCalls += 1;
      return listImpl();
    },
  },
}));
mock.module('@/stores/useProjectsStore', () => ({
  useProjectsStore: Object.assign(() => null, { getState: () => ({ getActiveProject: () => ({ path: activeProjectPath }) }) }),
}));
mock.module('@/lib/runtime-fetch', () => ({ runtimeFetch: async () => metadataImpl() }));
mock.module('@/lib/runtime-switch', () => ({
  getRuntimeTransportIdentity: () => runtimeKey,
  isRuntimeEndpointIdentityChange: () => false,
  subscribeRuntimeEndpointChanged: () => () => undefined,
}));

const { commandQueryOptions, readCommandsSnapshot, refreshCommandsQuery } = await import('./commandQueries');
const { queryClient } = await import('@/lib/queryRuntime');

describe('commandQueries', () => {
  beforeEach(() => {
    queryClient.clear();
    activeProjectPath = '/workspace/project';
    runtimeKey = 'runtime-a';
    listCalls = 0;
    listImpl = async () => [];
    metadataImpl = async () => new Response(JSON.stringify({ commands: {} }));
  });

  test('loads configurable command metadata in one batch', async () => {
    listImpl = async () => [
      ...Array.from({ length: 80 }, (_, index) => ({ name: `command-${index}`, source: 'command' })),
      { name: 'skill', source: 'skill' },
    ];
    metadataImpl = async () => new Response(JSON.stringify({ commands: { 'command-0': { scope: 'project' } } }));

    const commands = await refreshCommandsQuery(queryClient, activeProjectPath, runtimeKey);

    expect(commands).toHaveLength(80);
    expect(commands[0]?.scope).toBe('project');
    expect(listCalls).toBe(1);
  });

  test('preserves a complete snapshot when metadata refresh fails', async () => {
    listImpl = async () => [{ name: 'deploy', source: 'command' }];
    metadataImpl = async () => new Response(JSON.stringify({ commands: { deploy: { scope: 'project' } } }));
    await refreshCommandsQuery(queryClient, activeProjectPath, runtimeKey);
    metadataImpl = async () => { throw new Error('metadata unavailable'); };

    await expect(refreshCommandsQuery(queryClient, activeProjectPath, runtimeKey)).rejects.toThrow('metadata unavailable');
    expect(readCommandsSnapshot()[0]?.scope).toBe('project');
  });

  test('isolates directory and runtime snapshots and shares matching flights', async () => {
    listImpl = async () => [{ name: `${runtimeKey}:${activeProjectPath}`, source: 'command' }];
    await Promise.all([
      refreshCommandsQuery(queryClient, activeProjectPath, runtimeKey),
      refreshCommandsQuery(queryClient, activeProjectPath, runtimeKey),
    ]);
    activeProjectPath = '/workspace/second';
    await refreshCommandsQuery(queryClient, activeProjectPath, runtimeKey);
    runtimeKey = 'runtime-b';
    await refreshCommandsQuery(queryClient, activeProjectPath, runtimeKey);

    expect(listCalls).toBe(3);
    expect(commandQueryOptions(activeProjectPath).queryKey).toEqual(['runtime-b', 'commands', '/workspace/second']);
  });

  test('leaves the captured snapshot untouched when its runtime is inactive', async () => {
    listImpl = async () => [{ name: 'deploy', source: 'command' }];
    await refreshCommandsQuery(queryClient, activeProjectPath, runtimeKey);
    runtimeKey = 'runtime-b';

    await refreshCommandsQuery(queryClient, activeProjectPath, 'runtime-a');

    expect(listCalls).toBe(1);
    expect(readCommandsSnapshot(activeProjectPath, 'runtime-a')[0]?.name).toBe('deploy');
  });
});
