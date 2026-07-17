import { QueryClient } from '@tanstack/react-query';
import type { ProviderResult, QuotaProviderId } from '@/types';
import { runtimeFetch } from '@/lib/runtime-fetch';
import { getRuntimeTransportIdentity, isRuntimeEndpointIdentityChange, subscribeRuntimeEndpointChanged } from './runtime-switch';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      gcTime: 5 * 60_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

export const queryKeys = {
  runtime: (): readonly [string] => [getRuntimeTransportIdentity()],
  scoped: <T extends ReadonlyArray<unknown>>(...parts: T): readonly [string, ...T] => [getRuntimeTransportIdentity(), ...parts],
  quota: (providerId: QuotaProviderId): readonly [string, QuotaProviderId] => [getRuntimeTransportIdentity(), providerId],
  commands: {
    list: (directory: string | null, transport = getRuntimeTransportIdentity()): readonly [string, 'commands', string | null] => [transport, 'commands', directory],
  },
  agents: {
    list: (directory: string | null, transport = getRuntimeTransportIdentity()): readonly [string, 'agents', string | null] => [transport, 'agents', directory],
  },
};

export const fetchQuotaProvider = async (
  providerId: QuotaProviderId,
  signal: AbortSignal,
): Promise<ProviderResult> => {
  const response = await runtimeFetch(`/api/quota/${encodeURIComponent(providerId)}`, { signal });
  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    throw new Error(payload?.error || 'Failed to fetch quota');
  }
  return payload as ProviderResult;
};

export const installQueryRuntimeLifecycle = (client: Pick<QueryClient, 'clear'>): (() => void) => (
  subscribeRuntimeEndpointChanged((detail) => {
    if (isRuntimeEndpointIdentityChange(detail)) {
      client.clear();
    }
  })
);
