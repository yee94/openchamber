import { describe, expect, it, vi } from 'vitest';
import { createStartupPipelineRuntime } from './startup-pipeline-runtime.js';

describe('startup pipeline runtime', () => {
  it('sets the active loopback bridge origin after listen and before bootstrap', async () => {
    const order = [];
    const runtime = createStartupPipelineRuntime({
      createTerminalRuntime: vi.fn(() => ({})), createDictationRuntime: vi.fn(() => ({})), createMessageStreamWsRuntime: vi.fn(() => ({})),
      createServerStartupRuntime: vi.fn(() => ({ resolveBindHost: () => '127.0.0.1', startListeningAndMaybeTunnel: async () => ({ activePort: 41234 }), attachProcessHandlers: vi.fn() })),
    });
    await runtime.run({
      app: {}, server: {}, express: {}, fs: {}, path: {}, uiAuthController: {}, buildAugmentedPath: () => '', searchPathFor: () => '', isExecutable: () => true,
      isRequestOriginAllowed: () => true, rejectWebSocketUpgrade: () => {}, buildOpenCodeUrl: () => '', getOpenCodeAuthHeaders: () => ({}), globalEventHub: {}, processForwardedEventPayload: () => {}, messageStreamWsClients: new Set(), triggerHealthCheck: () => {}, upstreamStallTimeoutMs: 1,
      terminalHeartbeatIntervalMs: 1, terminalRebindWindowMs: 1, terminalMaxRebindsPerWindow: 1, setupProxy: () => {}, scheduleOpenCodeApiDetection: () => {},
      bootstrapOpenCodeAtStartup: () => { order.push('bootstrap'); }, setManagedOpenCodeBridgeOrigin: (origin) => { order.push(origin); },
      staticRoutesRuntime: { registerStaticRoutes: () => {}, registerApiOnlyFallbackRoutes: () => {} }, process: {}, crypto: {}, normalizeTunnelBootstrapTtlMs: () => 1,
      readSettingsFromDiskMigrated: async () => ({}), tunnelAuthController: {}, startTunnelWithNormalizedRequest: () => {}, gracefulShutdown: () => {}, getSignalsAttached: () => false, setSignalsAttached: () => {}, syncToHmrState: () => {},
      TUNNEL_MODE_QUICK: 'quick', TUNNEL_MODE_MANAGED_LOCAL: 'local', TUNNEL_MODE_MANAGED_REMOTE: 'remote', host: '127.0.0.1', port: 0, startupTunnelRequest: null, onTunnelReady: () => {}, tunnelRuntimeContext: { setActivePort: () => {} }, attachSignals: false, apiOnly: false, dictationModelsDir: '',
    });
    expect(order).toEqual(['http://127.0.0.1:41234', 'bootstrap']);
  });
});
