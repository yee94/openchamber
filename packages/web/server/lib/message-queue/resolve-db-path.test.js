import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { resolveMessageQueueDbPath } from './resolve-db-path.js';

describe('resolveMessageQueueDbPath', () => {
  it('uses the data directory default and honors explicit disabling', () => {
    expect(resolveMessageQueueDbPath({}, '/data')).toBe(path.join('/data', 'message-queue.sqlite'));
    expect(resolveMessageQueueDbPath({ messageQueueDbPath: null }, '/data')).toBeNull();
  });
  it('keeps an explicit path', () => expect(resolveMessageQueueDbPath({ messageQueueDbPath: '/tmp/q.sqlite' }, '/data')).toBe('/tmp/q.sqlite'));
});
