import { worktreeMapsEqual } from '@/lib/worktrees/worktreeManager';
import type { WorktreeMetadata } from '@/types/worktree';

export const getMobileSessionPageSize = (hasWorktrees: boolean): number =>
  hasWorktrees ? 5 : 20;

type MobileWorktreeRefreshResult = {
  path: string;
  status: 'success' | 'failed';
  worktrees?: WorktreeMetadata[];
};

export const mergeMobileWorktreeRefreshResults = (
  previous: Map<string, WorktreeMetadata[]>,
  projectPaths: Set<string>,
  results: MobileWorktreeRefreshResult[],
): Map<string, WorktreeMetadata[]> => {
  const next = new Map<string, WorktreeMetadata[]>();
  for (const [path, worktrees] of previous) {
    if (projectPaths.has(path)) next.set(path, worktrees);
  }
  for (const result of results) {
    if (result.status === 'success') next.set(result.path, result.worktrees ?? []);
  }
  return worktreeMapsEqual(next, previous) ? previous : next;
};
