import { describe, expect, test } from 'vitest';

import {
  buildFileGitDecorationIndex,
  classifyGitStatusFile,
  decorateFileTreeChildren,
  ghostChildrenForDirectory,
  lookupFileGitDecoration,
  lookupFolderGitBadge,
  mergeDirectoryGhostNodes,
} from './fileGitDecorations';

describe('classifyGitStatusFile', () => {
  test('prefers a working-tree delete over a staged modify', () => {
    expect(classifyGitStatusFile({ path: 'a.ts', index: 'M', working_dir: 'D' })).toEqual({
      kind: 'deleted',
      code: 'D',
    });
  });

  test('treats untracked as its own status', () => {
    expect(classifyGitStatusFile({ path: 'new.ts', index: '?', working_dir: '?' })).toEqual({
      kind: 'untracked',
      code: '?',
    });
  });

  test('reads staged add when the worktree is clean', () => {
    expect(classifyGitStatusFile({ path: 'new.ts', index: 'A', working_dir: ' ' })).toEqual({
      kind: 'added',
      code: 'A',
    });
  });
});

describe('buildFileGitDecorationIndex', () => {
  const files = [
    { path: 'src/keep.ts', index: 'M', working_dir: ' ' },
    { path: 'src/gone.ts', index: 'D', working_dir: ' ' },
    { path: 'src/lib/nested.ts', index: ' ', working_dir: '?' },
  ];

  test('indexes absolute paths and folder badges including deletes', () => {
    const index = buildFileGitDecorationIndex(files, '/repo');
    expect(lookupFileGitDecoration(index, '/repo/src/keep.ts', '/repo')?.code).toBe('M');
    expect(lookupFileGitDecoration(index, '/repo/src/gone.ts', '/repo')?.kind).toBe('deleted');
    expect(lookupFolderGitBadge(index, '/repo/src')).toEqual({
      modified: 1,
      added: 1,
      deleted: 1,
    });
  });
});

describe('ghost nodes', () => {
  const files = [
    { path: 'src/gone.ts', index: 'D', working_dir: ' ' },
    { path: 'src/missing/dir/file.ts', index: ' ', working_dir: 'D' },
    { path: 'src/keep.ts', index: 'M', working_dir: 'M' },
  ];

  test('injects deleted files and missing parent directories', () => {
    const existing = [
      { name: 'keep.ts', path: '/repo/src/keep.ts', type: 'file' as const },
    ];
    const merged = mergeDirectoryGhostNodes(existing, '/repo/src', '/repo', files);
    expect(merged.map((node) => node.name)).toEqual(['missing', 'gone.ts', 'keep.ts']);
    expect(merged.find((node) => node.name === 'gone.ts')?.ghost).toBe(true);
    expect(merged.find((node) => node.name === 'missing')?.type).toBe('directory');
  });

  test('keeps the original array when nothing is missing', () => {
    const existing = [
      { name: 'gone.ts', path: '/repo/src/gone.ts', type: 'file' as const },
      { name: 'keep.ts', path: '/repo/src/keep.ts', type: 'file' as const },
      { name: 'missing', path: '/repo/src/missing', type: 'directory' as const },
    ];
    expect(mergeDirectoryGhostNodes(existing, '/repo/src', '/repo', files)).toBe(existing);
  });

  test('lists ghost children for a deleted directory without a disk listing', () => {
    const children = ghostChildrenForDirectory('/repo/src/missing', '/repo', files);
    expect(children).toEqual([
      {
        name: 'dir',
        path: '/repo/src/missing/dir',
        type: 'directory',
        ghost: true,
      },
    ]);
  });

  test('decorateFileTreeChildren reuses the input object when no ghosts are added', () => {
    const childrenByDir = {
      '/repo': [{ name: 'src', path: '/repo/src', type: 'directory' as const }],
    };
    expect(decorateFileTreeChildren(childrenByDir, '/repo', [
      { path: 'src/keep.ts', index: 'M', working_dir: 'M' },
    ])).toBe(childrenByDir);
  });
});
