import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { confirmMessageQueueEvent, createGlobalMessageStreamHub } from '../event-stream/global-hub.js';
import { createAscendingMessageID } from './message-id.js';
import { createMessageQueueRuntime } from './runtime.js';

const roots = new Set();
const sleep = (ms = 10) => new Promise((resolve) => setTimeout(resolve, ms));
const eventually = async (check, timeout = 2_000) => { let failure; for (const until = Date.now() + timeout; Date.now() < until; await sleep()) { try { return await check(); } catch (error) { failure = error; } } throw failure; };
const payload = (id, directory = '/repo', sessionID = 'session', extra = {}) => ({ scope: { directory, sessionID }, item: { queueItemID: `item-${id}`, operationID: `operation-${id}`, messageID: `msg_seed_${id}`, content: `body-${id}`, composerDocument: { text: `body-${id}`, references: [] }, sendConfig: { providerID: 'openai', modelID: 'gpt' }, attachments: [], attachmentIssues: [], createdAt: 1, ...extra } });
const admit = (id, directory = '/repo', sessionID = 'session') => ({ requestID: `admit-${id}`, ...payload(id, directory, sessionID) });
const createSseResponse = (payload) => {
  const encoder = new TextEncoder();
  let delivered = false;
  return { ok: true, body: { getReader: () => ({ read: async () => {
    if (delivered) return { value: undefined, done: true };
    delivered = true;
    return { value: encoder.encode(`id: queue-event\ndata: ${JSON.stringify(payload)}\n\n`), done: false };
  } }) } };
};
const confirmThroughGlobalHub = async (service, runtimeKey, payload) => {
  let received = 0;
  const hub = createGlobalMessageStreamHub({ buildOpenCodeUrl: (pathname) => `http://runtime${pathname}`, getOpenCodeAuthHeaders: () => ({}), getRuntimeIdentity: () => ({ runtimeKey }), upstreamReconnectDelayMs: 1_000, fetchImpl: async () => createSseResponse({ directory: '/repo', payload }) });
  hub.subscribeEvent((event) => { received += 1; confirmMessageQueueEvent(service, event); });
  try {
    hub.start();
    await eventually(() => expect(received).toBe(1));
  } finally {
    hub.stop();
  }
};
const fixture = async ({ send = async () => ({ ok: true }), apiBaseUrl = 'http://runtime' } = {}) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'queue-authority-import-')); roots.add(root); const sent = [];
  const adapter = { captureRuntime: () => ({}), checkEligibility: async () => ({ available: true, idle: true, settled: true, latestMessageID: 'msg_00000000000000000000000000' }), createMessageID: createAscendingMessageID, materializeAttachments: async () => [], send: async (context, options) => { sent.push(context); return send(context, options); }, findMessage: async () => ({ found: false }) };
  let currentApiBaseUrl = apiBaseUrl;
  const runtime = createMessageQueueRuntime({ dbPath: path.join(root, 'queue.sqlite'), attachmentRoot: path.join(root, 'attachments'), adapter, workerID: `authority-${process.pid}`, getRuntimeConfig: () => ({ apiBaseUrl: currentApiBaseUrl }) }); await runtime.start();
  return { root, runtime, service: runtime.service, adapter, sent, setApiBaseUrl: (value) => { currentApiBaseUrl = value; } };
};
const stage = (service, id, entry, generation, kind = 'activation', clientID = id) => { const created = service.createImport({ requestID: `create-${id}`, kind, clientID, snapshotHash: crypto.createHash('sha256').update(id).digest('hex'), itemCount: 1, protocol: 4, expectedGeneration: generation }); service.stageImport({ requestID: `stage-${id}`, importID: created.importID, scopeOrdinal: 0, itemOrdinal: 0, payload: entry }); const sealed = service.sealImport({ requestID: `seal-${id}`, importID: created.importID }); return { ...created, manifestHash: sealed.manifestHash }; };

afterEach(async () => { for (const root of roots) { roots.delete(root); fs.rmSync(root, { recursive: true, force: true }); } });

