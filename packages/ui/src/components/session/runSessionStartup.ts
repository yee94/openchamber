import { releaseSessionStartupBarrier } from '@/lib/session-startup-barrier';
import { startGlobalSessionIndexStartup } from '@/stores/useGlobalSessionsStore';

export const runSessionStartup = async (
  directories: string[],
  start = startGlobalSessionIndexStartup,
): Promise<void> => {
  try {
    await start(directories);
  } catch (error) {
    console.warn('[SessionStartup] Initial session index sync failed:', error);
  } finally {
    releaseSessionStartupBarrier();
  }
};
