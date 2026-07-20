import { createHash, randomUUID } from 'node:crypto';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const MAX_BYTES = 25 * 1024 * 1024;
const UPLOAD_ID = /^[a-z0-9][a-z0-9_-]{0,127}$/;
const STORAGE_KEY = /^[a-f0-9]{64}$/;

function fail(code) {
  const error = new Error(code);
  error.code = code;
  throw error;
}

function validUploadID(uploadID) {
  return typeof uploadID === 'string' && UPLOAD_ID.test(uploadID);
}

function validStorageKey(storageKey) {
  return typeof storageKey === 'string' && STORAGE_KEY.test(storageKey);
}

async function directory(pathname) {
  await fsp.mkdir(pathname, { recursive: true, mode: 0o700 });
  const stat = await fsp.lstat(pathname);
  if (!stat.isDirectory() || stat.isSymbolicLink()) fail('attachment_store_unsafe_path');
}

async function regularFile(pathname, missingCode = 'attachment_store_not_found') {
  let stat;
  try {
    stat = await fsp.lstat(pathname);
  } catch (error) {
    if (error.code === 'ENOENT') fail(missingCode);
    throw error;
  }
  if (!stat.isFile() || stat.isSymbolicLink()) fail('attachment_store_unsafe_path');
  return stat;
}

async function syncDirectory(pathname) {
  try {
    const handle = await fsp.open(pathname, 'r');
    try { await handle.sync(); } finally { await handle.close(); }
  } catch { /* Some platforms do not support syncing directories. */ }
}

function asChunk(value) {
  if (Buffer.isBuffer(value)) return value;
  if (value instanceof Uint8Array) return Buffer.from(value);
  return Buffer.from(String(value));
}

