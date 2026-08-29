import { describe, expect, test } from 'vitest';

import { fileUriToPath } from './lspUris';

describe('lsp location mapping', () => {
  test('file URIs from tsserver stay absolute', () => {
    expect(fileUriToPath('file:///repo/src/util.ts')).toBe('/repo/src/util.ts');
  });
});
