import { useQuery, type QueryClient } from '@tanstack/react-query';
import type { GitHubAuthStatus, RuntimeAPIs } from '@/lib/api/types';
import { queryClient, queryKeys } from '@/lib/queryRuntime';
import { runtimeFetch } from '@/lib/runtime-fetch';
import { getRuntimeTransportIdentity } from '@/lib/runtime-switch';
import { getRegisteredRuntimeAPIs } from '@/contexts/runtimeAPIRegistry';

type GitHubAuthStatusWithError = GitHubAuthStatus & { error?: string };

const resolveRuntimeGitHub = (runtimeGitHub?: RuntimeAPIs['github']): RuntimeAPIs['github'] | undefined =>
  runtimeGitHub ?? getRegisteredRuntimeAPIs()?.github;

const githubAuthQueryKey = (transport = getRuntimeTransportIdentity()) =>
  queryKeys.github.auth(transport);

const fetchGitHubAuthStatus = async (
  runtimeGitHub: RuntimeAPIs['github'] | undefined,
  signal: AbortSignal,
): Promise<GitHubAuthStatus> => {
  if (runtimeGitHub) {
    return runtimeGitHub.authStatus();
  }

  const response = await runtimeFetch('/api/github/auth/status', {
    method: 'GET',
    headers: { Accept: 'application/json' },
    signal,
  });
  const payload = (await response.json().catch(() => null)) as GitHubAuthStatusWithError | null;
  if (!response.ok || !payload) {
    throw new Error(payload?.error || response.statusText || 'Failed to load GitHub status');
  }
  return payload;
};

export const githubAuthQueryOptions = (
  runtimeGitHub?: RuntimeAPIs['github'],
  transport = getRuntimeTransportIdentity(),
) => {
  const capturedRuntimeGitHub = resolveRuntimeGitHub(runtimeGitHub);
  return {
    queryKey: githubAuthQueryKey(transport),
    queryFn: async ({ signal }: { signal: AbortSignal }): Promise<GitHubAuthStatus> =>
      fetchGitHubAuthStatus(capturedRuntimeGitHub, signal),
    retry: 2,
  };
};

const isRuntimeGitHubArg = (
  value: RuntimeAPIs['github'] | { enabled?: boolean } | undefined,
): value is RuntimeAPIs['github'] =>
  Boolean(value) && typeof value === 'object' && 'authStatus' in value;

export const useGitHubAuthQuery = (
  runtimeGitHubOrOptions?: RuntimeAPIs['github'] | { enabled?: boolean },
) => {
  const runtimeGitHub = isRuntimeGitHubArg(runtimeGitHubOrOptions) ? runtimeGitHubOrOptions : undefined;
  const enabled = isRuntimeGitHubArg(runtimeGitHubOrOptions)
    ? undefined
    : (runtimeGitHubOrOptions as { enabled?: boolean } | undefined)?.enabled;
  return useQuery({
    ...githubAuthQueryOptions(runtimeGitHub),
    enabled,
  });
};

export const readGitHubAuthSnapshot = (
  client: Pick<QueryClient, 'getQueryData'> = queryClient,
  transport = getRuntimeTransportIdentity(),
): GitHubAuthStatus | null =>
  (client.getQueryData<GitHubAuthStatus>(githubAuthQueryKey(transport)) ?? null);

export const refreshGitHubAuthQuery = async (
  client: Pick<QueryClient, 'fetchQuery' | 'getQueryData'>,
  runtimeGitHub: RuntimeAPIs['github'] | undefined,
  transport: string,
): Promise<GitHubAuthStatus | null> => {
  if (getRuntimeTransportIdentity() !== transport) {
    return client.getQueryData<GitHubAuthStatus>(githubAuthQueryKey(transport)) ?? null;
  }
  return client.fetchQuery({ ...githubAuthQueryOptions(runtimeGitHub, transport), staleTime: 0 });
};

export const setGitHubAuthSnapshot = (
  client: Pick<QueryClient, 'setQueryData'> = queryClient,
  data: GitHubAuthStatus | null,
  transport = getRuntimeTransportIdentity(),
): void => {
  client.setQueryData(githubAuthQueryKey(transport), data);
};
