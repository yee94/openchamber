import { expect, test } from 'bun:test';
import { createMessageQueueServerRuntime } from './message-queue-server-runtime';

const descriptor = { scopeID: 'scope-a', revision: 1, directory: '/repo', sessionID: 'session-a', worktreeState: 'active', itemCount: 1 };
const item = { queueItemID: 'queue-a', operationID: 'operation-a', messageID: 'msg_a', content: 'queued', status: 'queued', attemptCount: 0, position: 0, rowVersion: 1, createdAt: 1 };

test('writes successful status, catalog, and complete scope into transport Query keys', async () => {
  const cache = new Map<string, unknown>();
  const client = {
    setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value),
    getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined,
    removeQueries: ({ queryKey }: { queryKey: readonly unknown[] }) => { for (const key of cache.keys()) if (key.startsWith(JSON.stringify(queryKey).slice(0, -1))) cache.delete(key); },
    invalidateQueries: async () => {},
  };
  const runtime = createMessageQueueServerRuntime({ client: client as never, capture: () => ({ transportIdentity: 'device-a', generation: 1 }), current: () => true, status: async () => ({ capability: true, authority: 'shadow' }), snapshot: async () => ({ revision: 1, scopes: [descriptor], worktreeOrders: [] }), scope: async () => ({ ...descriptor, items: [item] }) });
  await runtime.refresh();
  expect(cache.get(JSON.stringify(['device-a', 'messageQueue', 'status']))).toEqual({ capability: true, authority: 'shadow' });
  expect(cache.get(JSON.stringify(['device-a', 'messageQueue', 'snapshot']))).toEqual({ revision: 1, scopes: [descriptor], worktreeOrders: [] });
  const first = runtime.getScope({ transportIdentity: 'device-a', directory: '/repo', sessionID: 'session-a' });
  expect(first?.items).toEqual([item]);
  expect(runtime.getScope({ transportIdentity: 'device-a', directory: '/repo', sessionID: 'session-a' })).toBe(first);
});

test('successful empty catalog clears descriptors while a failed refresh keeps the prior complete scope', async () => {
  let empty = false, fail = false;
  const cache = new Map<string, unknown>();
  const client = { setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value), getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined, removeQueries: () => {}, invalidateQueries: async () => {} };
  const runtime = createMessageQueueServerRuntime({ client: client as never, capture: () => ({ transportIdentity: 'device-a', generation: 1 }), current: () => true, status: async () => ({ capability: true }), snapshot: async () => { if (fail) throw new Error('offline'); return { revision: empty ? 2 : 1, scopes: empty ? [] : [descriptor], worktreeOrders: [] }; }, scope: async () => ({ ...descriptor, items: [item] }) });
  await runtime.refresh();
  fail = true; await runtime.refresh();
  expect(runtime.getScope({ transportIdentity: 'device-a', directory: '/repo', sessionID: 'session-a' })?.items).toEqual([item]);
  fail = false; empty = true; await runtime.refresh();
  expect(runtime.getState().scopes.size).toBe(0);
});

test('direct capture identity changes clear A descriptors and scope snapshots before restart', async () => {
  let identity = 'A', generation = 1;
  const cache = new Map<string, unknown>();
  const client = { setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value), getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined, removeQueries: () => {}, invalidateQueries: async () => {} };
  const runtime = createMessageQueueServerRuntime({ client: client as never, capture: () => ({ transportIdentity: identity, generation }), current: () => true, status: async () => ({ capability: true }), snapshot: async () => ({ revision: 1, scopes: [descriptor], worktreeOrders: [] }), scope: async () => ({ ...descriptor, items: [item] }) });
  await runtime.refresh();
  expect(runtime.getScope({ transportIdentity: 'A', directory: '/repo', sessionID: 'session-a' })?.items).toEqual([item]);
  identity = 'B'; generation++;
  expect(runtime.getScope({ transportIdentity: 'B', directory: '/repo', sessionID: 'session-a' })).toBe(undefined);
  expect(runtime.getState().transportIdentity).toBe('B');
  expect(runtime.getState().scopes.size).toBe(0);
});

