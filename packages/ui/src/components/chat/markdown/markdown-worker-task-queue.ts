import type { MarkdownWorkerJobRequest } from './markdown-worker-protocol';

type ExecuteMarkdownWorkerTask = (
  request: MarkdownWorkerJobRequest,
  isCancelled: () => boolean,
) => Promise<void>;
type YieldToWorkerEvents = () => Promise<void>;

type MarkdownWorkerTaskQueue = {
  enqueue: (request: MarkdownWorkerJobRequest) => void;
  cancel: (id: number) => void;
  whenIdle: () => Promise<void>;
};

/**
 * Serial worker-side scheduler. Visible work always overtakes queued background
 * work, while cancellation removes work that has not started yet. Shiki's
 * tokenizers are synchronous once entered, so a running task is allowed to
 * finish; its cancellation flag lets the caller suppress the stale response.
 */
export const createMarkdownWorkerTaskQueue = (
  execute: ExecuteMarkdownWorkerTask,
  yieldToWorkerEvents: YieldToWorkerEvents = () => new Promise<void>((resolve) => setTimeout(resolve, 0)),
): MarkdownWorkerTaskQueue => {
  const visible = { items: [] as MarkdownWorkerJobRequest[], head: 0 };
  const background = { items: [] as MarkdownWorkerJobRequest[], head: 0 };
  const cancelled = new Set<number>();
  const knownIds = new Set<number>();
  let drainPromise: Promise<void> | null = null;

  const takeFromLane = (lane: typeof visible): MarkdownWorkerJobRequest | undefined => {
    const request = lane.items[lane.head];
    if (!request) return undefined;
    lane.head += 1;
    if (lane.head >= lane.items.length) {
      lane.items.length = 0;
      lane.head = 0;
    }
    return request;
  };

  const takeNext = (): MarkdownWorkerJobRequest | undefined => (
    takeFromLane(visible) ?? takeFromLane(background)
  );

  const hasQueuedTasks = (): boolean => (
    visible.head < visible.items.length || background.head < background.items.length
  );

  const drain = async (): Promise<void> => {
    while (true) {
      const request = takeNext();
      if (!request) break;
      if (!cancelled.has(request.id)) {
        await execute(request, () => cancelled.has(request.id));
        // Worker messages (notably cancel and newly-visible requests) are
        // macrotasks. Yield between Shiki jobs so a promise continuation cannot
        // drain stale background work ahead of those messages.
        await yieldToWorkerEvents();
      }
      cancelled.delete(request.id);
      knownIds.delete(request.id);
    }
  };

  const ensureDrain = (): Promise<void> => {
    if (drainPromise) {
      return drainPromise;
    }
    drainPromise = drain().finally(() => {
      drainPromise = null;
      if (hasQueuedTasks()) {
        void ensureDrain();
      }
    });
    return drainPromise;
  };

  return {
    enqueue(request) {
      const target = request.priority === 'visible' ? visible : background;
      knownIds.add(request.id);
      target.items.push(request);
      void ensureDrain();
    },
    cancel(id) {
      if (knownIds.has(id)) {
        cancelled.add(id);
      }
    },
    async whenIdle() {
      while (drainPromise) {
        await drainPromise;
      }
    },
  };
};
