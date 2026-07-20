import { afterEach, beforeEach, describe, expect, mock, test } from 'bun:test';

type RuntimeFetchInit = RequestInit & { query?: Record<string, unknown> };
type RuntimeFetchCall = [path: string, init?: RuntimeFetchInit];
const runtimeFetchCalls: RuntimeFetchCall[] = [];
let runtimeFetchImplementation: (...args: RuntimeFetchCall) => Promise<Response>;
const runtimeFetch = async (...args: RuntimeFetchCall): Promise<Response> => {
  runtimeFetchCalls.push(args);
  return runtimeFetchImplementation(...args);
};
mock.module('@/lib/runtime-fetch', () => ({
  buildRuntimeFetchUrl: (input: string) => input,
  getRuntimeRequestPriority: () => undefined,
  installRuntimeFetchBridge: () => undefined,
  isLatin1Safe: () => true,
  runtimeFetch,
  sanitizeHeadersForBrowser: () => undefined,
  setRuntimeInteractiveSessionRequestId: () => undefined,
}));

const api = await import('./message-queue-server');

const item = { queueItemID: 'item/a', operationID: 'operation/a', messageID: 'message/a', content: 'hello', status: 'queued', attemptCount: 0, position: 0, rowVersion: 2, createdAt: 1 };
const scope = { scopeID: 'scope/a', revision: 4, directory: '/repo', sessionID: 'session/a', worktreeState: 'active', itemCount: 1, items: [item] };
const snapshot = { revision: 4, scopes: [{ ...scope, items: undefined }], worktreeOrders: [{ projectDirectory: '/repo', orderedPaths: ['/repo/w'], revision: 2 }] };
const changes = { revision: 4, scopes: [{ scopeID: 'scope/a', revision: 4, directory: '/repo', sessionID: 'session/a', worktreeState: 'active', itemCount: 1 }], worktreeOrders: snapshot.worktreeOrders };

