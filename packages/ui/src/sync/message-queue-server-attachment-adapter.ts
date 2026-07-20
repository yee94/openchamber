import { createMessageQueueAttachmentUpload, uploadMessageQueueAttachment, type MessageQueueAttachment } from '@/lib/message-queue-server';

const MAX_ATTACHMENT_BYTES = 25 * 1024 * 1024;
const MAX_TOTAL_BYTES = 50 * 1024 * 1024;
export type QueueAttachmentCandidate =
  | { attachmentID: string; filename: string; mimeType: string; occurrenceRefID?: MessageQueueAttachment['occurrenceRefID']; source: 'local'; value: Blob }
  | { attachmentID: string; filename: string; mimeType: string; occurrenceRefID?: MessageQueueAttachment['occurrenceRefID']; source: 'server'; path: string; size: number };
export type QueueAttachmentUploadResult = { attachments: MessageQueueAttachment[]; totalBytes: number };
const digest = async (value: Blob): Promise<string> => [...new Uint8Array(await crypto.subtle.digest('SHA-256', await value.arrayBuffer()))].map((byte) => byte.toString(16).padStart(2, '0')).join('');

export const uploadQueueAttachments = async (items: readonly QueueAttachmentCandidate[], signal?: AbortSignal): Promise<QueueAttachmentUploadResult> => {
  let totalBytes = 0;
  for (const item of items) { const size = item.source === 'local' ? item.value.size : item.size; if (!Number.isSafeInteger(size) || size < 0 || size > MAX_ATTACHMENT_BYTES) throw new RangeError('message-queue-attachment-too-large'); totalBytes += size; }
  if (totalBytes > MAX_TOTAL_BYTES) throw new RangeError('message-queue-attachments-too-large');
  const attachments: MessageQueueAttachment[] = [];
  for (const item of items) {
    if (item.source === 'server') {
      attachments.push({ attachmentID: item.attachmentID, occurrenceRefID: item.occurrenceRefID ?? ['root', item.attachmentID], filename: item.filename, mimeType: item.mimeType || 'application/octet-stream', size: item.size, source: 'server', locator: { kind: 'server-path', path: item.path } });
      continue;
    }
    const upload = await createMessageQueueAttachmentUpload({ signal });
    await uploadMessageQueueAttachment(upload, item.value, await digest(item.value), signal);
    attachments.push({ attachmentID: item.attachmentID, occurrenceRefID: item.occurrenceRefID ?? ['root', item.attachmentID], filename: item.filename, mimeType: item.mimeType || item.value.type || 'application/octet-stream', size: item.value.size, source: 'local', locator: { kind: 'upload', uploadID: upload.uploadID } });
  }
  return { attachments, totalBytes };
};