describe('Phase 3 authority and import integration', () => {
  it('auto-starts durable active rows after restart and holds paused rows until resume', async () => {
    const f = await fixture(); f.service.admit(admit('restart')); f.service.setAuthority({ authority: 'active', expectedGeneration: 0 }); await f.runtime.stop();
    const reopened = createMessageQueueRuntime({ dbPath: path.join(f.root, 'queue.sqlite'), attachmentRoot: path.join(f.root, 'attachments'), adapter: f.adapter, workerID: 'restarted', getRuntimeConfig: () => ({ apiBaseUrl: 'http://runtime' }) }); await reopened.start(); await eventually(() => expect(f.sent).toHaveLength(1)); const active = reopened.service.getAuthority(); await reopened.service.pauseAuthority({ expectedGeneration: active.generation }); await reopened.stop();
    const paused = createMessageQueueRuntime({ dbPath: path.join(f.root, 'queue.sqlite'), attachmentRoot: path.join(f.root, 'attachments'), adapter: f.adapter, workerID: 'paused', getRuntimeConfig: () => ({ apiBaseUrl: 'http://runtime' }) }); await paused.start(); expect(paused.worker.status().paused).toBe(true); const authority = paused.service.getAuthority(); paused.service.resumeAuthority({ expectedGeneration: authority.generation }); await paused.start(); await paused.stop();
  });

  it('confirms a paused sending row through the global hub and writes its completion tombstone', async () => {
    let release; const f = await fixture({ send: async () => new Promise((resolve) => { release = () => resolve({ ok: true }); }) }); const added = f.service.admit(admit('pause')); f.service.setAuthority({ authority: 'active', expectedGeneration: 0 }); void f.runtime.start(); await eventually(() => expect(release).toBeTypeOf('function')); const authority = f.service.getAuthority(); f.service.pauseAuthority({ expectedGeneration: authority.generation }); release(); await sleep(); const current = f.service.getScope(added.scopeID).items[0]; expect(current).toMatchObject({ status: 'reconciling', messageID: expect.stringMatching(/^msg_/) }); await confirmThroughGlobalHub(f.service, f.service.getRuntimeKey(), { type: 'message.updated', properties: { info: { role: 'user', sessionID: 'session', id: current.messageID } } }); expect(f.service.snapshot().scopes).toMatchObject([{ scopeID: added.scopeID, itemCount: 0 }]); expect(f.service.confirmByMessage({ directory: '/repo', sessionID: 'session', messageID: current.messageID })).toMatchObject({ completed: true, duplicate: true }); await f.runtime.stop();
  });

  it('keeps shadow authority and late runtime A events from confirming runtime B rows', async () => {
    const f = await fixture({ apiBaseUrl: 'http://runtime-a' }); const addedA = f.service.admit(admit('a')); const runtimeA = f.service.getRuntimeKey();
    await confirmThroughGlobalHub(f.service, runtimeA, { type: 'message.updated', properties: { info: { role: 'user', sessionID: 'session', id: 'msg_seed_a' } } });
    expect(f.service.getScope(addedA.scopeID).items).toHaveLength(1);
    f.service.setAuthority({ authority: 'paused', expectedGeneration: 0 }); f.setApiBaseUrl('http://runtime-b'); const addedB = f.service.admit(admit('b')); const runtimeB = f.service.getRuntimeKey(); f.service.setAuthority({ authority: 'paused', expectedGeneration: 0 });
    await confirmThroughGlobalHub(f.service, runtimeA, { type: 'message.updated', properties: { info: { role: 'user', sessionID: 'session', id: 'msg_seed_b' } } });
    expect(runtimeA).not.toBe(runtimeB); expect(f.service.getScope(addedB.scopeID).items).toHaveLength(1); await f.runtime.stop();
  });

  it('commits late rows atomically with exact active/tombstone confirmation and per-scope tails', async () => {
    const f = await fixture(); const base = f.service.admit(admit('base')); f.service.setAuthority({ authority: 'active', expectedGeneration: 0 }); const generation = f.service.getAuthority().generation; const exact = stage(f.service, 'lateexact', payload('base'), generation, 'late'); f.service.commitLateImport({ requestID: 'commit-exact', importID: exact.importID, expectedGeneration: generation, manifestHash: exact.manifestHash, protocol: 4 }); expect(f.service.getScope(base.scopeID).items).toHaveLength(1);
    const addition = stage(f.service, 'lateadd', payload('late', '/other', 'other'), generation, 'late'); f.service.commitLateImport({ requestID: 'commit-add', importID: addition.importID, expectedGeneration: generation, manifestHash: addition.manifestHash, protocol: 4 }); expect(f.service.getAuthority().generation).toBe(generation);
    const conflict = stage(f.service, 'lateconflict', payload('bad', '/repo', 'session', { operationID: 'operation-base' }), generation, 'late'); expect(() => f.service.commitLateImport({ requestID: 'commit-conflict', importID: conflict.importID, expectedGeneration: generation, manifestHash: conflict.manifestHash, protocol: 4 })).toThrow(expect.objectContaining({ code: 'idempotency_conflict' })); expect(f.service.getScope(base.scopeID).items).toHaveLength(1); await f.runtime.stop();
  });

  it('permits one activation CAS and rolls back malformed manifests before authority changes', async () => {
    const f = await fixture(); const first = stage(f.service, 'activatea', payload('a'), 0); const second = stage(f.service, 'activateb', payload('b'), 0, 'activation', 'b'); const committed = f.service.activateImport({ requestID: 'activate-a', importID: first.importID, expectedGeneration: 0, manifestHash: first.manifestHash, protocol: 4 }); expect(committed.generation).toBe(1); expect(() => f.service.activateImport({ requestID: 'activate-b', importID: second.importID, expectedGeneration: 0, manifestHash: second.manifestHash, protocol: 4 })).toThrow(expect.objectContaining({ code: 'generation_conflict' })); expect(f.service.snapshot().scopes).toHaveLength(1); await f.runtime.stop();
  });
});
