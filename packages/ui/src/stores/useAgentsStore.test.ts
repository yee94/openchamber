import { beforeEach, describe, expect, mock, test } from 'bun:test';

let activeProjectPath = '/workspace/project';
let runtimeKey = 'runtime-a';
let listAgentsCalls = 0;
let listAgentsImpl: (directory?: string | null) => Promise<unknown[]> = async () => [];
let metadataFails = false;

mock.module('@/lib/opencode/client', () => ({
  opencodeClient: {
    getDirectory: () => '/fallback/project',
    listAgents: async (directory?: string | null) => {
      listAgentsCalls += 1;
      return listAgentsImpl(directory);
    },
  },
}));

mock.module('@/stores/useProjectsStore', () => ({
  useProjectsStore: { getState: () => ({ getActiveProject: () => ({ path: activeProjectPath }) }) },
}));

mock.module('@/lib/runtime-switch', () => ({ getRuntimeTransportIdentity: () => runtimeKey }));
mock.module('@/lib/runtime-fetch', () => ({
  runtimeFetch: async () => metadataFails
    ? Promise.reject(new Error('metadata unavailable'))
    : new Response(JSON.stringify({ scope: 'project' }), { headers: { 'Content-Type': 'application/json' } }),
}));
mock.module('@/lib/configUpdate', () => ({
  startConfigUpdate: mock(() => undefined), finishConfigUpdate: mock(() => undefined), updateConfigUpdateMessage: mock(() => undefined),
}));
mock.module('@/lib/configSync', () => ({
  emitConfigChange: mock(() => undefined), scopeMatches: mock(() => false), subscribeToConfigChanges: mock(() => () => undefined),
}));
mock.module('@/stores/useConfigStore', () => ({ useConfigStore: { getState: () => ({}) } }));
mock.module('@/stores/useSkillsStore', () => ({
  invalidateSkillsLoadCache: mock(() => undefined), useSkillsStore: { getState: () => ({}) },
}));
mock.module('@/stores/useSkillsCatalogStore', () => ({ useSkillsCatalogStore: { getState: () => ({}) } }));

const { useAgentsStore } = await import('./useAgentsStore');

describe('useAgentsStore', () => {
  beforeEach(() => {
    activeProjectPath = '/workspace/project';
    runtimeKey = 'runtime-a';
    listAgentsCalls = 0;
    metadataFails = false;
    listAgentsImpl = async () => [];
    useAgentsStore.setState({
      selectedAgentName: null,
      agents: [],
      agentsByCacheKey: {},
      activeAgentsCacheKey: null,
      isLoading: false,
      agentDraft: null,
    });
  });

  test('keeps TTL snapshots isolated by directory and runtime identity', async () => {
    listAgentsImpl = async (directory) => [{ name: directory?.endsWith('one') ? 'one' : 'two' }];

    activeProjectPath = '/workspace/race-one';
    await useAgentsStore.getState().loadAgents();
    expect(useAgentsStore.getState().agents.map((agent) => agent.name)).toEqual(['one']);

    activeProjectPath = '/workspace/race-two';
    await useAgentsStore.getState().loadAgents();
    expect(useAgentsStore.getState().agents.map((agent) => agent.name)).toEqual(['two']);

    activeProjectPath = '/workspace/race-one';
    await useAgentsStore.getState().loadAgents();
    expect(useAgentsStore.getState().agents.map((agent) => agent.name)).toEqual(['one']);
    expect(listAgentsCalls).toBe(2);

    runtimeKey = 'runtime-b';
    await useAgentsStore.getState().loadAgents();
    expect(listAgentsCalls).toBe(3);
    expect(Object.keys(useAgentsStore.getState().agentsByCacheKey)).toHaveLength(3);
  });

  test('keeps the active directory snapshot when an earlier request finishes later', async () => {
    let resolveOne: ((agents: unknown[]) => void) | undefined;
    let resolveTwo: ((agents: unknown[]) => void) | undefined;
    listAgentsImpl = async (directory) => new Promise((resolve) => {
      if (directory?.endsWith('one')) resolveOne = resolve;
      else resolveTwo = resolve;
    });

    activeProjectPath = '/workspace/concurrent-one';
    const first = useAgentsStore.getState().loadAgents();
    activeProjectPath = '/workspace/concurrent-two';
    const second = useAgentsStore.getState().loadAgents();
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(resolveTwo).toBeDefined();
    resolveTwo!([{ name: 'two' }]);
    await second;
    expect(resolveOne).toBeDefined();
    resolveOne!([{ name: 'one' }]);
    await first;

    expect(useAgentsStore.getState().agents.map((agent) => agent.name)).toEqual(['two']);
  });

  test('keeps the complete scope snapshot stale when metadata refresh fails', async () => {
    const originalDateNow = Date.now;
    listAgentsImpl = async () => [{ name: 'agent' }];
    await useAgentsStore.getState().loadAgents();
    metadataFails = true;
    Date.now = () => originalDateNow() + 6000;
    try {
      await useAgentsStore.getState().loadAgents();
      expect(useAgentsStore.getState().agents[0]?.name).toBe('agent');
      expect((useAgentsStore.getState().agents[0] as { scope?: string } | undefined)?.scope).toBe('project');
      await useAgentsStore.getState().loadAgents();
      expect(listAgentsCalls).toBe(3);
    } finally {
      Date.now = originalDateNow;
    }
  });
});
