import { infiniteQueryOptions, useInfiniteQuery, useQuery, type InfiniteData, type QueryClient } from '@tanstack/react-query';
import { queryClient, queryKeys } from '@/lib/queryRuntime';
import { runtimeFetch } from '@/lib/runtime-fetch';
import { getRuntimeTransportIdentity } from '@/lib/runtime-switch';
import { opencodeClient } from '@/lib/opencode/client';
import { useProjectsStore } from '@/stores/useProjectsStore';
import type { SkillsCatalogItem, SkillsCatalogResponse, SkillsCatalogSource, SkillsCatalogSourceResponse } from '@/lib/api/types';

export const FALLBACK_SKILLS_CATALOG_SOURCES: SkillsCatalogSource[] = [
  {
    id: 'anthropic',
    label: 'Anthropic',
    description: "Anthropic's public skills repository",
    source: 'anthropics/skills',
    defaultSubpath: 'skills',
    sourceType: 'github',
  },
  {
    id: 'clawdhub',
    label: 'ClawdHub',
    description: 'Community skill registry with vector search',
    source: 'clawdhub:registry',
    sourceType: 'clawdhub',
  },
];

type SkillsCatalogSourcePage = { items: SkillsCatalogItem[]; nextCursor: string | null };

const normalizeDirectory = (directory: string | null | undefined): string | null => directory?.trim() || null;

export const resolveSkillsCatalogQueryDirectory = (): string | null => {
  const activeProject = useProjectsStore.getState().getActiveProject?.();
  return normalizeDirectory(activeProject?.path) ?? normalizeDirectory(opencodeClient.getDirectory());
};

const sourcesQueryKey = (directory: string | null, transport = getRuntimeTransportIdentity()) =>
  queryKeys.skillsCatalog.sources(directory, transport);

const sourceQueryKey = (directory: string | null, sourceId: string, transport = getRuntimeTransportIdentity()) =>
  queryKeys.skillsCatalog.source(directory, sourceId, transport);

const sourceRefreshGenerations = new Map<string, number>();

export const skillsCatalogSourcesQueryOptions = (
  directory: string | null = resolveSkillsCatalogQueryDirectory(),
  transport = getRuntimeTransportIdentity(),
  refresh = false,
) => {
  const normalizedDirectory = normalizeDirectory(directory);
  return {
    queryKey: sourcesQueryKey(normalizedDirectory, transport),
    queryFn: ({ signal }: { signal: AbortSignal }) => fetchSkillsCatalogSources(normalizedDirectory, refresh, signal),
    staleTime: 5_000,
    retry: 2,
  };
};

export const skillsCatalogSourceInfiniteQueryOptions = (
  directory: string | null,
  sourceId: string,
  transport = getRuntimeTransportIdentity(),
  refresh = false,
) => {
  const normalizedDirectory = normalizeDirectory(directory);
  return infiniteQueryOptions({
    queryKey: sourceQueryKey(normalizedDirectory, sourceId, transport),
    queryFn: ({ signal, pageParam }) => fetchSkillsCatalogSource(normalizedDirectory, sourceId, pageParam, refresh, signal),
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage, allPages) => getNextSkillsCatalogSourceCursor(lastPage, allPages),
    staleTime: 5_000,
    retry: 2,
  });
};

export const useSkillsCatalogSourcesQuery = (options: { enabled?: boolean } = {}) => {
  const activeProjectPath = useProjectsStore((state) => state.getActiveProject?.()?.path ?? null);
  return useQuery({
    ...skillsCatalogSourcesQueryOptions(normalizeDirectory(activeProjectPath) ?? normalizeDirectory(opencodeClient.getDirectory())),
    enabled: options.enabled,
  });
};

export const useSkillsCatalogSourceInfiniteQuery = (sourceId: string, options: { enabled?: boolean } = {}) => {
  const activeProjectPath = useProjectsStore((state) => state.getActiveProject?.()?.path ?? null);
  return useInfiniteQuery({
    ...skillsCatalogSourceInfiniteQueryOptions(normalizeDirectory(activeProjectPath) ?? normalizeDirectory(opencodeClient.getDirectory()), sourceId),
    enabled: options.enabled && Boolean(sourceId),
  });
};

export const flattenSkillsCatalogSourcePages = (pages: readonly SkillsCatalogSourcePage[]): SkillsCatalogItem[] => {
  const items = new Map<string, SkillsCatalogItem>();
  for (const page of pages) {
    for (const item of page.items) items.set(`${item.sourceId}:${item.skillDir}`, item);
  }
  return Array.from(items.values());
};

export const readSkillsCatalogSourcesSnapshot = (
  client: Pick<QueryClient, 'getQueryData'> = queryClient,
  directory: string | null = resolveSkillsCatalogQueryDirectory(),
  transport = getRuntimeTransportIdentity(),
): SkillsCatalogSource[] => client.getQueryData<SkillsCatalogSource[]>(sourcesQueryKey(normalizeDirectory(directory), transport)) ?? FALLBACK_SKILLS_CATALOG_SOURCES;

const readSkillsCatalogSourceSnapshot = (
  client: Pick<QueryClient, 'getQueryData'> = queryClient,
  directory: string | null,
  sourceId: string,
  transport = getRuntimeTransportIdentity(),
): InfiniteData<SkillsCatalogSourcePage, string | null> | undefined =>
  client.getQueryData<InfiniteData<SkillsCatalogSourcePage, string | null>>(sourceQueryKey(normalizeDirectory(directory), sourceId, transport));

