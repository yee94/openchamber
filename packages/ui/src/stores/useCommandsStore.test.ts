import { beforeEach, describe, expect, mock, test } from 'bun:test';

let activeProjectPath = '/workspace/project';
let runtimeKey = 'runtime-a';
let commandRequestDirectory: string | null = null;

let listCommandsWithDetailsCalls = 0;
let listCommandsWithDetailsImpl: () => Promise<unknown[]> = async () => [];
let withDirectoryImpl: (_directory: string | null, callback: () => Promise<unknown>) => Promise<unknown> = async (directory, callback) => {
  commandRequestDirectory = directory;
  return callback();
};
let getDirectoryImpl: () => string = () => '/fallback/project';
let runtimeFetchCalls: Array<{ input: string; init?: RequestInit }> = [];
let runtimeFetchImpl: (input: string, init?: RequestInit) => Promise<Response> = async () => new Response(JSON.stringify({ commands: {} }), {
  headers: { 'Content-Type': 'application/json' },
});

const listCommandsWithDetailsMock = async () => {
  listCommandsWithDetailsCalls += 1;
  return listCommandsWithDetailsImpl();
};

const withDirectoryMock = async (directory: string | null, callback: () => Promise<unknown>) => withDirectoryImpl(directory, callback);
const getDirectoryMock = () => getDirectoryImpl();
const runtimeFetchMock = async (input: string, init?: RequestInit) => {
  runtimeFetchCalls.push({ input, init });
  return runtimeFetchImpl(input, init);
};

mock.module('@/lib/opencode/client', () => ({
  opencodeClient: {
    getDirectory: getDirectoryMock,
    listCommandsWithDetails: listCommandsWithDetailsMock,
    withDirectory: withDirectoryMock,
  },
}));

mock.module('@/stores/useProjectsStore', () => ({
  useProjectsStore: {
    getState: () => ({
      getActiveProject: () => ({ path: activeProjectPath }),
    }),
  },
}));

mock.module('@/lib/runtime-fetch', () => ({
  runtimeFetch: runtimeFetchMock,
}));

mock.module('@/lib/runtime-switch', () => ({
  getRuntimeTransportIdentity: () => runtimeKey,
}));

mock.module('@/lib/configUpdate', () => ({
  startConfigUpdate: mock(() => undefined),
  finishConfigUpdate: mock(() => undefined),
  updateConfigUpdateMessage: mock(() => undefined),
}));

mock.module('@/lib/configSync', () => ({
  emitConfigChange: mock(() => undefined),
  scopeMatches: mock(() => false),
  subscribeToConfigChanges: mock(() => () => undefined),
}));

const { invalidateCommandsLoadCache, useCommandsStore } = await import('./useCommandsStore');

