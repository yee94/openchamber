import { describe, expect, test } from 'bun:test';

import { createToolPatchTurnDiffs, getFirstChangedModifiedLineFromPatch } from './diffPatchUtils';

describe('getFirstChangedModifiedLineFromPatch', () => {
  test('returns the first added line instead of the hunk context start', () => {
    expect(getFirstChangedModifiedLineFromPatch(`diff --git a/src/file.ts b/src/file.ts
@@ -56,10 +56,11 @@
 unchanged 58
 unchanged 59
 unchanged 60
+changed 61
 unchanged 62`)).toBe(59);
  });

  test('returns the following modified line for deletion-only hunks', () => {
    expect(getFirstChangedModifiedLineFromPatch(`@@ -10,4 +10,3 @@
 context
-removed
 after`)).toBe(11);
  });

  test('returns null when the patch has no hunk change lines', () => {
    expect(getFirstChangedModifiedLineFromPatch('Binary files a/image.png and b/image.png differ')).toBeNull();
  });
});

describe('createToolPatchTurnDiffs', () => {
  test('preserves every file from one tool invocation', () => {
    const diffs = createToolPatchTurnDiffs([
      {
        path: 'src/a.ts',
        patch: '--- a/src/a.ts\n+++ b/src/a.ts\n@@ -1 +1 @@\n-old\n+new',
      },
      {
        path: 'src/b.ts',
        patch: '--- /dev/null\n+++ b/src/b.ts\n@@ -0,0 +1 @@\n+created',
      },
    ]);

    expect(diffs.map((diff) => diff.file)).toEqual(['src/a.ts', 'src/b.ts']);
    expect(diffs.map((diff) => diff.status)).toEqual(['modified', 'added']);
    expect(diffs.map((diff) => [diff.additions, diff.deletions])).toEqual([[1, 1], [1, 0]]);
  });

  test('drops empty and duplicate patch records', () => {
    const diffs = createToolPatchTurnDiffs([
      { path: 'src/a.ts', patch: '@@ -1 +1 @@\n-old\n+new' },
      { path: 'src/a.ts', patch: '@@ -2 +2 @@\n-left\n+right' },
      { path: 'src/b.ts', patch: '   ' },
    ]);

    expect(diffs).toHaveLength(1);
    expect(diffs[0]?.file).toBe('src/a.ts');
  });
});
