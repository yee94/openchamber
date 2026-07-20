import { expect, test } from 'bun:test';
import { MessageQueueServerError } from '@/lib/message-queue-server';
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

test('does not repeat a committed mutation when the worker advances the scope before refresh', async () => {
  const cache = new Map<string, unknown>();
  const client = { setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value), getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined, removeQueries: () => {}, invalidateQueries: async () => {} };
  let scopeRevision = 1, mutationCalls = 0;
  const runtime = createMessageQueueServerRuntime({
    client: client as never,
    capture: () => ({ transportIdentity: 'device-a', generation: 1 }),
    current: () => true,
    status: async () => ({ capability: true, authority: 'paused' }),
    snapshot: async () => ({ revision: scopeRevision, scopes: [{ ...descriptor, revision: scopeRevision }], worktreeOrders: [] }),
    scope: async () => ({ ...descriptor, revision: scopeRevision, items: [{ ...item, rowVersion: scopeRevision }] }),
    manualSend: async () => { mutationCalls++; scopeRevision = 2; queueMicrotask(() => { scopeRevision = 3; }); return { revision: 2 }; },
  });
  await runtime.refresh();

  const result = await runtime.manualSend({ requestID: 'send-once', scopeID: descriptor.scopeID, revision: 1, item });

  expect(result.status).toBe('committed');
  expect(result.scope?.revision).toBe(3);
  expect(mutationCalls).toBe(1);
});

test('manual send reconciles the latest snapshot so a worker bump cannot empty the chip list', async () => {
  const cache = new Map<string, unknown>();
  const client = { setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value), getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined, removeQueries: () => {}, invalidateQueries: async () => {} };
  const tail = { ...item, queueItemID: 'queue-b', operationID: 'operation-b', messageID: 'msg_b', content: 'tail', position: 1 };
  let revision = 1;
  const runtime = createMessageQueueServerRuntime({
    client: client as never,
    capture: () => ({ transportIdentity: 'device-a', generation: 1 }),
    current: () => true,
    status: async () => ({ capability: true, authority: 'active' }),
    snapshot: async () => ({ revision, scopes: [{ ...descriptor, revision, itemCount: 2 }], worktreeOrders: [] }),
    scope: async () => ({
      ...descriptor,
      revision,
      itemCount: 2,
      items: revision >= 2
        ? [{ ...tail, position: 0, status: 'sending' as const }, { ...item, position: 1 }]
        : [item, tail],
    }),
    manualSend: async () => {
      revision = 2;
      return { revision: 2 };
    },
  });
  await runtime.refresh();
  expect(runtime.getScope({ transportIdentity: 'device-a', directory: '/repo', sessionID: 'session-a' })?.items.map((entry) => entry.queueItemID)).toEqual(['queue-a', 'queue-b']);
  const result = await runtime.manualSend({ requestID: 'cut-in', scopeID: descriptor.scopeID, revision: 1, item: tail });
  expect(result.status).toBe('committed');
  expect(result.scope?.items.map((entry) => entry.queueItemID)).toEqual(['queue-b', 'queue-a']);
  expect(result.scope?.items[0]?.status).toBe('sending');
});

test('failed manual send reloads the authoritative scope instead of leaving an empty chip list', async () => {
  const cache = new Map<string, unknown>();
  const client = { setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value), getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined, removeQueries: () => {}, invalidateQueries: async () => {} };
  const tail = { ...item, queueItemID: 'queue-b', operationID: 'operation-b', messageID: 'msg_b', content: 'tail', position: 1 };
  let revision = 1;
  const runtime = createMessageQueueServerRuntime({
    client: client as never,
    capture: () => ({ transportIdentity: 'device-a', generation: 1 }),
    current: () => true,
    status: async () => ({ capability: true, authority: 'active' }),
    snapshot: async () => ({ revision, scopes: [{ ...descriptor, revision, itemCount: 2 }], worktreeOrders: [] }),
    scope: async () => ({ ...descriptor, revision, itemCount: 2, items: [item, tail] }),
    manualSend: async () => {
      revision = 2;
      throw new MessageQueueServerError(409, 'scope_locked');
    },
  });
  await runtime.refresh();
  await expect(runtime.manualSend({ requestID: 'cut-in-fail', scopeID: descriptor.scopeID, revision: 1, item: tail })).rejects.toMatchObject({ code: 'scope_locked' });
  // Failure still reloads from the latest snapshot so chips match the server.
  expect(runtime.getState().scopes.get(descriptor.scopeID)?.revision).toBe(2);
  expect(runtime.getScope({ transportIdentity: 'device-a', directory: '/repo', sessionID: 'session-a' })?.items.map((entry) => entry.queueItemID)).toEqual(['queue-a', 'queue-b']);
});

