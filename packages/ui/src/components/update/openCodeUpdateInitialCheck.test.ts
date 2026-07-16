import { describe, expect, test } from 'bun:test';
import { scheduleOpenCodeUpdateInitialCheck } from './openCodeUpdateInitialCheck';

describe('scheduleOpenCodeUpdateInitialCheck', () => {
  test('calls browser timers with the global receiver', () => {
    const originalSetTimeout = globalThis.setTimeout;
    const originalClearTimeout = globalThis.clearTimeout;
    const receivers: unknown[] = [];
    const timerId = {} as ReturnType<typeof setTimeout>;
    try {
      globalThis.setTimeout = function (this: unknown) {
        receivers.push(this);
        return timerId;
      } as unknown as typeof setTimeout;
      globalThis.clearTimeout = function (this: unknown) {
        receivers.push(this);
      } as unknown as typeof clearTimeout;

      const cancel = scheduleOpenCodeUpdateInitialCheck(true, async () => undefined);
      cancel();

      expect(receivers).toEqual([globalThis, globalThis]);
    } finally {
      globalThis.setTimeout = originalSetTimeout;
      globalThis.clearTimeout = originalClearTimeout;
    }
  });

  test('schedules one five-second check and does not reschedule after failure', async () => {
    const scheduledChecks: Array<{ callback: () => void; delay: number }> = [];
    let checkCalls = 0;

    scheduleOpenCodeUpdateInitialCheck(
      true,
      () => {
        checkCalls += 1;
        return Promise.reject(new Error('OpenCode is unavailable'));
      },
      {
        setTimeout: (callback, delay) => {
          scheduledChecks.push({ callback, delay });
          return {} as ReturnType<typeof setTimeout>;
        },
        clearTimeout: () => undefined,
      },
    );

    expect(scheduledChecks).toHaveLength(1);
    expect(scheduledChecks[0]?.delay).toBe(5_000);

    scheduledChecks[0]?.callback();
    await Promise.resolve();

    expect(checkCalls).toBe(1);
    expect(scheduledChecks).toHaveLength(1);
  });

  test('cancels the scheduled check', () => {
    const clearedTimers: Array<ReturnType<typeof setTimeout>> = [];
    const timerId = {} as ReturnType<typeof setTimeout>;
    const cancel = scheduleOpenCodeUpdateInitialCheck(
      true,
      async () => undefined,
      {
        setTimeout: () => timerId,
        clearTimeout: (id) => { clearedTimers.push(id); },
      },
    );

    cancel();

    expect(clearedTimers).toEqual([timerId]);
  });

  test('does not schedule a check when disabled', () => {
    let scheduleCalls = 0;

    scheduleOpenCodeUpdateInitialCheck(
      false,
      async () => undefined,
      {
        setTimeout: () => {
          scheduleCalls += 1;
          return {} as ReturnType<typeof setTimeout>;
        },
        clearTimeout: () => undefined,
      },
    );

    expect(scheduleCalls).toBe(0);
  });
});
