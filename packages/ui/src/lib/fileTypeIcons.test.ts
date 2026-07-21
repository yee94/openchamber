import { describe, expect, test } from 'bun:test';

import { getFileTypeIconHref } from './fileTypeIcons';

describe('getFileTypeIconHref', () => {
  test('uses the folder glyph for directory attachments', () => {
    expect(getFileTypeIconHref('opencode', { isDirectory: true })).toBe('#folder');
    expect(getFileTypeIconHref('opencode', { isDirectory: true, themeVariant: 'light' })).toBe('#folder_light');
  });

  test('keeps the document fallback for extensionless files', () => {
    expect(getFileTypeIconHref('opencode')).toBe('#document');
  });
});