test('observer leading pull applies a newer snapshot after a tip without another wait', async () => {
  const cache = new Map<string, unknown>();
  const client = { setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value), getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined, removeQueries: () => {}, invalidateQueries: async () => {} };
  let revision = 1;
  let waits = 0;
  let releaseWait = () => {};
  let gate = Promise.resolve();
  const runtime = createMessageQueueServerRuntime({
    client: client as never,
    capture: () => ({ transportIdentity: 'device-a', generation: 1 }),
    current: () => true,
    status: async () => ({ capability: true, authority: 'active' }),
    snapshot: async () => ({ revision, scopes: [{ ...descriptor, revision, itemCount: revision === 1 ? 1 : 0 }], worktreeOrders: [] }),
    scope: async () => ({ ...descriptor, revision, itemCount: revision === 1 ? 1 : 0, items: revision === 1 ? [item] : [] }),
    waitInvalidation: async () => {
      waits += 1;
      await gate;
      return waits === 1 ? 'tip' : 'aborted';
    },
  });
  await runtime.refresh();
  expect(runtime.getScope({ transportIdentity: 'device-a', directory: '/repo', sessionID: 'session-a' })?.items).toEqual([item]);
  gate = new Promise<void>((resolve) => { releaseWait = resolve; });
  runtime.start();
  for (let i = 0; i < 100 && waits < 1; i++) await Promise.resolve();
  expect(waits).toBe(1);
  // Server advanced while the observer was between applies; the next leading GET
  // must clear the completed row when the tip wait unblocks.
  revision = 2;
  releaseWait();
  for (let i = 0; i < 100 && (runtime.getScope({ transportIdentity: 'device-a', directory: '/repo', sessionID: 'session-a' })?.items.length ?? -1) !== 0; i++) await Promise.resolve();
  expect(runtime.getScope({ transportIdentity: 'device-a', directory: '/repo', sessionID: 'session-a' })?.items).toEqual([]);
  runtime.stop();
});

test('remove treats authoritative not_found as committed after scope reload', async () => {
  const cache = new Map<string, unknown>();
  const client = { setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value), getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined, removeQueries: () => {}, invalidateQueries: async () => {} };
  let revision = 1;
  let removeCalls = 0;
  const runtime = createMessageQueueServerRuntime({
    client: client as never,
    capture: () => ({ transportIdentity: 'device-a', generation: 1 }),
    current: () => true,
    status: async () => ({ capability: true, authority: 'paused' }),
    snapshot: async () => ({ revision, scopes: [{ ...descriptor, revision, itemCount: revision === 1 ? 1 : 0 }], worktreeOrders: [] }),
    scope: async () => ({ ...descriptor, revision, itemCount: revision === 1 ? 1 : 0, items: revision === 1 ? [item] : [] }),
    remove: async () => {
      removeCalls++;
      revision = 2;
      throw new MessageQueueServerError(404, 'not_found');
    },
  });
  await runtime.refresh();
  const result = await runtime.remove({ requestID: 'remove-stale', scopeID: descriptor.scopeID, revision: 1, item });
  expect(result.status).toBe('committed');
  expect(result.scope?.items).toEqual([]);
  expect(removeCalls).toBe(1);
});

