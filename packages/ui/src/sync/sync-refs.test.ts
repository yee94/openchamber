import { expect, test } from 'bun:test';
import { resolveMaterializedSessionDirectory, type MaterializedSessionDirectorySnapshot } from './sync-refs';

const snapshot = (sessionIDs: string[], messageIDs: string[]): MaterializedSessionDirectorySnapshot => ({
  session: sessionIDs.map((id) => ({ id })) as MaterializedSessionDirectorySnapshot['session'],
  message: Object.fromEntries(messageIDs.map((id) => [id, []])),
});

test('resolves the unique initialized directory with session identity and materialized messages', () => {
  expect(resolveMaterializedSessionDirectory('ses_loaded', undefined, [
    ['/project-a', snapshot(['ses_loaded'], ['ses_loaded'])],
    ['/project-b', snapshot(['ses_other'], ['ses_other'])],
  ])).toBe('/project-a');
});

test('prefers the caller directory and leaves ambiguous cross-directory IDs unresolved', () => {
  const snapshots: Array<readonly [string, MaterializedSessionDirectorySnapshot]> = [
    ['/project-a', snapshot(['ses_shared'], ['ses_shared'])],
    ['/project-b', snapshot(['ses_shared'], ['ses_shared'])],
  ];

  expect(resolveMaterializedSessionDirectory('ses_shared', '/project-b', snapshots)).toBe('/project-b');
  expect(resolveMaterializedSessionDirectory('ses_shared', undefined, snapshots)).toBe(undefined);
});

test('requires both session identity and a readable message snapshot key', () => {
  expect(resolveMaterializedSessionDirectory('ses_missing', undefined, [
    ['/project-a', snapshot(['ses_missing'], [])],
    ['/project-b', snapshot([], ['ses_missing'])],
  ])).toBe(undefined);
});
