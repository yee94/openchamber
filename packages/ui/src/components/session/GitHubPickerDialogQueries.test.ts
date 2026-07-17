import { describe, expect, test } from 'bun:test';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = dirname(fileURLToPath(import.meta.url));

describe('GitHub picker queries', () => {
  test('scopes infinite search queries by runtime, project, and search text', async () => {
    const [pullRequests, issues] = await Promise.all([
      readFile(join(directory, 'GitHubPrPickerDialog.tsx'), 'utf8'),
      readFile(join(directory, 'GitHubIssuePickerDialog.tsx'), 'utf8'),
    ]);

    for (const content of [pullRequests, issues]) {
      expect(content).toContain('useInfiniteQuery({');
      expect(content).toContain("queryKeys.scoped('github-");
      expect(content).toContain('projectDirectory, searchQuery');
      expect(content).toContain('getNextPageParam:');
      expect(content).toContain('&& !error && connected && github && projectDirectory');
    }
  });
});
