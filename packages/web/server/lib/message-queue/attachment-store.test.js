import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import { createRequire } from 'node:module';
import os from 'node:os';
import path from 'node:path';
import { Readable } from 'node:stream';
import { afterEach, describe, expect, it } from 'vitest';
import { createAttachmentStore } from './attachment-store.js';
import { createMessageQueueService } from './service.js';
import { createMessageQueueWorker } from './worker.js';

const directories = [];
const require = createRequire(import.meta.url);
const Database = require('better-sqlite3');
const fixture = async () => {
  const rootDir = await fs.mkdtemp(path.join(os.tmpdir(), 'attachment-store-'));
  directories.push(rootDir);
  return { rootDir, store: createAttachmentStore({ rootDir }) };
};
const digest = (value) => createHash('sha256').update(value).digest('hex');
const body = (value) => Readable.from([Buffer.from(value)]);
afterEach(async () => Promise.all(directories.splice(0).map((directory) => fs.rm(directory, { recursive: true, force: true }))));

describe('attachment store', () => {
  it('stores content by sha256 and reads it after restart', async () => {
    const { rootDir, store } = await fixture();
    const result = await store.writeUpload({ uploadID: 'upload-1', stream: body('hello'), expectedSize: 5 });
    expect(result).toEqual({ storageKey: digest('hello'), size: 5 });
    const reopened = createAttachmentStore({ rootDir });
    const stream = await reopened.openObject(result.storageKey);
    expect(Buffer.concat(await Array.fromAsync(stream)).toString()).toBe('hello');
  });

  it('cleans staging for hash, size, and maximum-size failures', async () => {
    const { rootDir, store } = await fixture();
    await expect(store.writeUpload({ uploadID: 'hash', stream: body('hello'), expectedSize: 5, expectedSha256: 'a'.repeat(64) })).rejects.toMatchObject({ code: 'attachment_store_hash_mismatch' });
    await expect(store.writeUpload({ uploadID: 'size', stream: body('hello'), expectedSize: 4 })).rejects.toMatchObject({ code: 'attachment_store_size_mismatch' });
    const limited = createAttachmentStore({ rootDir, maxBytes: 4 });
    await expect(limited.writeUpload({ uploadID: 'limit', stream: body('hello'), expectedSize: 5 })).rejects.toMatchObject({ code: 'attachment_store_max_bytes' });
    expect(await store.listStaging()).toEqual([]);
  });

  it('accepts exactly 25 MiB and rejects a client-declared size that differs from received bytes', async () => {
    const { store } = await fixture();
    const limit = 25 * 1024 * 1024;
    const exact = Buffer.alloc(limit, 7);
    await expect(store.writeUpload({ uploadID: 'exact-limit', stream: Readable.from([exact]), expectedSize: limit })).resolves.toMatchObject({ size: limit });
    await expect(store.writeUpload({ uploadID: 'forged-size', stream: body('server-bytes'), expectedSize: 1 })).rejects.toMatchObject({ code: 'attachment_store_size_mismatch' });
  });

  it('cleans staging when an upload aborts', async () => {
    const { store } = await fixture();
    const controller = new AbortController();
    controller.abort();
    await expect(store.writeUpload({ uploadID: 'abort', stream: body('hello'), expectedSize: 5, signal: controller.signal })).rejects.toMatchObject({ code: 'attachment_store_aborted' });
    expect(await store.listStaging()).toEqual([]);
  });

  it('deduplicates concurrent uploads with identical content', async () => {
    const { store } = await fixture();
    const [first, second] = await Promise.all(['one', 'two'].map((uploadID) => store.writeUpload({ uploadID, stream: body('hello'), expectedSize: 5 })));
    expect(first).toEqual(second);
  });

  it('rejects traversal keys and cleans old staging while protecting live objects', async () => {
    const { rootDir, store } = await fixture();
    await expect(store.openObject('../secret')).rejects.toMatchObject({ code: 'attachment_store_invalid_storage_key' });
    await expect(store.writeUpload({ uploadID: '../bad', stream: body('x'), expectedSize: 1 })).rejects.toMatchObject({ code: 'attachment_store_invalid_upload_id' });
    const live = await store.writeUpload({ uploadID: 'live', stream: body('live'), expectedSize: 4 });
    const stale = await store.writeUpload({ uploadID: 'stale', stream: body('stale'), expectedSize: 5 });
    await fs.writeFile(path.join(rootDir, 'staging', 'old.part'), 'old');
    const old = new Date(Date.now() - 10_000);
    await fs.utimes(path.join(rootDir, 'objects', stale.storageKey.slice(0, 2), stale.storageKey), old, old);
    await fs.utimes(path.join(rootDir, 'staging', 'old.part'), old, old);
    expect(await store.gc({ liveStorageKeys: new Set([live.storageKey]), olderThan: Date.now() - 1_000 })).toEqual({ deletedObjects: 1, deletedStaging: 1 });
    await expect(store.openObject(live.storageKey)).resolves.toBeDefined();
    await expect(store.openObject(stale.storageKey)).rejects.toMatchObject({ code: 'attachment_store_not_found' });
  });

  it('reads authorized regular server paths after resolving them and rejects symlink escape', async () => {
    const { rootDir, store } = await fixture();
    const scope = path.join(rootDir, 'scope');
    const outside = path.join(rootDir, 'outside.txt');
    const inside = path.join(scope, 'inside.txt');
    const link = path.join(scope, 'escape.txt');
    await fs.mkdir(scope);
    await fs.writeFile(inside, 'inside');
    await fs.writeFile(outside, 'outside');
    await fs.symlink(outside, link);
    const resolvedScope = await fs.realpath(scope);
    const scoped = createAttachmentStore({ rootDir, isServerPathAllowed: (pathname) => pathname.startsWith(`${resolvedScope}${path.sep}`) });
    await expect(scoped.readAttachment({ locator: { kind: 'server-path', path: inside }, filename: 'inside.txt', mimeType: 'text/plain', size: 6 }, { runtimeKey: 'runtime', directory: scope })).resolves.toMatchObject({ type: 'file', filename: 'inside.txt', mime: 'text/plain' });
    await expect(scoped.readAttachment({ locator: { kind: 'server-path', path: link } }, { runtimeKey: 'runtime', directory: scope })).rejects.toMatchObject({ code: 'attachment_store_not_found' });
  });

  it('opens downloadable attachment streams only after validating object and server-path metadata', async () => {
    const { rootDir, store } = await fixture();
    const object = await store.writeUpload({ uploadID: 'download', stream: body('download-body'), expectedSize: 13 });
    const uploaded = await store.openAttachment({ filename: 'download.txt', mimeType: 'text/plain', size: 13, locator: { kind: 'upload', storageKey: object.storageKey } }, {});
    expect(Buffer.concat(await Array.fromAsync(uploaded.stream)).toString()).toBe('download-body');
    await expect(store.openAttachment({ size: 12, locator: { kind: 'upload', storageKey: object.storageKey } }, {})).rejects.toMatchObject({ code: 'attachment_store_not_found' });
    await expect(store.openAttachment({ locator: { kind: 'upload', storageKey: '../secret' } }, {})).rejects.toMatchObject({ code: 'attachment_store_invalid_storage_key' });
  });

  it('round-trips uploaded attachment bytes into the restarted worker file part', async () => {
    const { rootDir, store } = await fixture();
    const dbPath = path.join(rootDir, 'queue.sqlite');
    const getRuntimeConfig = () => ({ apiBaseUrl: 'http://runtime' });
    const service = createMessageQueueService({ dbPath, getRuntimeConfig });
    const uploaded = await store.writeUpload({ uploadID: 'upload-body', stream: body('PNG-bytes'), expectedSize: 9 });
    const upload = service.createAttachmentUpload();
    service.markAttachmentReady({ ...upload, objectHash: uploaded.storageKey, storageKey: uploaded.storageKey, sizeBytes: uploaded.size });
    const admitted = service.admit({ requestID: 'attachment-flow', scope: { directory: '/repo', sessionID: 'session' }, item: {
      queueItemID: 'item', operationID: 'operation', messageID: 'message', content: 'send file', createdAt: 1, migrationImport: true, attachments: [{ uploadID: upload.uploadID, name: 'image.png', mediaType: 'image/png' }], attachmentIssues: [], composerDocument: { text: 'send file', references: [{ attachmentID: upload.uploadID }] }, sendConfig: { providerID: 'openai', modelID: 'gpt' },
    } });
    expect(service.getScope(admitted.scopeID).items[0].attachments).toEqual([{ attachmentID: upload.uploadID, occurrenceRefID: ['root', upload.uploadID], filename: 'image.png', mimeType: 'image/png', size: 9, source: 'local', locator: { kind: 'upload', uploadID: upload.uploadID, storageKey: uploaded.storageKey } }]);
    service.close();

    const reopened = createMessageQueueService({ dbPath, getRuntimeConfig });
    reopened.setAuthority({ authority: 'active', expectedGeneration: 0 });
    const sent = [];
    const adapter = {
      captureRuntime: () => ({ token: 'runtime' }), checkEligibility: () => ({ available: true, idle: true, settled: true, latestMessageID: 'msg_0' }), createMessageID: () => 'msg_1',
      materializeAttachments: async (item) => [{ type: 'text', text: item.content }, await store.readAttachment(item.attachments[0], item)],
      send: async (context) => { sent.push(context.parts); return { ok: true }; }, findMessage: async () => ({ found: false }),
    };
    const worker = createMessageQueueWorker({ service: reopened, adapter, workerID: 'attachment-worker' });
    worker.start();
    await worker.wake();
    expect(sent).toHaveLength(1);
    expect(sent[0][1]).toMatchObject({ type: 'file', filename: 'image.png', mime: 'image/png' });
    expect(Buffer.from(sent[0][1].url.split(',')[1], 'base64').toString()).toBe('PNG-bytes');
    await worker.stop(); reopened.close();
  });

  it('keeps database metadata until the object file deletion succeeds', async () => {
    const { rootDir, store } = await fixture();
    const dbPath = path.join(rootDir, 'queue.sqlite');
    const service = createMessageQueueService({ dbPath, getRuntimeConfig: () => ({ apiBaseUrl: 'http://runtime' }) });
    const upload = service.createAttachmentUpload();
    const object = await store.writeUpload({ uploadID: 'gc-object', stream: body('gc'), expectedSize: 2 });
    service.markAttachmentReady({ ...upload, objectHash: object.storageKey, storageKey: object.storageKey, sizeBytes: 2 });
    service.close();
    const raw = new Database(dbPath);
    expect(raw.prepare('SELECT COUNT(*) AS count FROM attachment_object').get().count).toBe(1);
    raw.close();
    await expect(store.deleteObject(object.storageKey)).resolves.toBeUndefined();
    const reopened = createMessageQueueService({ dbPath, getRuntimeConfig: () => ({ apiBaseUrl: 'http://runtime' }) });
    expect(reopened.removeAttachmentObjectForGC({ objectHash: object.storageKey, storageKey: object.storageKey })).toBe(0);
    reopened.close();
  });
});