test('not_found remove reload preserves remaining items in the same scope', async () => {
  const cache = new Map<string, unknown>();
  const client = { setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value), getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined, removeQueries: () => {}, invalidateQueries: async () => {} };
  const kept = { ...item, queueItemID: 'queue-kept', operationID: 'operation-kept', messageID: 'msg_kept', content: 'kept' };
  let revision = 1;
  const runtime = createMessageQueueServerRuntime({
    client: client as never,
    capture: () => ({ transportIdentity: 'device-a', generation: 1 }),
    current: () => true,
    status: async () => ({ capability: true, authority: 'paused' }),
    snapshot: async () => ({ revision, scopes: [{ ...descriptor, revision, itemCount: revision === 1 ? 2 : 1 }], worktreeOrders: [] }),
    scope: async () => ({
      ...descriptor,
      revision,
      itemCount: revision === 1 ? 2 : 1,
      items: revision === 1 ? [item, kept] : [kept],
    }),
    remove: async () => {
      revision = 2;
      throw new MessageQueueServerError(404, 'not_found');
    },
  });
  await runtime.refresh();
  const result = await runtime.remove({ requestID: 'remove-gone', scopeID: descriptor.scopeID, revision: 1, item });
  expect(result.status).toBe('committed');
  expect(result.scope?.items).toEqual([kept]);
});

test('conflict reload keeps sibling scope pages while advancing only the mutated scope', async () => {
  const cache = new Map<string, unknown>();
  const client = {
    setQueryData: (key: readonly unknown[], value: unknown) => cache.set(JSON.stringify(key), value),
    getQueryData: <T>(key: readonly unknown[]) => cache.get(JSON.stringify(key)) as T | undefined,
    removeQueries: ({ queryKey }: { queryKey: readonly unknown[] }) => {
      const prefix = JSON.stringify(queryKey).slice(0, -1);
      for (const key of cache.keys()) if (key.startsWith(prefix)) cache.delete(key);
    },
    invalidateQueries: async () => {},
  };
  const sibling = { scopeID: 'scope-b', revision: 1, directory: '/repo', sessionID: 'session-b', worktreeState: 'active' as const, itemCount: 1 };
  const siblingItem = { ...item, queueItemID: 'queue-b', operationID: 'operation-b', messageID: 'msg_b', content: 'sibling' };
  let revisionA = 1;
  let revisionB = 1;
  let editCalls = 0;
  const runtime = createMessageQueueServerRuntime({
    client: client as never,
    capture: () => ({ transportIdentity: 'device-a', generation: 1 }),
    current: () => true,
    status: async () => ({ capability: true, authority: 'paused' }),
    snapshot: async () => ({
      revision: Math.max(revisionA, revisionB),
      scopes: [
        { ...descriptor, revision: revisionA, itemCount: 1 },
        { ...sibling, revision: revisionB, itemCount: 1 },
      ],
      worktreeOrders: [],
    }),
    scope: async (scopeID) => {
      if (scopeID === sibling.scopeID) return { ...sibling, revision: revisionB, items: [siblingItem] };
      return { ...descriptor, revision: revisionA, itemCount: 1, items: [{ ...item, content: `a-${revisionA}` }] };
    },
    edit: async () => {
      editCalls++;
      if (editCalls === 1) {
        revisionA = 2;
        revisionB = 2;
        throw new MessageQueueServerError(409, 'revision_conflict');
      }
      return { revision: revisionA };
    },
  });
  await runtime.refresh();
  expect(runtime.getScope({ transportIdentity: 'device-a', directory: '/repo', sessionID: 'session-b' })?.items).toEqual([siblingItem]);
  const result = await runtime.edit({ requestID: 'edit-a', scopeID: descriptor.scopeID, revision: 1, item, patch: { content: 'edited' } });
  expect(result.status).toBe('committed');
  expect(runtime.getScope({ transportIdentity: 'device-a', directory: '/repo', sessionID: 'session-b' })?.items).toEqual([siblingItem]);
  expect(runtime.getState().scopes.get(sibling.scopeID)?.revision).toBe(1);
  expect(runtime.getState().scopes.get(descriptor.scopeID)?.revision).toBe(2);
});
