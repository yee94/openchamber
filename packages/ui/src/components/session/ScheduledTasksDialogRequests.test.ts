import { describe, expect, test } from 'bun:test';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

describe('ScheduledTasksDialog queries', () => {
  test('scopes cached tasks and mutation invalidation by runtime and project', async () => {
    const content = await readFile(join(dirname(fileURLToPath(import.meta.url)), 'ScheduledTasksDialog.tsx'), 'utf8');
    expect(content).toContain("queryKeys.scoped('scheduled-tasks', selectedProjectID)");
    expect(content).toContain('useQuery({');
    expect(content).toContain('useMutation({');
    expect(content).toContain("queryKeys.scoped('scheduled-tasks', projectID)");
    expect(content).toContain('tasksQuery.error ? (');
  });
});