test('restart reloads the active transport after an A to B switch', async () => {
  let identity = 'A', generation = 1;
  const cache = new Map<string, unknown>();
  const client = { setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value), getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined, removeQueries: () => {}, invalidateQueries: async () => {} };
  const runtime = createMessageQueueServerRuntime({ client: client as never, capture: () => ({ transportIdentity: identity, generation }), current: () => true, status: async () => ({ capability: true }), snapshot: async () => ({ revision: 1, scopes: [descriptor], worktreeOrders: [] }), scope: async () => ({ ...descriptor, items: [{ ...item, content: identity }] }) });
  await runtime.refresh(); identity = 'B'; generation++; runtime.restart(); await runtime.refresh();
  expect(runtime.getScope({ transportIdentity: 'B', directory: '/repo', sessionID: 'session-a' })?.items[0]?.content).toBe('B');
});

test('an A mutation completion cannot publish into B state', async () => {
  let identity = 'A', generation = 1, release: (() => void) | undefined;
  const cache = new Map<string, unknown>();
  const client = { setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value), getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined, removeQueries: () => {}, invalidateQueries: async () => {} };
  const runtime = createMessageQueueServerRuntime({ client: client as never, capture: () => ({ transportIdentity: identity, generation }), current: () => true, status: async () => ({ capability: true }), snapshot: async () => ({ revision: 1, scopes: [descriptor], worktreeOrders: [] }), scope: async () => ({ ...descriptor, items: [item] }), edit: async () => { await new Promise<void>((resolve) => { release = resolve; }); return { revision: 2 }; } });
  await runtime.refresh();
  const pending = runtime.edit({ requestID: 'edit', scopeID: descriptor.scopeID, revision: 1, item, patch: { content: 'edited' } });
  identity = 'B'; generation++; runtime.getState(); release?.();
  expect(await pending).toEqual({ status: 'stale' });
  expect(runtime.getScope({ transportIdentity: 'B', directory: '/repo', sessionID: 'session-a' })).toBe(undefined);
});

test('treats a mismatched renew acknowledgement as stale', async () => {
  const runtime = createMessageQueueServerRuntime({ capture: () => ({ transportIdentity: 'device-a', generation: 1 }), current: () => true, renew: async () => ({ queueItemID: 'queue-other', token: 'token', generation: 1, expiresAt: 2 }) } as never);
  expect(await runtime.renewEdit({ item, token: 'token', generation: 1, ttlMs: 1_000, runtime: { transportIdentity: 'device-a', generation: 1 } })).toBe(undefined);
});

test('sends paused authority through the server CAS and reserves legacy send for shadow authority', async () => {
  const cache = new Map<string, unknown>();
  const client = { setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value), getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined, removeQueries: () => {}, invalidateQueries: async () => {} };
  let scopeRevision = 1, serverCalls = 0, legacyCalls = 0;
  const paused = createMessageQueueServerRuntime({ client: client as never, capture: () => ({ transportIdentity: 'device-a', generation: 1 }), current: () => true, status: async () => ({ capability: true, authority: 'paused' }), snapshot: async () => ({ revision: scopeRevision, scopes: [{ ...descriptor, revision: scopeRevision }], worktreeOrders: [] }), scope: async () => ({ ...descriptor, revision: scopeRevision, items: [item] }), manualSend: async () => { serverCalls++; scopeRevision = 2; return { revision: 2 }; }, legacyManualSend: async () => { legacyCalls++; } });
  await paused.refresh();
  expect((await paused.manualSend({ requestID: 'paused-send', scopeID: descriptor.scopeID, revision: 1, item })).status).toBe('committed');
  expect({ serverCalls, legacyCalls }).toEqual({ serverCalls: 1, legacyCalls: 0 });

  const shadow = createMessageQueueServerRuntime({ capture: () => ({ transportIdentity: 'device-a', generation: 1 }), current: () => true, status: async () => ({ capability: true, authority: 'shadow' }), manualSend: async () => { serverCalls++; return { revision: 1 }; }, legacyManualSend: async () => { legacyCalls++; } });
  await shadow.refresh();
  expect((await shadow.manualSend({ requestID: 'shadow-send', scopeID: descriptor.scopeID, revision: 1, item })).status).toBe('committed');
  expect({ serverCalls, legacyCalls }).toEqual({ serverCalls: 1, legacyCalls: 1 });
});
