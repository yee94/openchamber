import { describe, expect, test } from 'vitest';

import { computeDirtyLineMarks, marksForGitGutter } from './gitGutter';

describe('computeDirtyLineMarks', () => {
  test('returns no marks when the documents match', () => {
    expect(computeDirtyLineMarks('a\nb\n', 'a\nb\n')).toEqual([]);
  });

  test('marks inserted lines as added', () => {
    expect(computeDirtyLineMarks('a\nc\n', 'a\nb\nc\n')).toEqual([
      { line: 2, kind: 'add' },
    ]);
  });

  test('marks a replacement as modified', () => {
    expect(computeDirtyLineMarks('a\nold\nc\n', 'a\nnew\nc\n')).toEqual([
      { line: 2, kind: 'mod' },
    ]);
  });

  test('places a delete marker on the following current line', () => {
    expect(computeDirtyLineMarks('a\ngone\nc\n', 'a\nc\n')).toEqual([
      { line: 2, kind: 'del' },
    ]);
  });

  test('keeps two separated hunks distinct', () => {
    expect(computeDirtyLineMarks('a\nb\nc\nd\n', 'a\nB\nc\nD\n')).toEqual([
      { line: 2, kind: 'mod' },
      { line: 4, kind: 'mod' },
    ]);
  });
});

describe('marksForGitGutter', () => {
  test('paints every line for an untracked file', () => {
    expect(marksForGitGutter({ kind: 'untracked', baseline: '' }, 'one\ntwo')).toEqual([
      { line: 1, kind: 'add' },
      { line: 2, kind: 'add' },
    ]);
  });

  test('stays empty when gutter is off', () => {
    expect(marksForGitGutter({ kind: 'off', baseline: 'old' }, 'new')).toEqual([]);
  });
});
