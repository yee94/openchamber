import { describe, expect, test } from 'bun:test';
import type { Session } from '@opencode-ai/sdk/v2';

import {
  isPathWithinProject,
  sortProjectsByRecentSessionActivity,
} from './utils';

const session = (id: string, directory: string, updated: number): Session =>
  ({
    id,
    directory,
    time: { updated, created: updated - 1000 },
  }) as Session;

describe('isPathWithinProject', () => {
  test('matches child directories for root projects', () => {
    expect(isPathWithinProject('/workspace/app', '/')).toBe(true);
  });

  test('matches exact project directories', () => {
    expect(isPathWithinProject('/workspace/app', '/workspace/app')).toBe(true);
  });

  test('does not match sibling directory prefixes', () => {
    expect(isPathWithinProject('/workspace/app2', '/workspace/app')).toBe(false);
  });

  test('returns false when directory is null', () => {
    expect(isPathWithinProject(null, '/workspace/app')).toBe(false);
  });

  test('returns false when projectPath is null', () => {
    expect(isPathWithinProject('/workspace/app', null)).toBe(false);
  });

  test('matches deep child directories', () => {
    expect(isPathWithinProject('/workspace/app/sub/dir', '/workspace/app')).toBe(true);
  });
});

describe('sortProjectsByRecentSessionActivity', () => {
  test('orders projects by the newest session update under each project', () => {
    const projects = [
      { normalizedPath: '/alpha', label: 'Alpha', addedAt: 1 },
      { normalizedPath: '/beta', label: 'Beta', addedAt: 2 },
    ];
    const sessions = [
      session('s1', '/alpha', 100),
      session('s2', '/beta', 500),
    ];

    const sorted = sortProjectsByRecentSessionActivity(projects, (project) => {
      const latest = sessions
        .filter((entry) => entry.directory === project.normalizedPath)
        .reduce((max, entry) => Math.max(max, entry.time?.updated ?? 0), 0);
      return latest;
    });

    expect(sorted.map((project) => project.normalizedPath)).toEqual(['/beta', '/alpha']);
  });

  test('falls back to lastOpenedAt when a project has no sessions', () => {
    const projects = [
      { normalizedPath: '/alpha', label: 'Alpha', lastOpenedAt: 50 },
      { normalizedPath: '/beta', label: 'Beta', lastOpenedAt: 200 },
    ];

    const sorted = sortProjectsByRecentSessionActivity(projects, () => 0);

    expect(sorted.map((project) => project.normalizedPath)).toEqual(['/beta', '/alpha']);
  });
});
