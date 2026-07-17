import { beforeEach, describe, expect, mock, test } from 'bun:test';

let activeProjectPath = '/workspace/project';
let runtimeKey = 'runtime-a';
type FetchCall = { input: string; init?: RequestInit };
const fetchCalls: FetchCall[] = [];
let fetchImpl: (input: string, init?: RequestInit) => Promise<Response> = async () => new Response('{}');

mock.module('@/lib/opencode/client', () => ({ opencodeClient: { getDirectory: () => '/fallback/project' } }));
mock.module('@/stores/useProjectsStore', () => ({
  useProjectsStore: Object.assign(() => null, { getState: () => ({ getActiveProject: () => ({ path: activeProjectPath }) }) }),
}));
mock.module('@/lib/runtime-fetch', () => ({
  runtimeFetch: (input: string, init?: RequestInit) => {
    fetchCalls.push({ input, init });
    return fetchImpl(input, init);
  },
}));
mock.module('@/lib/runtime-switch', () => ({
  getRuntimeTransportIdentity: () => runtimeKey,
  isRuntimeEndpointIdentityChange: () => false,
  subscribeRuntimeEndpointChanged: () => () => undefined,
}));

const {
  pluginFileQueryOptions,
  pluginRegistryQueryOptions,
  pluginsListQueryOptions,
  readPluginRegistrySnapshot,
  refreshPluginRegistryQuery,
  refreshPluginsListQuery,
} = await import('./pluginQueries');
const { queryClient, queryKeys } = await import('@/lib/queryRuntime');

const jsonResponse = (body: unknown, init?: ResponseInit): Response => new Response(JSON.stringify(body), {
  status: init?.status ?? 200,
  headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
});

describe('pluginQueries', () => {
  beforeEach(() => {
    queryClient.clear();
    activeProjectPath = '/workspace/project';
    runtimeKey = 'runtime-a';
    fetchCalls.length = 0;
    fetchImpl = async () => jsonResponse({});
  });

  test('list request scopes directory, runtime, and abort signal', async () => {
    const controller = new AbortController();
    fetchImpl = async () => jsonResponse({ entries: [], files: [] });

    await pluginsListQueryOptions(' /workspace/a ', 'runtime-b').queryFn({ signal: controller.signal });

    expect(pluginsListQueryOptions(' /workspace/a ', 'runtime-b').queryKey).toEqual(['runtime-b', 'plugins', 'list', '/workspace/a']);
    expect(fetchCalls[0]?.input).toBe('/api/config/plugins?directory=%2Fworkspace%2Fa');
    expect(fetchCalls[0]?.init?.headers).toEqual({ 'x-opencode-directory': '/workspace/a' });
    expect(fetchCalls[0]?.init?.signal).toBe(controller.signal);
  });

  test('registry keys canonicalize specs and isolate distinct spec sets', () => {
    expect(queryKeys.plugins.registry('/workspace/a', [' b ', 'a', 'a'], false, 'runtime-a')).toEqual([
      'runtime-a', 'plugins', 'registry', '/workspace/a', ['a', 'b'], false,
    ]);
    expect(pluginRegistryQueryOptions('/workspace/a', ['a'], false, 'runtime-a').queryKey)
      .not.toEqual(pluginRegistryQueryOptions('/workspace/a', ['b'], false, 'runtime-a').queryKey);
  });

  test('registry preserves URL semantics, chunks long spec lists, and aggregates results', async () => {
    const specs = Array.from({ length: 50 }, (_, index) => `plugin-${index}-${'x'.repeat(20)}@1.0.0`);
    fetchImpl = async (input) => jsonResponse({
      results: [{ kind: 'npm-ok', spec: new URL(`http://localhost${input}`).searchParams.get('specs')?.split(',')[0] ?? '', name: 'plugin', currentVersion: null, latestVersion: null, versions: [], hasUpdate: false }],
    });

    const registry = await pluginRegistryQueryOptions('/workspace/a', specs, true).queryFn({ signal: new AbortController().signal });

    expect(fetchCalls).toHaveLength(2);
    expect(fetchCalls[0]?.input).toContain('refresh=true');
    expect(fetchCalls[0]?.input).toContain('directory=%2Fworkspace%2Fa');
    expect(Object.keys(registry)).toHaveLength(2);
  });

  test('registry failure keeps the prior complete snapshot', async () => {
    fetchImpl = async () => jsonResponse({
      results: [{ kind: 'npm-ok', spec: 'plugin-a', name: 'plugin-a', currentVersion: null, latestVersion: null, versions: [], hasUpdate: false }],
    });
    await refreshPluginRegistryQuery(queryClient, activeProjectPath, ['plugin-a'], false, runtimeKey);
    fetchImpl = async () => jsonResponse({}, { status: 500 });

    await expect(queryClient.fetchQuery({ ...pluginRegistryQueryOptions(activeProjectPath, ['plugin-a'], false, runtimeKey), staleTime: 0, retry: false })).rejects.toThrow('Failed to load plugin registry info');

    expect(readPluginRegistrySnapshot(activeProjectPath, ['plugin-a'], false, runtimeKey)['plugin-a']?.kind).toBe('npm-ok');
  });

  test('file request reads directory-scoped content and forwards its signal', async () => {
    const controller = new AbortController();
    fetchImpl = async () => jsonResponse({ fileName: 'plugin.ts', scope: 'project', content: 'export {}' });

    const file = await pluginFileQueryOptions('/workspace/a', 'file:user:plugin.ts').queryFn({ signal: controller.signal });

    expect(file).toEqual({ fileName: 'plugin.ts', scope: 'project', content: 'export {}' });

    expect(fetchCalls[0]?.input).toBe('/api/config/plugins/file/file%3Auser%3Aplugin.ts?directory=%2Fworkspace%2Fa');
    expect(fetchCalls[0]?.init?.signal).toBe(controller.signal);
  });

  test('matching list refreshes share one flight and inactive runtimes retain their snapshot', async () => {
    let resolveResponse: ((response: Response) => void) | undefined;
    fetchImpl = async () => new Promise<Response>((resolve) => { resolveResponse = resolve; });
    const first = refreshPluginsListQuery(queryClient, activeProjectPath, runtimeKey);
    const second = refreshPluginsListQuery(queryClient, activeProjectPath, runtimeKey);
    resolveResponse?.(jsonResponse({ entries: [], files: [] }));
    await Promise.all([first, second]);

    runtimeKey = 'runtime-b';
    await refreshPluginsListQuery(queryClient, activeProjectPath, 'runtime-a');

    expect(fetchCalls).toHaveLength(1);
    expect(fetchCalls[0]?.init?.signal).toBeInstanceOf(AbortSignal);
  });
});
