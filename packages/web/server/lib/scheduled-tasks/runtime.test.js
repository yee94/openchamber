import { describe, expect, it, vi } from 'vitest';
import { computeNextRunAt, createScheduledTasksRuntime, formatScheduledSessionTitle, parseScheduledCommandPrompt } from './runtime.js';

const scheduledTask = {
  id: 'task-1',
  name: 'Task',
  enabled: true,
  schedule: { kind: 'daily', times: ['23:59'], timezone: 'UTC' },
  execution: { prompt: 'run', providerID: 'openai', modelID: 'gpt-4.1' },
  state: { createdAt: 1, updatedAt: 1, lastStatus: 'idle' },
};

const createRuntime = (updateScheduledTaskState) => createScheduledTasksRuntime({
  projectConfigRuntime: {
    listScheduledTasks: vi.fn(async () => [scheduledTask]),
    updateScheduledTaskState,
    upsertScheduledTask: vi.fn(),
  },
  listProjects: vi.fn(async () => [{ id: 'project-1', path: '/tmp/project-1' }]),
  buildOpenCodeUrl: vi.fn(() => 'http://127.0.0.1:4096'),
  getOpenCodeAuthHeaders: vi.fn(() => ({})),
  waitForOpenCodeReady: vi.fn(async () => {
    throw new Error('OpenCode unavailable');
  }),
  logger: { info: vi.fn(), warn: vi.fn() },
});

describe('scheduled-tasks runtime helpers', () => {
  it('computes next daily run in timezone', () => {
    const nowUtc = Date.UTC(2025, 0, 1, 8, 0, 0);
    const next = computeNextRunAt({
      enabled: true,
      schedule: {
        kind: 'daily',
        times: ['09:30'],
        timezone: 'UTC',
      },
    }, nowUtc);

    expect(next).toBe(Date.UTC(2025, 0, 1, 9, 30, 0));
  });

  it('computes weekly next run using weekdays', () => {
    // Monday 2025-01-06 10:00:00 UTC
    const nowUtc = Date.UTC(2025, 0, 6, 10, 0, 0);
    const next = computeNextRunAt({
      enabled: true,
      schedule: {
        kind: 'weekly',
        times: ['09:00'],
        weekdays: [1, 3],
        timezone: 'UTC',
      },
    }, nowUtc);

    // Wednesday 2025-01-08 09:00:00 UTC
    expect(next).toBe(Date.UTC(2025, 0, 8, 9, 0, 0));
  });

  it('picks nearest time from multiple daily times', () => {
    const nowUtc = Date.UTC(2025, 0, 1, 9, 20, 0);
    const next = computeNextRunAt({
      enabled: true,
      schedule: {
        kind: 'daily',
        times: ['09:15', '09:45', '18:00'],
        timezone: 'UTC',
      },
    }, nowUtc);

    expect(next).toBe(Date.UTC(2025, 0, 1, 9, 45, 0));
  });

  it('computes one-time next run for future date', () => {
    const nowUtc = Date.UTC(2026, 3, 15, 10, 0, 0);
    const next = computeNextRunAt({
      enabled: true,
      schedule: {
        kind: 'once',
        date: '2026-04-16',
        time: '13:30',
        timezone: 'UTC',
      },
    }, nowUtc);

    expect(next).toBe(Date.UTC(2026, 3, 16, 13, 30, 0));
  });

  it('returns null for past one-time schedule', () => {
    const nowUtc = Date.UTC(2026, 3, 16, 14, 0, 0);
    const next = computeNextRunAt({
      enabled: true,
      schedule: {
        kind: 'once',
        date: '2026-04-16',
        time: '13:30',
        timezone: 'UTC',
      },
    }, nowUtc);

    expect(next).toBeNull();
  });

  it('formats session title with timestamp suffix', () => {
    const title = formatScheduledSessionTitle({
      name: 'Morning Sync',
      schedule: { timezone: 'UTC' },
    }, Date.UTC(2025, 2, 10, 7, 5, 0));

    expect(title).toBe('Morning Sync 2025-03-10 07:05');
  });

  it('parses slash command prompt for scheduled command mode', () => {
    expect(parseScheduledCommandPrompt('/review src/components')).toEqual({
      command: 'review',
      arguments: 'src/components',
    });
  });

  it('returns null when prompt is not a slash command', () => {
    expect(parseScheduledCommandPrompt('Summarize open issues')).toBeNull();
    expect(parseScheduledCommandPrompt('/')).toBeNull();
  });
});