export const refreshSkillsCatalogSourcesQuery = async (
  client: Pick<QueryClient, 'fetchQuery' | 'getQueryData'>,
  directory: string | null,
  transport: string,
): Promise<SkillsCatalogSource[]> => {
  const normalizedDirectory = normalizeDirectory(directory);
  if (getRuntimeTransportIdentity() !== transport) return readSkillsCatalogSourcesSnapshot(client, normalizedDirectory, transport);
  return client.fetchQuery({ ...skillsCatalogSourcesQueryOptions(normalizedDirectory, transport, true), staleTime: 0 });
};

export const refreshSkillsCatalogSourceQuery = async (
  client: Pick<QueryClient, 'cancelQueries' | 'setQueryData' | 'getQueryData'>,
  directory: string | null,
  sourceId: string,
  transport: string,
): Promise<InfiniteData<SkillsCatalogSourcePage, string | null> | undefined> => {
  const normalizedDirectory = normalizeDirectory(directory);
  if (getRuntimeTransportIdentity() !== transport) return readSkillsCatalogSourceSnapshot(client, normalizedDirectory, sourceId, transport);
  const key = sourceQueryKey(normalizedDirectory, sourceId, transport);
  const generationKey = JSON.stringify(key);
  const generation = (sourceRefreshGenerations.get(generationKey) ?? 0) + 1;
  sourceRefreshGenerations.set(generationKey, generation);
  await client.cancelQueries({ queryKey: key, exact: true });
  const page = await fetchSkillsCatalogSource(normalizedDirectory, sourceId, null, true, new AbortController().signal);
  if (getRuntimeTransportIdentity() !== transport || sourceRefreshGenerations.get(generationKey) !== generation) {
    return readSkillsCatalogSourceSnapshot(client, normalizedDirectory, sourceId, transport);
  }
  const data = { pages: [page], pageParams: [null] };
  client.setQueryData(key, data);
  return data;
};

export const invalidateSkillsCatalogQueries = (
  client: Pick<QueryClient, 'invalidateQueries'>,
  directory: string | null,
  transport: string,
) => Promise.all([
  client.invalidateQueries({ queryKey: sourcesQueryKey(normalizeDirectory(directory), transport) }),
  client.invalidateQueries({ queryKey: [transport, 'skillsCatalog', 'source', normalizeDirectory(directory)], exact: false }),
]);

async function fetchSkillsCatalogSources(directory: string | null, refresh: boolean, signal: AbortSignal): Promise<SkillsCatalogSource[]> {
  const response = await fetchWithTimeout(buildCatalogUrl('/api/config/skills/catalog', { directory, refresh }), signal);
  const payload = await response.json().catch(() => null) as SkillsCatalogResponse | null;
  if (!response.ok || !payload?.ok) throw new Error(payload?.error?.message ?? `Failed to load catalog (${response.status})`);
  return payload.sources?.length ? payload.sources : FALLBACK_SKILLS_CATALOG_SOURCES;
}

async function fetchSkillsCatalogSource(directory: string | null, sourceId: string, cursor: string | null, refresh: boolean, signal: AbortSignal): Promise<SkillsCatalogSourcePage> {
  const params = { directory, sourceId, cursor, refresh };
  const response = await fetchWithTimeout(buildCatalogUrl('/api/config/skills/catalog/source', params), signal);
  const payload = await response.json().catch(() => null) as SkillsCatalogSourceResponse | null;
  if (response.ok && (payload?.ok || Array.isArray(payload?.items))) return { items: payload.items ?? [], nextCursor: payload.nextCursor ?? null };

  const fallback = await fetchWithTimeout(buildCatalogUrl('/api/config/skills/catalog', params), signal);
  const fallbackPayload = await fallback.json().catch(() => null) as SkillsCatalogResponse | null;
  const items = fallbackPayload?.itemsBySource?.[sourceId];
  if (fallback.ok && fallbackPayload?.ok && Array.isArray(items)) return { items, nextCursor: null };
  throw new Error(payload?.error?.message ?? fallbackPayload?.error?.message ?? `Failed to load catalog source (${response.status})`);
}

function getNextSkillsCatalogSourceCursor(lastPage: SkillsCatalogSourcePage, allPages: SkillsCatalogSourcePage[]): string | undefined {
  const cursor = lastPage.nextCursor;
  if (!cursor || lastPage.items.length === 0) return undefined;
  const priorPages = allPages.slice(0, -1);
  if (priorPages.some((page) => page.nextCursor === cursor)) return undefined;
  return cursor;
}

function buildCatalogUrl(path: string, params: { directory: string | null; sourceId?: string; cursor?: string | null; refresh: boolean }): string {
  const query = new URLSearchParams();
  if (params.directory) query.set('directory', params.directory);
  if (params.sourceId) query.set('sourceId', params.sourceId);
  if (params.cursor) query.set('cursor', params.cursor);
  if (params.refresh) query.set('refresh', 'true');
  const suffix = query.toString();
  return suffix ? `${path}?${suffix}` : path;
}

async function fetchWithTimeout(url: string, signal: AbortSignal): Promise<Response> {
  const timeout = new AbortController();
  const timeoutId = setTimeout(() => timeout.abort(), 3_000);
  try {
    return await runtimeFetch(url, { method: 'GET', headers: { Accept: 'application/json' }, signal: AbortSignal.any([signal, timeout.signal]) });
  } finally {
    clearTimeout(timeoutId);
  }
}
