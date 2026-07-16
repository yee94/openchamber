import { opencodeClient } from '@/lib/opencode/client';
import { getRuntimeKey } from '@/lib/runtime-switch';

const DEFAULT_RETRY_DELAYS_MS = [0, 250, 500, 1_000, 2_000, 2_000, 2_000, 2_000] as const;
const DEFAULT_FAILURE_COOLDOWN_MS = 5_000;

type RuntimeReadinessDependencies = {
  probe: (runtimeKey: string) => Promise<boolean>;
  wait: (delayMs: number) => Promise<void>;
  retryDelaysMs?: readonly number[];
  failureCooldownMs?: number;
  now?: () => number;
};

type RuntimeReadinessCoordinator = {
  waitUntilReady: (runtimeKey: string) => Promise<void>;
  reset: (runtimeKey?: string) => void;
};

export const createRuntimeReadinessCoordinator = (
  dependencies: RuntimeReadinessDependencies,
): RuntimeReadinessCoordinator => {
  const inflightByRuntime = new Map<string, Promise<void>>();
  const readyRuntimes = new Set<string>();
  const failedAtByRuntime = new Map<string, number>();
  const runtimeGenerations = new Map<string, number>();
  let resetGeneration = 0;

  const getGeneration = (runtimeKey: string): string => (
    `${resetGeneration}:${runtimeGenerations.get(runtimeKey) ?? 0}`
  );

  const waitUntilReady = (runtimeKey: string): Promise<void> => {
    if (readyRuntimes.has(runtimeKey)) return Promise.resolve();
    const existing = inflightByRuntime.get(runtimeKey);
    if (existing) return existing;

    const now = dependencies.now ?? Date.now;
    const failureCooldownMs = dependencies.failureCooldownMs ?? DEFAULT_FAILURE_COOLDOWN_MS;
    const failedAt = failedAtByRuntime.get(runtimeKey);
    if (failedAt !== undefined && now() - failedAt < failureCooldownMs) {
      return Promise.reject(new Error(`OpenCode readiness is cooling down for runtime ${runtimeKey}`));
    }

    const retryDelaysMs = dependencies.retryDelaysMs ?? DEFAULT_RETRY_DELAYS_MS;
    const generation = getGeneration(runtimeKey);
    const readiness = (async () => {
      for (const delayMs of retryDelaysMs) {
        if (getGeneration(runtimeKey) !== generation) return;
        if (delayMs > 0) await dependencies.wait(delayMs);
        if (getGeneration(runtimeKey) !== generation) return;
        if (await dependencies.probe(runtimeKey)) {
          if (getGeneration(runtimeKey) === generation) {
            readyRuntimes.add(runtimeKey);
            failedAtByRuntime.delete(runtimeKey);
          }
          return;
        }
      }
      failedAtByRuntime.set(runtimeKey, now());
      throw new Error(`OpenCode did not become ready for runtime ${runtimeKey}`);
    })();
    inflightByRuntime.set(runtimeKey, readiness);
    void readiness.finally(() => {
      if (inflightByRuntime.get(runtimeKey) === readiness) {
        inflightByRuntime.delete(runtimeKey);
      }
    }).catch(() => {});
    return readiness;
  };

  return {
    waitUntilReady,
    reset: (runtimeKey) => {
      if (runtimeKey) {
        runtimeGenerations.set(runtimeKey, (runtimeGenerations.get(runtimeKey) ?? 0) + 1);
        inflightByRuntime.delete(runtimeKey);
        readyRuntimes.delete(runtimeKey);
        failedAtByRuntime.delete(runtimeKey);
        return;
      }
      resetGeneration += 1;
      inflightByRuntime.clear();
      readyRuntimes.clear();
      failedAtByRuntime.clear();
    },
  };
};

const runtimeReadiness = createRuntimeReadinessCoordinator({
  probe: () => opencodeClient.checkHealth(),
  wait: (delayMs) => new Promise((resolve) => setTimeout(resolve, delayMs)),
});

export const waitForOpenCodeReadiness = (): Promise<void> => (
  runtimeReadiness.waitUntilReady(getRuntimeKey())
);

export const resetOpenCodeReadiness = (runtimeKey?: string): void => {
  runtimeReadiness.reset(runtimeKey);
};
