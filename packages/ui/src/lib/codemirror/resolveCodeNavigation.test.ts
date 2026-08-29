import { describe, expect, test, vi } from 'vitest';

import { resolveCodeNavigation } from './resolveCodeNavigation';

const SAMPLE = `import { helper } from './util';\n\nexport function helper() {\n  return 1;\n}\n\nexport function caller() {\n  return helper();\n}\n`;

describe('resolveCodeNavigation', () => {
  test('jumps to a same-file function definition', async () => {
    const target = await resolveCodeNavigation({
      kind: 'identifier',
      text: 'helper',
      from: 0,
      to: 6,
      filePath: '/repo/src/app.ts',
      line: 8,
    }, {
      files: {},
      directory: '/repo',
      currentContent: SAMPLE,
    });
    expect(target).toEqual({ path: '/repo/src/app.ts', line: 3 });
  });

  test('opens a relative import when the candidate file exists', async () => {
    const statFile = vi.fn(async (path: string) => ({
      path,
      isFile: path === '/repo/src/util.ts',
      size: 10,
    }));
    const target = await resolveCodeNavigation({
      kind: 'import-path',
      text: './util',
      from: 0,
      to: 8,
      filePath: '/repo/src/app.ts',
      line: 1,
    }, {
      files: { statFile },
      directory: '/repo',
      currentContent: SAMPLE,
    });
    expect(target).toEqual({ path: '/repo/src/util.ts', line: 1 });
  });
});