export function createAttachmentStore({ rootDir, clock = () => Date.now(), maxBytes = MAX_BYTES, isServerPathAllowed = () => false } = {}) {
  if (typeof rootDir !== 'string' || !rootDir) fail('attachment_store_invalid_root');
  if (!Number.isSafeInteger(maxBytes) || maxBytes < 0) fail('attachment_store_invalid_max_bytes');

  const root = path.resolve(rootDir);
  const staging = path.join(root, 'staging');
  const objects = path.join(root, 'objects');
  const stagingPath = (uploadID) => path.join(staging, `${uploadID}.part`);
  const objectPath = (storageKey) => path.join(objects, storageKey.slice(0, 2), storageKey);
  const locks = new Map();
  const withStorageKeyLock = async (storageKey, action) => {
    const previous = locks.get(storageKey) ?? Promise.resolve();
    let release;
    const current = new Promise((resolve) => { release = resolve; });
    const tail = previous.then(() => current);
    locks.set(storageKey, tail);
    await previous;
    try { return await action(); } finally { release(); if (locks.get(storageKey) === tail) locks.delete(storageKey); }
  };

  async function init() {
    await directory(root);
    await directory(staging);
    await directory(objects);
  }

  async function deleteStaging(uploadID) {
    if (!validUploadID(uploadID)) fail('attachment_store_invalid_upload_id');
    const pathname = stagingPath(uploadID);
    try {
      const stat = await fsp.lstat(pathname);
      if (!stat.isFile() || stat.isSymbolicLink()) fail('attachment_store_unsafe_path');
      await fsp.unlink(pathname);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }

  async function writeUpload({ uploadID, stream, expectedSize, expectedSha256, signal, onStored } = {}) {
    if (!validUploadID(uploadID)) fail('attachment_store_invalid_upload_id');
    if (!Number.isSafeInteger(expectedSize) || expectedSize < 0) fail('attachment_store_invalid_expected_size');
    if (expectedSize > maxBytes) fail('attachment_store_max_bytes');
    if (expectedSha256 !== undefined && !validStorageKey(expectedSha256)) fail('attachment_store_invalid_expected_hash');
    if (!stream || typeof stream[Symbol.asyncIterator] !== 'function') fail('attachment_store_invalid_stream');
    await init();
    if (signal?.aborted) fail('attachment_store_aborted');

    const temporary = stagingPath(uploadID);
    let handle;
    let completed = false;
    try {
      try {
        handle = await fsp.open(temporary, 'wx', 0o600);
      } catch (error) {
        if (error.code === 'EEXIST') fail('attachment_store_upload_exists');
        throw error;
      }
      const hash = createHash('sha256');
      let size = 0;
      try {
        for await (const value of stream) {
          if (signal?.aborted) fail('attachment_store_aborted');
          const chunk = asChunk(value);
          size += chunk.byteLength;
          if (size > maxBytes) fail('attachment_store_max_bytes');
          hash.update(chunk);
          await handle.write(chunk);
        }
      } catch (error) {
        if (error?.code?.startsWith('attachment_store_')) throw error;
        if (signal?.aborted || error?.name === 'AbortError') fail('attachment_store_aborted');
        fail('attachment_store_stream_failed');
      }
      if (signal?.aborted) fail('attachment_store_aborted');
      if (size !== expectedSize) fail('attachment_store_size_mismatch');
      const storageKey = hash.digest('hex');
      if (expectedSha256 && storageKey !== expectedSha256) fail('attachment_store_hash_mismatch');
      await handle.sync();
      await handle.close();
      handle = undefined;

      const result = { storageKey, size };
      await withStorageKeyLock(storageKey, async () => {
        const destinationDirectory = path.join(objects, storageKey.slice(0, 2));
        await directory(destinationDirectory);
        const destination = objectPath(storageKey);
        try {
          await fsp.rename(temporary, destination);
        } catch (error) {
          if (error.code !== 'EEXIST' && error.code !== 'ENOTEMPTY') throw error;
          await regularFile(destination);
          await fsp.unlink(temporary);
        }
        await syncDirectory(destinationDirectory);
        await onStored?.(result);
      });
      completed = true;
      return result;
    } finally {
      if (handle) await handle.close();
      if (!completed) await deleteStaging(uploadID).catch(() => {});
    }
  }

  async function openObject(storageKey) {
    if (!validStorageKey(storageKey)) fail('attachment_store_invalid_storage_key');
    await regularFile(objectPath(storageKey));
    return fs.createReadStream(objectPath(storageKey));
  }

  async function openAttachment(attachment, item, { signal } = {}) {
    const serverPath = attachment?.locator?.kind === 'server-path' ? attachment.locator.path : attachment?.serverPath;
    if (serverPath) {
      if (signal?.aborted) fail('attachment_store_aborted');
      const resolved = await fsp.realpath(serverPath).catch(() => fail('attachment_store_not_found'));
      if (isServerPathAllowed(resolved, item?.runtimeKey) !== true) fail('attachment_store_not_found');
      const scopeDirectory = await fsp.realpath(item?.directory).catch(() => fail('attachment_store_not_found'));
      if (resolved !== scopeDirectory && !resolved.startsWith(`${scopeDirectory}${path.sep}`)) fail('attachment_store_not_found');
      const stat = await regularFile(resolved);
      if (stat.size > maxBytes || ((attachment.size ?? attachment.sizeBytes) !== undefined && stat.size !== (attachment.size ?? attachment.sizeBytes))) fail('attachment_store_not_found');
      return { stream: fs.createReadStream(resolved), size: stat.size, mime: attachment.mimeType ?? attachment.mediaType ?? 'application/octet-stream', filename: attachment.filename ?? attachment.name ?? path.basename(resolved) };
    }
    const storageKey = attachment?.locator?.kind === 'upload' ? attachment.locator.storageKey : attachment?.storageKey;
    if (!storageKey) fail('attachment_store_not_found');
    if (!validStorageKey(storageKey)) fail('attachment_store_invalid_storage_key');
    const stat = await regularFile(objectPath(storageKey));
    if (stat.size > maxBytes || ((attachment.size ?? attachment.sizeBytes) !== undefined && stat.size !== (attachment.size ?? attachment.sizeBytes))) fail('attachment_store_not_found');
    return { stream: fs.createReadStream(objectPath(storageKey)), size: stat.size, mime: attachment.mimeType ?? attachment.mediaType ?? 'application/octet-stream', filename: attachment.filename ?? attachment.name ?? 'attachment' };
  }

  async function readAttachment(attachment, item, { signal } = {}) {
    const locator = attachment?.locator;
    const serverPath = locator?.kind === 'server-path' ? locator.path : attachment?.serverPath;
    if (serverPath) {
      if (signal?.aborted) fail('attachment_store_aborted');
      const resolved = await fsp.realpath(serverPath).catch(() => fail('attachment_store_not_found'));
      if (isServerPathAllowed(resolved, item?.runtimeKey) !== true) fail('attachment_store_not_found');
      const scopeDirectory = await fsp.realpath(item?.directory).catch(() => fail('attachment_store_not_found'));
      if (resolved !== scopeDirectory && !resolved.startsWith(`${scopeDirectory}${path.sep}`)) fail('attachment_store_not_found');
      const stat = await regularFile(resolved);
      if (stat.size > maxBytes) fail('attachment_store_max_bytes');
      if ((attachment.size ?? attachment.sizeBytes) !== undefined && stat.size !== (attachment.size ?? attachment.sizeBytes)) fail('attachment_store_size_mismatch');
      return { type: 'file', mime: attachment.mimeType ?? attachment.mediaType ?? 'application/octet-stream', filename: attachment.filename ?? attachment.name ?? path.basename(resolved), url: pathToFileURL(resolved).toString() };
    }
    const storageKey = attachment?.locator?.kind === 'upload' ? attachment.locator.storageKey : attachment?.storageKey;
    if (!storageKey) return null;
    const stream = await openObject(storageKey);
    const chunks = []; let size = 0;
    for await (const chunk of stream) { size += chunk.length; if (size > maxBytes) fail('attachment_store_max_bytes'); chunks.push(chunk); }
    return { type: 'file', mime: attachment.mimeType ?? attachment.mediaType ?? 'application/octet-stream', filename: attachment.filename ?? attachment.name ?? 'attachment', url: `data:${attachment.mimeType ?? attachment.mediaType ?? 'application/octet-stream'};base64,${Buffer.concat(chunks).toString('base64')}` };
  }

  async function deleteObjectUnlocked(storageKey) {
    if (!validStorageKey(storageKey)) fail('attachment_store_invalid_storage_key');
    const pathname = objectPath(storageKey);
    try {
      await regularFile(pathname);
      await fsp.unlink(pathname);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
  async function deleteObject(storageKey) { return withStorageKeyLock(storageKey, () => deleteObjectUnlocked(storageKey)); }
  async function deleteObjectIf(storageKey, predicate) {
    if (!validStorageKey(storageKey) || typeof predicate !== 'function') fail('attachment_store_invalid_storage_key');
    return withStorageKeyLock(storageKey, async () => (await predicate() === 1 ? (await deleteObjectUnlocked(storageKey), true) : false));
  }

  async function listStaging() {
    await init();
    const entries = await fsp.readdir(staging, { withFileTypes: true });
    const result = [];
    for (const entry of entries) {
      if (!entry.isFile() || entry.isSymbolicLink() || !entry.name.endsWith('.part')) continue;
      const uploadID = entry.name.slice(0, -5);
      if (!validUploadID(uploadID)) continue;
      const stat = await regularFile(stagingPath(uploadID));
      result.push({ uploadID, size: stat.size, mtimeMs: stat.mtimeMs });
    }
    return result.sort((a, b) => a.uploadID.localeCompare(b.uploadID));
  }

  async function gc({ liveStorageKeys = new Set(), olderThan = clock(), isStorageKeyLive } = {}) {
    const cutoff = olderThan instanceof Date ? olderThan.getTime() : olderThan;
    if (!Number.isFinite(cutoff)) fail('attachment_store_invalid_gc_cutoff');
    await init();
    const live = new Set([...liveStorageKeys].filter(validStorageKey));
    let deletedObjects = 0;
    let deletedStaging = 0;
    for (const prefix of await fsp.readdir(objects, { withFileTypes: true })) {
      if (!/^[a-f0-9]{2}$/.test(prefix.name) || !prefix.isDirectory() || prefix.isSymbolicLink()) continue;
      const prefixPath = path.join(objects, prefix.name);
      for (const entry of await fsp.readdir(prefixPath, { withFileTypes: true })) {
        if (!validStorageKey(entry.name) || entry.name.slice(0, 2) !== prefix.name || !entry.isFile() || entry.isSymbolicLink() || live.has(entry.name)) continue;
        const pathname = path.join(prefixPath, entry.name);
        const deleted = await withStorageKeyLock(entry.name, async () => {
          if (typeof isStorageKeyLive === 'function' && await isStorageKeyLive(entry.name)) return false;
          const stat = await regularFile(pathname);
          if (stat.mtimeMs >= cutoff) return false;
          await fsp.unlink(pathname);
          return true;
        }).catch(() => false);
        if (deleted) deletedObjects += 1;
      }
    }
    for (const item of await listStaging()) {
      if (item.mtimeMs < cutoff) { await deleteStaging(item.uploadID); deletedStaging += 1; }
    }
    return { deletedObjects, deletedStaging };
  }

  return { init, writeUpload, openObject, openAttachment, readAttachment, deleteStaging, deleteObject, deleteObjectIf, listStaging, gc, close: async () => {}, stop: async () => {} };
}
