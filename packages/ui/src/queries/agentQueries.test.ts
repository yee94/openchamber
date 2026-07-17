import { beforeEach, describe, expect, mock, test } from 'bun:test';

let activeProjectPath = '/workspace/project';
let runtimeKey = 'runtime-a';
let listCalls = 0;
let listImpl: () => Promise<Array<{ name: string }>> = async () => [];
let metadataImpl: () => Promise<Response> = async () => new Response(JSON.stringify({ scope: 'project' }));

mock.module('@/lib/opencode/client', () => ({ opencodeClient: { getDirectory: () => '/fallback/project', listAgents: async () => { listCalls += 1; return listImpl(); } } }));
mock.module('@/stores/useProjectsStore', () => ({ useProjectsStore: Object.assign(() => null, { getState: () => ({ getActiveProject: () => ({ path: activeProjectPath }) }) }) }));
mock.module('@/lib/runtime-fetch', () => ({ runtimeFetch: async () => metadataImpl() }));
mock.module('@/lib/runtime-switch', () => ({ getRuntimeTransportIdentity: () => runtimeKey, isRuntimeEndpointIdentityChange: () => false, subscribeRuntimeEndpointChanged: () => () => undefined }));

const { agentQueryOptions, readAgentsSnapshot, refreshAgentsQuery } = await import('./agentQueries');
const { queryClient } = await import('@/lib/queryRuntime');

describe('agentQueries', () => {
  beforeEach(() => {
    queryClient.clear();
    activeProjectPath = '/workspace/project';
    runtimeKey = 'runtime-a';
    listCalls = 0;
    listImpl = async () => [];
    metadataImpl = async () => new Response(JSON.stringify({ scope: 'project' }));
  });

  test('loads metadata and retains the complete snapshot when metadata fails', async () => {
    listImpl = async () => [{ name: 'deploy' }];
    await refreshAgentsQuery(queryClient, activeProjectPath, runtimeKey);
    metadataImpl = async () => { throw new Error('metadata unavailable'); };
    await expect(refreshAgentsQuery(queryClient, activeProjectPath, runtimeKey)).rejects.toThrow('metadata unavailable');
    expect(readAgentsSnapshot()[0]?.name).toBe('deploy');
    expect((readAgentsSnapshot()[0] as { scope?: string } | undefined)?.scope).toBe('project');
  });

  test('isolates query keys and skips inactive runtime refreshes', async () => {
    listImpl = async () => [{ name: `${runtimeKey}:${activeProjectPath}` }];
    await Promise.all([refreshAgentsQuery(queryClient, activeProjectPath, runtimeKey), refreshAgentsQuery(queryClient, activeProjectPath, runtimeKey)]);
    activeProjectPath = '/workspace/second';
    await refreshAgentsQuery(queryClient, activeProjectPath, runtimeKey);
    runtimeKey = 'runtime-b';
    await refreshAgentsQuery(queryClient, activeProjectPath, 'runtime-a');
    expect(listCalls).toBe(2);
    expect(agentQueryOptions(activeProjectPath).queryKey).toEqual(['runtime-b', 'agents', '/workspace/second']);
  });
});
