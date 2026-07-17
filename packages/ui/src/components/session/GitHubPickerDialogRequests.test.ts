import { describe, expect, test } from 'bun:test';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const source = async (filename: string) => readFile(join(dirname(fileURLToPath(import.meta.url)), filename), 'utf8');

describe('GitHub picker query requests', () => {
  test('uses a runtime-scoped infinite query for pull request search and pagination', async () => {
    const content = await source('GitHubPrPickerDialog.tsx');
    expect(content).toContain("queryKey: queryKeys.scoped('github-prs', projectDirectory, searchQuery)");
    expect(content).toContain('useInfiniteQuery({');
    expect(content).toContain('getNextPageParam:');
  });

  test('uses a runtime-scoped infinite query for issue search and pagination', async () => {
    const content = await source('GitHubIssuePickerDialog.tsx');
    expect(content).toContain("queryKey: queryKeys.scoped('github-issues', projectDirectory, searchQuery)");
    expect(content).toContain('useInfiniteQuery({');
    expect(content).toContain('getNextPageParam:');
  });
});
