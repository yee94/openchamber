import { isElectronShell } from '@/lib/desktop';
import { desktopHostsGet } from '@/lib/desktopHosts';
import { getRuntimeKey, switchRuntimeEndpoint } from '@/lib/runtime-switch';

/**
 * On desktop startup, re-open the E2EE relay tunnel if the default host is a
 * relay host. Relay hosts have no reachable HTTP base, so the Electron shell
 * boots the LOCAL UI and defers reconnection to the renderer: here we read the
 * persisted relay descriptor + client token and activate the tunnel in-process
 * via switchRuntimeEndpoint({ relay }). Direct hosts don't need this — the shell
 * injects their apiBaseUrl/token as window globals before render.
 *
 * Safe to call unconditionally; it is a no-op outside the Electron shell and when
 * the default host is local or already active.
 */
export const restoreDesktopRelayRuntime = async (): Promise<void> => {
  if (!isElectronShell()) return;
  const config = await desktopHostsGet().catch(() => null);
  const defaultHostId = config?.defaultHostId;
  if (!config || !defaultHostId || defaultHostId === 'local') return;
  const host = config.hosts.find((entry) => entry.id === defaultHostId);
  if (!host?.relay) return;
  // Must match runtimeKeyForHost() in DesktopHostSwitcher so switch/resolve agree.
  const runtimeKey = `host:${host.id}`;
  if (getRuntimeKey() === runtimeKey) return;
  switchRuntimeEndpoint({
    apiBaseUrl: typeof window !== 'undefined' ? window.location.origin : '',
    clientToken: host.clientToken || null,
    runtimeKey,
    relay: host.relay,
  });
};
