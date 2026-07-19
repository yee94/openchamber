import { runtimeFetch } from '@/lib/runtime-fetch';

type OpenCodeHealth = {
  openCodeRunning?: unknown;
  isOpenCodeReady?: unknown;
};

export async function checkOpenCodeAvailability(): Promise<boolean> {
  const response = await runtimeFetch('/health');
  if (!response.ok) return false;

  const data = (await response.json().catch(() => null)) as OpenCodeHealth | null;
  return data?.openCodeRunning === true || data?.isOpenCodeReady === true;
}

export async function retryOpenCodeAvailability(): Promise<boolean> {
  const response = await runtimeFetch('/api/opencode/retry', { method: 'POST' });
  return response.ok;
}
