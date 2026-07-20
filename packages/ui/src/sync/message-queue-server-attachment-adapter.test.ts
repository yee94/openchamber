import { describe, expect, test } from 'bun:test';
import { uploadQueueAttachments } from './message-queue-server-attachment-adapter';

describe('message queue server attachment admission', () => {
  test('enforces per-item admission before creating uploads', async () => {
    await expect(uploadQueueAttachments([{ attachmentID: 'a', filename: 'large', mimeType: 'application/octet-stream', source: 'local', value: new Blob([new Uint8Array(25 * 1024 * 1024 + 1)]) }])).rejects.toThrow('message-queue-attachment-too-large');
  });

  test('keeps canonical server paths without creating an upload', async () => {
    expect(await uploadQueueAttachments([{ attachmentID: 'a', filename: 'server.txt', mimeType: 'text/plain', source: 'server', path: '/repo/server.txt', size: 3 }])).toEqual({ attachments: [{ attachmentID: 'a', occurrenceRefID: ['root', 'a'], filename: 'server.txt', mimeType: 'text/plain', size: 3, source: 'server', locator: { kind: 'server-path', path: '/repo/server.txt' } }], totalBytes: 3 });
  });

  test('enforces authoritative server attachment and aggregate limits', async () => {
    await expect(uploadQueueAttachments([{ attachmentID: 'a', filename: 'large', mimeType: 'application/octet-stream', source: 'server', path: '/repo/large', size: 25 * 1024 * 1024 + 1 }])).rejects.toThrow('message-queue-attachment-too-large');
    await expect(uploadQueueAttachments([{ attachmentID: 'a', filename: 'a', mimeType: 'application/octet-stream', source: 'server', path: '/repo/a', size: 20 * 1024 * 1024 }, { attachmentID: 'b', filename: 'b', mimeType: 'application/octet-stream', source: 'server', path: '/repo/b', size: 20 * 1024 * 1024 }, { attachmentID: 'c', filename: 'c', mimeType: 'application/octet-stream', source: 'server', path: '/repo/c', size: 11 * 1024 * 1024 }])).rejects.toThrow('message-queue-attachments-too-large');
  });
});