describe('scheduled-tasks runtime cleanup', () => {
  it('releases the running lock after the initial running-state write fails', async () => {
    let calls = 0;
    const updateScheduledTaskState = vi.fn(async () => {
      calls += 1;
      if (calls === 2) {
        throw new Error('initial state write failed');
      }
      return { task: scheduledTask };
    });
    const runtime = createRuntime(updateScheduledTaskState);
    await runtime.syncProject('project-1');

    const first = await runtime.runNow('project-1', 'task-1');
    const second = await runtime.runNow('project-1', 'task-1');

    expect(first).toMatchObject({ ok: false, status: 'error', error: 'initial state write failed' });
    expect(second.running).toBeUndefined();
    expect(updateScheduledTaskState).toHaveBeenCalledTimes(5);
    expect(runtime.getStatus().hasRunningScheduledTasks).toBe(false);
  });

  it('releases the running lock after the final state write fails', async () => {
    let calls = 0;
    const updateScheduledTaskState = vi.fn(async () => {
      calls += 1;
      if (calls === 3) {
        throw new Error('final state write failed');
      }
      return { task: scheduledTask };
    });
    const runtime = createRuntime(updateScheduledTaskState);
    await runtime.syncProject('project-1');

    const first = await runtime.runNow('project-1', 'task-1');
    const second = await runtime.runNow('project-1', 'task-1');

    expect(first).toMatchObject({ ok: false, status: 'error', error: 'final state write failed' });
    expect(second.running).toBeUndefined();
    expect(updateScheduledTaskState).toHaveBeenCalledTimes(5);
    expect(runtime.getStatus().hasRunningScheduledTasks).toBe(false);
  });
});

describe('scheduled-tasks project sync isolation', () => {
  it('continues syncing projects after one project fails and retries the failed project', async () => {
    vi.useFakeTimers();
    const projectConfigRuntime = {
      listScheduledTasks: vi.fn(async (projectID) => {
        if (projectID === 'project-1' && projectConfigRuntime.listScheduledTasks.mock.calls.filter(([id]) => id === projectID).length === 1) {
          throw new Error('project-1 config is unavailable');
        }
        return [{ ...scheduledTask, id: `${projectID}-task` }];
      }),
      updateScheduledTaskState: vi.fn(async (_projectID, _taskID, state) => ({
        task: { ...scheduledTask, state },
      })),
      upsertScheduledTask: vi.fn(),
    };
    const runtime = createScheduledTasksRuntime({
      projectConfigRuntime,
      listProjects: vi.fn(async () => [
        { id: 'project-1', path: '/tmp/project-1' },
        { id: 'project-2', path: '/tmp/project-2' },
      ]),
      buildOpenCodeUrl: vi.fn(),
      getOpenCodeAuthHeaders: vi.fn(),
    });

    await runtime.start();

    expect(projectConfigRuntime.listScheduledTasks).toHaveBeenCalledWith('project-2');
    expect(runtime.getStatus().hasEnabledScheduledTasks).toBe(true);

    await vi.advanceTimersByTimeAsync(1_000);

    expect(projectConfigRuntime.listScheduledTasks).toHaveBeenCalledTimes(3);
    expect(projectConfigRuntime.listScheduledTasks).toHaveBeenLastCalledWith('project-1');
    runtime.stop();
    vi.useRealTimers();
  });

  it('bounds failed project sync retries', async () => {
    vi.useFakeTimers();
    const listScheduledTasks = vi.fn(async () => {
      throw new Error('config is unavailable');
    });
    const runtime = createScheduledTasksRuntime({
      projectConfigRuntime: {
        listScheduledTasks,
        updateScheduledTaskState: vi.fn(),
        upsertScheduledTask: vi.fn(),
      },
      listProjects: vi.fn(async () => [{ id: 'project-1', path: '/tmp/project-1' }]),
      buildOpenCodeUrl: vi.fn(),
      getOpenCodeAuthHeaders: vi.fn(),
    });

    await runtime.start();
    await vi.advanceTimersByTimeAsync(3_000);

    expect(listScheduledTasks).toHaveBeenCalledTimes(4);

    await vi.advanceTimersByTimeAsync(1_000);

    expect(listScheduledTasks).toHaveBeenCalledTimes(4);
    runtime.stop();
    vi.useRealTimers();
  });

  it('clears pending project sync retries on stop', async () => {
    vi.useFakeTimers();
    const listScheduledTasks = vi.fn(async () => {
      throw new Error('config is unavailable');
    });
    const runtime = createScheduledTasksRuntime({
      projectConfigRuntime: {
        listScheduledTasks,
        updateScheduledTaskState: vi.fn(),
        upsertScheduledTask: vi.fn(),
      },
      listProjects: vi.fn(async () => [{ id: 'project-1', path: '/tmp/project-1' }]),
      buildOpenCodeUrl: vi.fn(),
      getOpenCodeAuthHeaders: vi.fn(),
    });

    await runtime.start();
    runtime.stop();
    await vi.advanceTimersByTimeAsync(1_000);

    expect(listScheduledTasks).toHaveBeenCalledTimes(1);
    vi.useRealTimers();
  });
});