describe('message queue server adapter', () => {
  beforeEach(() => {
    runtimeFetchCalls.length = 0;
    runtimeFetchImplementation = async () => new Response(JSON.stringify(snapshot));
  });
  afterEach(() => {
    runtimeFetchCalls.length = 0;
  });

  test('uses exact encoded read paths, queries, and signals', async () => {
    const responses = [scope, changes, snapshot.worktreeOrders[0]];
    runtimeFetchImplementation = async () => new Response(JSON.stringify(responses.shift()));
    const controller = new AbortController();
    await api.fetchMessageQueueScope('scope/a?', { offset: 2, limit: 8, expectedRevision: 4, signal: controller.signal });
    await api.waitForMessageQueueChanges(4, { signal: controller.signal, timeoutMs: 12_000 });
    await api.fetchWorktreeOrder('/repo a', controller.signal);
    expect(runtimeFetchCalls).toEqual([
      ['/api/openchamber/message-queue/scopes/scope%2Fa%3F', { query: { offset: 2, limit: 8, expectedRevision: 4 }, signal: controller.signal }],
      ['/api/openchamber/message-queue/changes', { query: { afterRevision: 4, timeout: 12_000 }, signal: controller.signal }],
      ['/api/openchamber/message-queue/worktrees/order', { query: { projectDirectory: '/repo a' }, signal: controller.signal }],
    ]);
  });

  test('accepts catalog changes without item bodies and rejects malformed descriptors', async () => {
    runtimeFetchImplementation = async () => new Response(JSON.stringify(changes));
    expect(await api.waitForMessageQueueChanges(3)).toEqual(changes);
    runtimeFetchImplementation = async () => new Response(JSON.stringify({ ...changes, scopes: [{ ...changes.scopes[0], itemCount: -1 }] }));
    try {
      await api.waitForMessageQueueChanges(3);
      throw new Error('expected malformed changes to fail');
    } catch (error) {
      expect((error as { code?: string }).code).toBe('unavailable');
    }
  });

  test('sends the admission and mutation contracts without serializing signals', async () => {
    runtimeFetchImplementation = async () => new Response(JSON.stringify({ revision: 5, scopeID: 'scope/a', queueItemID: 'item/a', rowVersion: 2 }));
    const controller = new AbortController();
    await api.admitTextQueueItem({ requestID: 'r1', expectedRevision: 4, scope: { directory: '/repo', sessionID: 'session/a' }, item: { queueItemID: 'item/a', operationID: 'operation/a', messageID: 'message/a', content: 'secret', attachments: [], attachmentIssues: [], createdAt: 1 }, signal: controller.signal });
    await api.editTextQueueItem('item/a', { requestID: 'r2', expectedRevision: 5, expectedRowVersion: 2, item: { content: 'updated' } });
    await api.removeQueueItem('item/a', { requestID: 'r3', expectedRevision: 5, expectedRowVersion: 3 });
    await api.reorderQueueScope('scope/a', { requestID: 'r4', expectedRevision: 5, queueItemIDs: ['item/a'] });
    await api.setWorktreeOrder({ requestID: 'r5', projectDirectory: '/repo', expectedRevision: 2, orderedPaths: ['/repo/w'] });
    expect(runtimeFetchCalls.map(([path, init]) => [path, init?.method, JSON.parse(String(init?.body))])).toEqual([
      ['/api/openchamber/message-queue/items', 'POST', { requestID: 'r1', expectedRevision: 4, scope: { directory: '/repo', sessionID: 'session/a' }, item: { queueItemID: 'item/a', operationID: 'operation/a', messageID: 'message/a', content: 'secret', attachments: [], attachmentIssues: [], createdAt: 1 } }],
      ['/api/openchamber/message-queue/items/item%2Fa', 'PATCH', { requestID: 'r2', expectedRevision: 5, expectedRowVersion: 2, item: { content: 'updated' } }],
      ['/api/openchamber/message-queue/items/item%2Fa', 'DELETE', { requestID: 'r3', expectedRevision: 5, expectedRowVersion: 3 }],
      ['/api/openchamber/message-queue/scopes/scope%2Fa/order', 'PUT', { requestID: 'r4', expectedRevision: 5, queueItemIDs: ['item/a'] }],
      ['/api/openchamber/message-queue/worktrees/order', 'PUT', { requestID: 'r5', projectDirectory: '/repo', expectedRevision: 2, orderedPaths: ['/repo/w'] }],
    ]);
    expect(runtimeFetchCalls[0]?.[1]?.signal).toBe(controller.signal);
  });

  test('accepts compact mutation acknowledgements and rejects item bodies', async () => {
    runtimeFetchImplementation = async () => new Response(JSON.stringify({ revision: 5, projectDirectory: '/repo' }));
    await api.setWorktreeOrder({ requestID: 'r5', projectDirectory: '/repo', expectedRevision: 2, orderedPaths: ['/repo/w'] });
    runtimeFetchImplementation = async () => new Response(JSON.stringify({ revision: 5, scope: scope }));
    try {
      await api.setWorktreeOrder({ requestID: 'r6', projectDirectory: '/repo', expectedRevision: 2, orderedPaths: ['/repo/w'] });
      throw new Error('expected malformed acknowledgement to fail');
    } catch (error) {
      expect((error as { code?: string }).code).toBe('unavailable');
    }
  });

  test('maps stable route errors and rejects malformed authoritative success', async () => {
    const readError = async (): Promise<{ status?: number; code?: string }> => {
      try {
        await api.fetchMessageQueueSnapshot();
        throw new Error('expected request to fail');
      } catch (error) {
        const value = error as { status?: number; code?: string };
        return { status: value.status, code: value.code };
      }
    };
    runtimeFetchImplementation = async () => new Response(JSON.stringify({ code: 'row_version_conflict', detail: 'secret' }), { status: 409 });
    expect(await readError()).toEqual({ status: 409, code: 'row_version_conflict' });
    runtimeFetchImplementation = async () => new Response('', { status: 501 });
    expect(await readError()).toEqual({ status: 501, code: 'unavailable' });
    runtimeFetchImplementation = async () => new Response(JSON.stringify({ revision: 1, scopes: [], worktreeOrders: 'invalid' }));
    expect(await readError()).toEqual({ status: 200, code: 'unavailable' });
  });

  test('accepts only canonical attachment DTOs and sends manual CAS', async () => {
    runtimeFetchImplementation = async (_path, init) => {
      if (init?.method === 'POST') return new Response(JSON.stringify({ revision: 6, scopeID: 'scope/a', queueItemID: 'item/a', rowVersion: 3 }));
      return new Response(JSON.stringify({ ...scope, items: [{ ...item, attachments: [{ attachmentID: 'attachment/a', occurrenceRefID: ['root', 'attachment/a'], filename: 'a.txt', mimeType: 'text/plain', size: 1, source: 'local', locator: { kind: 'upload', uploadID: 'upload/a' } }] }] }));
    };
    const parsed = await api.fetchMessageQueueScope('scope/a');
    expect(parsed.items[0]?.attachments?.[0]?.locator).toEqual({ kind: 'upload', uploadID: 'upload/a' });
    await api.sendQueueItemNow('item/a', { requestID: 'manual-1', expectedRevision: 4, expectedRowVersion: 2 });
    expect(runtimeFetchCalls.at(-1)?.[0]).toBe('/api/openchamber/message-queue/items/item%2Fa/send');
    expect(runtimeFetchCalls.at(-1)?.[1]?.method).toBe('POST');
    expect(runtimeFetchCalls.at(-1)?.[1]?.body).toBe(JSON.stringify({ requestID: 'manual-1', expectedRevision: 4, expectedRowVersion: 2 }));
    runtimeFetchImplementation = async () => new Response(JSON.stringify({ ...scope, items: [{ ...item, attachments: [{ uploadID: 'legacy' }] }] }));
    try { await api.fetchMessageQueueScope('scope/a'); throw new Error('expected canonical parser failure'); } catch (error) { expect((error as { code?: string }).code).toBe('unavailable'); }
  });

  test('uses reserved edit routes and normalizes downloaded attachment MIME parameters', async () => {
    const signal = new AbortController().signal;
    runtimeFetchImplementation = async (path) => {
      if (path.includes('/reserved-remove')) return new Response(JSON.stringify({ revision: 6, scopeID: 'scope/a', removedQueueItemID: 'item/a' }));
      if (path.includes('/renew')) return new Response(JSON.stringify({ queueItemID: 'item/a', token: 'token', expiresAt: 20, generation: 1 }));
      if (path.includes('/reserve')) return new Response(JSON.stringify({ revision: 5, scopeID: 'scope/a', queueItemID: 'item/a', rowVersion: 2, token: 'token', expiresAt: 10, generation: 1 }));
      if (path.includes('/content')) return new Response(new Blob(['x'], { type: 'text/plain;charset=utf-8' }), { headers: { 'Content-Length': '1', 'Content-Type': 'text/plain; charset=utf-8' } });
      return new Response(JSON.stringify({ released: true }));
    };
    const reserved = await api.reserveMessageQueueItemForEdit('item/a', { requestID: 'reserve', expectedRevision: 4, rowVersion: 2, owner: 'ui-edit', ttlMs: 1_000, signal });
    const blob = await api.downloadMessageQueueAttachment('item/a', { attachmentID: 'attachment/a', size: 1, mimeType: 'text/plain' }, signal);
    await api.renewEditReservation('item/a', { token: reserved.token, generation: 1, ttlMs: 1_000, signal });
    await api.releaseMessageQueueItemEditReservation('item/a', { token: reserved.token, signal });
    await api.removeReservedMessageQueueItem('item/a', { requestID: 'remove', expectedRevision: 4, expectedRowVersion: 2, token: reserved.token, generation: 1, signal });
    expect(blob.size).toBe(1); expect(blob.type).toBe('text/plain'); expect(runtimeFetchCalls[1]?.[1]?.signal).toBe(signal); expect(runtimeFetchCalls.map(([path]) => path)).toEqual([
      '/api/openchamber/message-queue/items/item%2Fa/reserve', '/api/openchamber/message-queue/items/item%2Fa/attachments/attachment%2Fa/content', '/api/openchamber/message-queue/items/item%2Fa/edit-reservations/token/renew', '/api/openchamber/message-queue/items/item%2Fa/release', '/api/openchamber/message-queue/items/item%2Fa/reserved-remove',
    ]);
  });

  test('requires the compact renew acknowledgement fields', async () => {
    runtimeFetchImplementation = async () => new Response(JSON.stringify({ queueItemID: 'item/a', token: 'token', generation: 1 }));
    try { await api.renewEditReservation('item/a', { token: 'token', generation: 1, ttlMs: 1_000 }); throw new Error('expected malformed renewal to fail'); } catch (error) { expect((error as { code?: string }).code).toBe('unavailable'); }
  });

  test('rejects downloaded attachments with a different MIME base type or size', async () => {
    const attachment = { attachmentID: 'attachment/a', size: 1, mimeType: 'text/plain' };
    const downloadError = async (): Promise<{ status?: number; code?: string }> => {
      try { await api.downloadMessageQueueAttachment('item/a', attachment); } catch (error) { return error as { status?: number; code?: string }; }
      throw new Error('expected download to fail');
    };
    runtimeFetchImplementation = async () => new Response(new Blob(['x'], { type: 'application/json' }), { headers: { 'Content-Length': '1', 'Content-Type': 'application/json; charset=utf-8' } });
    const mimeError = await downloadError();
    expect(mimeError.status).toBe(200); expect(mimeError.code).toBe('unavailable');
    runtimeFetchImplementation = async () => new Response(new Blob(['xx'], { type: 'text/plain' }), { headers: { 'Content-Length': '2', 'Content-Type': 'text/plain' } });
    const sizeError = await downloadError();
    expect(sizeError.status).toBe(200); expect(sizeError.code).toBe('unavailable');
  });
});
