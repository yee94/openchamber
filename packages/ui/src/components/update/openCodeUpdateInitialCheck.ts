const INITIAL_CHECK_DELAY_MS = 5_000;

type TimerId = ReturnType<typeof setTimeout>;

type Timers = {
  setTimeout: (callback: () => void, delay: number) => TimerId;
  clearTimeout: (timerId: TimerId) => void;
};

const defaultTimers: Timers = {
  setTimeout: (callback, delay) => globalThis.setTimeout(callback, delay),
  clearTimeout: (timerId) => globalThis.clearTimeout(timerId),
};

export function scheduleOpenCodeUpdateInitialCheck(
  enabled: boolean,
  checkForUpdate: () => Promise<unknown>,
  timers: Timers = defaultTimers,
) {
  if (!enabled) return () => undefined;

  const timerId = timers.setTimeout(() => {
    void checkForUpdate().catch(() => undefined);
  }, INITIAL_CHECK_DELAY_MS);

  return () => timers.clearTimeout(timerId);
}
