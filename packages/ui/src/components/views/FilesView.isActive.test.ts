import { describe, expect, mock, test } from 'bun:test';

mock.module('../chat/markdown/markdown-shiki.worker.ts?worker&url', () => ({ default: '' }));

const { shouldPollSelectedFile } = await import('./FilesView');

describe('FilesView active polling', () => {
  test('polls an active file after its selected path has loaded', () => {
    expect(shouldPollSelectedFile(true, '/workspace/file.ts', '/workspace/file.ts')).toBe(true);
  });

  test('pauses polling while inactive', () => {
    expect(shouldPollSelectedFile(false, '/workspace/file.ts', '/workspace/file.ts')).toBe(false);
  });

  test('waits for the selected path to load', () => {
    expect(shouldPollSelectedFile(true, '/workspace/next.ts', '/workspace/file.ts')).toBe(false);
  });
});
