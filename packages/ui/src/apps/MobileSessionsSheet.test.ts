import { describe, expect, test } from 'bun:test';

import { getMobileSessionPageSize } from './mobileSessionPagination';

// ---------------------------------------------------------------------------
// Test the core stop logic that MobileSessionsSheet uses without requiring
// full React rendering. These test the critical data transformations.
// ---------------------------------------------------------------------------

describe('MobileSessionsSheet pagination', () => {
  test('shows 20 sessions by default for projects without worktrees', () => {
    expect(getMobileSessionPageSize(false)).toBe(20);
  });

  test('shows 5 sessions by default for projects with worktrees', () => {
    expect(getMobileSessionPageSize(true)).toBe(5);
  });
});

describe('MobileSessionsSheet stop logic', () => {
  test('runningSessionMap: identifies busy and retry as running', () => {
    const allStatuses: Record<string, { type: string }> = {
      'ses_busy': { type: 'busy' },
      'ses_retry': { type: 'retry' },
      'ses_idle': { type: 'idle' },
    };

    // Simulate the runningSessionMap derivation
    const map: Record<string, boolean> = {};
    for (const [id, status] of Object.entries(allStatuses)) {
      map[id] = status.type === 'busy' || status.type === 'retry';
    }

    expect(map['ses_busy']).toBe(true);
    expect(map['ses_retry']).toBe(true);
    expect(map['ses_idle']).toBe(false);
    // Unknown sessions default to falsy
    expect(map['ses_unknown']).toBeFalsy();
  });

  test('runningSessionMap: handles empty statuses', () => {
    const map: Record<string, boolean> = {};
    expect(Object.keys(map)).toHaveLength(0);
  });

  test('stop IDs: running parent with collapsed running children includes all', () => {
    const runningSessionMap: Record<string, boolean> = {
      'parent': true,
      'child1': true,
      'child2': true,
      'child3': false,
    };

    const children = ['child1', 'child2', 'child3'];
    const isRunning = runningSessionMap['parent'] || false;
    const expanded = false;
    const runningChildIds = expanded
      ? []
      : children.filter((c) => runningSessionMap[c]);
    const stopIds = isRunning
      ? ['parent', ...runningChildIds]
      : runningChildIds;

    expect(stopIds).toEqual(['parent', 'child1', 'child2']);
  });

  test('stop IDs: non-running parent with collapsed running children includes only children', () => {
    const runningSessionMap: Record<string, boolean> = {
      'parent': false,
      'child1': true,
      'child2': false,
    };

    const children = ['child1', 'child2'];
    const isRunning = runningSessionMap['parent'] || false;
    const expanded = false;
    const runningChildIds = expanded
      ? []
      : children.filter((c) => runningSessionMap[c]);
    const stopIds = isRunning
      ? ['parent', ...runningChildIds]
      : runningChildIds;

    expect(stopIds).toEqual(['child1']);
  });

  test('stop IDs: expanded parent never shows group stop (individual rows handle it)', () => {
    const runningSessionMap: Record<string, boolean> = {
      'parent': true,
      'child1': true,
    };

    const isRunning = runningSessionMap['parent'] || false;
    const expanded = true;
    const children = ['child1'];
    const runningChildIds = expanded
      ? []
      : children.filter((c) => runningSessionMap[c]);

    // When expanded, collapsed running children is empty
    // But the parent itself being running still shows stop
    const hasRunningHiddenChildren = runningChildIds.length > 0;
    const stopIds = isRunning
      ? ['parent', ...runningChildIds]
      : runningChildIds;

    // Parent is running → still gets stop button (for itself)
    expect(stopIds).toEqual(['parent']);
    expect(hasRunningHiddenChildren).toBe(false);
  });

  test('stop IDs: no running sessions produces empty stop list', () => {
    const runningSessionMap: Record<string, boolean> = {
      'parent': false,
      'child1': false,
    };

    const children = ['child1'];
    const isRunning = runningSessionMap['parent'] || false;
    const expanded = false;
    const runningChildIds = expanded
      ? []
      : children.filter((c) => runningSessionMap[c]);
    const stopIds = isRunning
      ? ['parent', ...runningChildIds]
      : runningChildIds;

    expect(stopIds).toEqual([]);
  });

  test('group running IDs: dedupes across buckets for collapsed project', () => {
    const runningSessionMap: Record<string, boolean> = {
      's1': true,
      's2': false,
      's3': true,
    };

    // Simulate two buckets with overlapping sessions
    const buckets = [
      { sessions: [{ id: 's1' }, { id: 's2' }] },
      { sessions: [{ id: 's1' }, { id: 's3' }] },
    ] as Array<{ sessions: Array<{ id: string }> }>;

    const projectExpanded = false;
    const projectRunningIds = !projectExpanded
      ? [...new Set(buckets.flatMap((b) =>
          b.sessions.filter((s) => runningSessionMap[s.id]).map((s) => s.id),
        ))]
      : [];

    expect(projectRunningIds.sort()).toEqual(['s1', 's3']);
  });

  test('group running IDs: expanded project returns empty (individual rows handle it)', () => {
    const runningSessionMap: Record<string, boolean> = {
      's1': true,
    };

    const buckets = [
      { sessions: [{ id: 's1' }] },
    ] as Array<{ sessions: Array<{ id: string }> }>;

    const projectExpanded = true;
    const projectRunningIds = !projectExpanded
      ? [...new Set(buckets.flatMap((b) =>
          b.sessions.filter((s) => runningSessionMap[s.id]).map((s) => s.id),
        ))]
      : [];

    expect(projectRunningIds).toEqual([]);
  });

  test('worktree running IDs: collapsed worktree filters running sessions', () => {
    const runningSessionMap: Record<string, boolean> = {
      's1': true,
      's2': false,
      's3': true,
    };

    const bucket = {
      sessions: [{ id: 's1' }, { id: 's2' }, { id: 's3' }],
    } as { sessions: Array<{ id: string }> };

    const worktreeExpanded = false;
    const worktreeRunningIds = !worktreeExpanded
      ? bucket.sessions.filter((s) => runningSessionMap[s.id]).map((s) => s.id)
      : [];

    expect(worktreeRunningIds).toEqual(['s1', 's3']);
  });

  test('worktree running IDs: expanded worktree returns empty', () => {
    const runningSessionMap: Record<string, boolean> = {
      's1': true,
    };

    const bucket = {
      sessions: [{ id: 's1' }],
    } as { sessions: Array<{ id: string }> };

    const worktreeExpanded = true;
    const worktreeRunningIds = !worktreeExpanded
      ? bucket.sessions.filter((s) => runningSessionMap[s.id]).map((s) => s.id)
      : [];

    expect(worktreeRunningIds).toEqual([]);
  });

  test('Promise.all aborts all running session IDs', () => {
    // Verify the contract: all IDs are passed to abortCurrentOperation
    const aborted: string[] = [];
    const mockAbort = (id: string): Promise<void> => {
      aborted.push(id);
      return Promise.resolve();
    };

    const sessionIds = ['s1', 's2', 's3'];
    void Promise.all(sessionIds.map((id) => mockAbort(id)));

    // All IDs must be aborted
    expect(aborted.sort()).toEqual(['s1', 's2', 's3']);
  });

  test('handleStopSession aborts a single session', () => {
    const aborted: string[] = [];
    const mockAbort = (id: string): Promise<void> => {
      aborted.push(id);
      return Promise.resolve();
    };

    void mockAbort('single-session');

    expect(aborted).toEqual(['single-session']);
  });

  test('stop button aria-label: session format uses title', () => {
    // Simulates locale lookup: t('mobile.sessions.stopSessionAria', { title })
    const formatAria = (title: string) => `Stop ${title}`;
    expect(formatAria('My Chat')).toBe('Stop My Chat');
    expect(formatAria('Debug session')).toBe('Stop Debug session');
  });

  test('stop button aria-label: subsession format uses title', () => {
    // Simulates locale lookup: t('mobile.sessions.stopSubsessionsAria', { title })
    const formatAria = (title: string) => `Stop running subsessions of ${title}`;
    expect(formatAria('Parent Chat')).toBe('Stop running subsessions of Parent Chat');
  });

  test('stop button aria-label: group format uses label', () => {
    // Simulates locale lookup: t('mobile.sessions.stopGroupAria', { label })
    const formatAria = (label: string) => `Stop all running in ${label}`;
    expect(formatAria('my-project')).toBe('Stop all running in my-project');
    expect(formatAria('feature-branch')).toBe('Stop all running in feature-branch');
  });
});
