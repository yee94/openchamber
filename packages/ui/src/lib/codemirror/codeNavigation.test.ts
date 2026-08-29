import { describe, expect, test } from 'vitest';

import {
  findSameFileDefinitionLine,
  importPathCandidates,
  resolveRelativeImportPath,
  scoreDefinitionPreview,
  tokenAtOffset,
} from './codeNavigation';

const SAMPLE = `import { helper } from './util';\n\nexport function helper() {\n  return 1;\n}\n\nexport function caller() {\n  return helper();\n}\n`;

describe('tokenAtOffset', () => {
  test('reads an import path from a quoted specifier', () => {
    const fromIndex = SAMPLE.indexOf("'./util'");
    const token = tokenAtOffset(SAMPLE, fromIndex + 4);
    expect(token).toEqual({
      kind: 'import-path',
      text: './util',
      from: fromIndex,
      to: fromIndex + 8,
    });
  });

  test('reads the identifier under the cursor', () => {
    const call = SAMPLE.lastIndexOf('helper()');
    const token = tokenAtOffset(SAMPLE, call + 1);
    expect(token?.kind).toBe('identifier');
    expect(token?.text).toBe('helper');
  });
});

describe('resolveRelativeImportPath', () => {
  test('resolves a sibling import', () => {
    expect(resolveRelativeImportPath('/repo/src/app.ts', './util')).toBe('/repo/src/util');
  });

  test('ignores bare package specifiers', () => {
    expect(resolveRelativeImportPath('/repo/src/app.ts', 'react')).toBeNull();
  });

  test('lists common file candidates', () => {
    expect(importPathCandidates('/repo/src/util')).toContain('/repo/src/util.ts');
    expect(importPathCandidates('/repo/src/util')).toContain('/repo/src/util/index.ts');
  });
});

describe('findSameFileDefinitionLine', () => {
  test('finds a function definition that is not the current line', () => {
    expect(findSameFileDefinitionLine(SAMPLE, 'helper', 8)).toBe(3);
  });

  test('skips the line the user is already on', () => {
    expect(findSameFileDefinitionLine(SAMPLE, 'helper', 3)).toBeNull();
  });

  test('scores a preview that looks like a definition', () => {
    expect(scoreDefinitionPreview('helper', ['export function helper() {'])).toBe(2);
    expect(scoreDefinitionPreview('helper', ['return helper();'])).toBe(0);
  });
});