describe('useCommandsStore', () => {
  beforeEach(() => {
    listCommandsWithDetailsCalls = 0;
    listCommandsWithDetailsImpl = async () => [];
    activeProjectPath = '/workspace/project';
    runtimeKey = 'runtime-a';
    commandRequestDirectory = null;
    withDirectoryImpl = async (directory, callback) => {
      commandRequestDirectory = directory;
      return callback();
    };
    getDirectoryImpl = () => '/fallback/project';
    runtimeFetchCalls = [];
    runtimeFetchImpl = async () => new Response(JSON.stringify({ commands: {} }), {
      headers: { 'Content-Type': 'application/json' },
    });

    useCommandsStore.setState({
      selectedCommandName: null,
      commands: [],
      commandsByCacheKey: {},
      activeCommandsCacheKey: null,
      isLoading: false,
      commandDraft: null,
    });
  });

  test('loadCommands preserves previous commands when the command list fails', async () => {
    const previousCommands = [{
      name: 'existing',
      description: 'Existing command',
      template: 'do the previous thing',
      scope: 'project' as const,
    }];
    useCommandsStore.setState({ commands: previousCommands });
    listCommandsWithDetailsImpl = async () => {
      throw new Error('network down');
    };

    const result = await useCommandsStore.getState().loadCommands();

    expect(result).toBe(false);
    expect(listCommandsWithDetailsCalls).toBe(3);
    expect(useCommandsStore.getState().commands).toEqual(previousCommands);
    expect(useCommandsStore.getState().isLoading).toBe(false);
  });

  test('loads scope metadata for many commands with one batched runtime request', async () => {
    listCommandsWithDetailsImpl = async () => Array.from({ length: 80 }, (_, index) => ({
      name: `command-${index}`,
      description: `Command ${index}`,
      source: 'command',
    }));
    runtimeFetchImpl = async (_input, init) => {
      const body = JSON.parse(String(init?.body)) as { names: string[] };
      return new Response(JSON.stringify({
        commands: Object.fromEntries(body.names.map((name) => [name, { scope: 'project', isBuiltIn: false }])),
      }), { headers: { 'Content-Type': 'application/json' } });
    };

    const result = await useCommandsStore.getState().loadCommands();

    expect(result).toBe(true);
    expect(runtimeFetchCalls).toHaveLength(1);
    expect(runtimeFetchCalls[0]?.input).toBe('/api/config/commands/metadata');
    expect(runtimeFetchCalls[0]?.init?.method).toBe('POST');
    expect(useCommandsStore.getState().commands).toHaveLength(80);
    expect(useCommandsStore.getState().commands.every((command) => command.scope === 'project')).toBe(true);
  });

  test('keeps TTL snapshots isolated by directory and runtime identity', async () => {
    listCommandsWithDetailsImpl = async () => [{
      name: activeProjectPath.endsWith('one') ? 'one' : 'two',
      source: 'command',
    }];

    activeProjectPath = '/workspace/race-one';
    await useCommandsStore.getState().loadCommands();
    expect(useCommandsStore.getState().commands.map((command) => command.name)).toEqual(['one']);

    activeProjectPath = '/workspace/race-two';
    await useCommandsStore.getState().loadCommands();
    expect(useCommandsStore.getState().commands.map((command) => command.name)).toEqual(['two']);

    activeProjectPath = '/workspace/race-one';
    await useCommandsStore.getState().loadCommands();
    expect(useCommandsStore.getState().commands.map((command) => command.name)).toEqual(['one']);
    expect(listCommandsWithDetailsCalls).toBe(2);

    runtimeKey = 'runtime-b';
    await useCommandsStore.getState().loadCommands();
    expect(listCommandsWithDetailsCalls).toBe(3);
    expect(Object.keys(useCommandsStore.getState().commandsByCacheKey)).toHaveLength(3);
  });

  test('keeps the active directory snapshot when an earlier request finishes later', async () => {
    let resolveOne: ((commands: unknown[]) => void) | undefined;
    let resolveTwo: ((commands: unknown[]) => void) | undefined;
    listCommandsWithDetailsImpl = async () => new Promise((resolve) => {
      if (commandRequestDirectory?.endsWith('one')) resolveOne = resolve;
      else resolveTwo = resolve;
    });

    activeProjectPath = '/workspace/concurrent-one';
    const first = useCommandsStore.getState().loadCommands();
    activeProjectPath = '/workspace/concurrent-two';
    const second = useCommandsStore.getState().loadCommands();
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(resolveTwo).toBeDefined();
    resolveTwo!([{ name: 'two', source: 'command' }]);
    await second;
    expect(resolveOne).toBeDefined();
    resolveOne!([{ name: 'one', source: 'command' }]);
    await first;

    expect(useCommandsStore.getState().commands.map((command) => command.name)).toEqual(['two']);
  });

  test('refreshes the displayed snapshot when a command template changes', async () => {
    let template = 'first';
    listCommandsWithDetailsImpl = async () => [{ name: 'deploy', source: 'command', template }];

    await useCommandsStore.getState().loadCommands();
    template = 'second';
    invalidateCommandsLoadCache('/workspace/project');
    await useCommandsStore.getState().loadCommands();

    expect(useCommandsStore.getState().commands[0]?.template).toBe('second');
  });

  test('keeps scope out of PATCH payloads', async () => {
    listCommandsWithDetailsImpl = async () => [];
    runtimeFetchImpl = async () => new Response(JSON.stringify({ requiresReload: false }), {
      headers: { 'Content-Type': 'application/json' },
    });

    await useCommandsStore.getState().updateCommand('deploy', { scope: 'project', template: 'run' });

    const patch = runtimeFetchCalls.find((call) => call.init?.method === 'PATCH');
    expect(JSON.parse(String(patch?.init?.body))).toEqual({ template: 'run' });
  });

  test('keeps the complete scope snapshot stale when metadata refresh fails', async () => {
    invalidateCommandsLoadCache('/workspace/project');
    listCommandsWithDetailsImpl = async () => [{ name: 'deploy', source: 'command' }];
    runtimeFetchImpl = async () => new Response(JSON.stringify({ commands: { deploy: { scope: 'project' } } }), {
      headers: { 'Content-Type': 'application/json' },
    });
    await useCommandsStore.getState().loadCommands();
    runtimeFetchImpl = async () => { throw new Error('metadata unavailable'); };
    invalidateCommandsLoadCache('/workspace/project');

    await useCommandsStore.getState().loadCommands();

    expect(useCommandsStore.getState().commands[0]?.name).toBe('deploy');
    expect(useCommandsStore.getState().commands[0]?.scope).toBe('project');
    await useCommandsStore.getState().loadCommands();
    expect(listCommandsWithDetailsCalls).toBe(3);
  });
});
