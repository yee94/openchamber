import { describe, expect, test } from 'vitest';

import { fileUriToPath, languageIdForPath, pathToFileUri } from './lspUris';

describe('pathToFileUri / fileUriToPath', () => {
  test('round-trips a unix path', () => {
    expect(pathToFileUri('/repo/src/app.ts')).toBe('file:///repo/src/app.ts');
    expect(fileUriToPath('file:///repo/src/app.ts')).toBe('/repo/src/app.ts');
  });

  test('round-trips a windows path', () => {
    expect(pathToFileUri('C:/repo/src/app.ts')).toBe('file:///C:/repo/src/app.ts');
    expect(fileUriToPath('file:///C:/repo/src/app.ts')).toBe('C:/repo/src/app.ts');
  });

  test('rejects non-file URIs', () => {
    expect(fileUriToPath('https://example.com/a.ts')).toBeNull();
  });
});

describe('languageIdForPath', () => {
  test('maps TS/JS extensions', () => {
    expect(languageIdForPath('a.tsx')).toBe('typescriptreact');
    expect(languageIdForPath('a.ts')).toBe('typescript');
    expect(languageIdForPath('a.jsx')).toBe('javascriptreact');
    expect(languageIdForPath('a.mjs')).toBe('javascript');
    expect(languageIdForPath('a.py')).toBeNull();
  });
});
