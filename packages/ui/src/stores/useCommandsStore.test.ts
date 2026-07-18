import { beforeEach, describe, expect, mock, test } from 'bun:test';
let activeProjectPath = '/workspace/project';
let runtimeKey = 'runtime-a';
let commandRequestDirectory: string | null = null;
let listCalls = 0;
type RawCommand = { name: string; source?: string; template?: string };
let listImpl: () => Promise<RawCommand[]> = async () => [];
let metadataCalls: Array<RequestInit | undefined> = [];
let metadataImpl: (init?: RequestInit) => Promise<Response> = async () => new Response(JSON.stringify({ commands: {} }));

mock.module('@/lib/opencode/client', () => ({
  opencodeClient: {
    getDirectory: () => '/fallback/project',
    withDirectory: async (directory: string | null, callback: () => Promise<unknown>) => {
      commandRequestDirectory = directory;
      return callback();
    },
    listCommandsWithDetails: async () => {
      listCalls += 1;
      return listImpl();
    },
  },
}));
mock.module('@/stores/useProjectsStore', () => ({
  useProjectsStore: Object.assign(() => null, { getState: () => ({ getActiveProject: () => ({ path: activeProjectPath }) }) }),
}));
mock.module('@/lib/runtime-fetch', () => ({
  runtimeFetch: async (_input: string, init?: RequestInit) => {
    metadataCalls.push(init);
    return metadataImpl(init);
  },
}));
mock.module('@/lib/runtime-switch', () => ({
  getRuntimeTransportIdentity: () => runtimeKey,
  isRuntimeEndpointIdentityChange: () => false,
  subscribeRuntimeEndpointChanged: () => () => undefined,
}));
mock.module('@/lib/configUpdate', () => ({ startConfigUpdate: mock(() => undefined), finishConfigUpdate: mock(() => undefined), updateConfigUpdateMessage: mock(() => undefined) }));
mock.module('@/lib/configSync', () => ({ emitConfigChange: mock(() => undefined), scopeMatches: mock(() => false), subscribeToConfigChanges: mock(() => () => undefined) }));

const { commandQueryOptions, readCommandsSnapshot, refreshCommandsQuery } = await import('@/queries/commandQueries');
const { useCommandsStore } = await import('./useCommandsStore');
const { queryClient } = await import('@/lib/queryRuntime');

describe('useCommandsStore', () => {
  beforeEach(() => {
    queryClient.clear();
    activeProjectPath = '/workspace/project';
    runtimeKey = 'runtime-a';
    commandRequestDirectory = null;
    listCalls = 0;
    listImpl = async () => [];
    metadataCalls = [];
    metadataImpl = async () => new Response(JSON.stringify({ commands: {} }));
    useCommandsStore.setState({ selectedCommandName: null, commandDraft: null });
  });

  test('keeps only command UI state and loads through the query cache', async () => {
    listImpl = async () => [...Array.from({ length: 80 }, (_, index) => ({ name: `command-${index}`, source: 'command' })), { name: 'skill', source: 'skill' }];
    metadataImpl = async () => new Response(JSON.stringify({ commands: { 'command-0': { scope: 'project' } } }));

    const loaded = await useCommandsStore.getState().loadCommands();

    expect(loaded).toBe(true);
    expect(readCommandsSnapshot()).toHaveLength(80);
    expect(readCommandsSnapshot()[0]?.scope).toBe('project');
    expect(commandRequestDirectory).toBe('/workspace/project');
    expect(metadataCalls).toHaveLength(1);
    expect(metadataCalls[0]?.signal).toBeInstanceOf(AbortSignal);
    expect(Object.hasOwn(useCommandsStore.getState(), 'commands')).toBe(false);
    expect(Object.hasOwn(useCommandsStore.getState(), 'isLoading')).toBe(false);
  });

  test('refreshes the captured query after a mutation', async () => {
    let template = 'first';
    listImpl = async () => [{ name: 'deploy', source: 'command', template }];
    await refreshCommandsQuery(queryClient, activeProjectPath, runtimeKey);
    template = 'second';
    await refreshCommandsQuery(queryClient, activeProjectPath, runtimeKey);
    expect(readCommandsSnapshot()[0]?.template).toBe('second');

    metadataImpl = async (init) => init?.method === 'PATCH'
      ? new Response(JSON.stringify({ requiresReload: false }))
      : new Response(JSON.stringify({ commands: {} }));
    await useCommandsStore.getState().updateCommand('deploy', { template: 'third' });
    expect(listCalls).toBe(3);
  });

  test('keeps a switched runtime query untouched after a mutation completes', async () => {
    listImpl = async () => [{ name: 'deploy', source: 'command' }];
    await refreshCommandsQuery(queryClient, activeProjectPath, runtimeKey);
    const requestRuntime = runtimeKey;
    metadataImpl = async (init) => {
      if (init?.method === 'PATCH') {
        runtimeKey = 'runtime-b';
        return new Response(JSON.stringify({ requiresReload: false }));
      }
      return new Response(JSON.stringify({ commands: {} }));
    };

    await useCommandsStore.getState().updateCommand('deploy', { template: 'updated' });

    expect(runtimeKey).toBe('runtime-b');
    expect(listCalls).toBe(1);
    expect((queryClient.getQueryData(['runtime-a', 'commands', '/workspace/project']) as RawCommand[])[0]?.name).toBe('deploy');
    expect(commandQueryOptions('/workspace/project').queryKey).toEqual(['runtime-b', 'commands', '/workspace/project']);
    expect(requestRuntime).toBe('runtime-a');
  });

  test('uses the captured runtime query key', () => {
    expect(commandQueryOptions('/workspace/project').queryKey).toEqual(['runtime-a', 'commands', '/workspace/project']);
  });
});
