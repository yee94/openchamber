type QueuedTask = {
    cancelled: boolean;
    run: () => void;
};

type AfterPaintTaskQueueOptions = {
    requestFrame: (callback: FrameRequestCallback) => number;
    cancelFrame: (handle: number) => void;
    now: () => number;
    maxTasksPerFrame: number;
    frameBudgetMs: number;
};

type AfterPaintTaskQueue = {
    enqueue: (task: () => void) => () => void;
    clear: () => void;
};

export const createAfterPaintTaskQueue = (
    options: AfterPaintTaskQueueOptions,
): AfterPaintTaskQueue => {
    const pending: QueuedTask[] = [];
    const maxTasksPerFrame = Math.max(1, Math.floor(options.maxTasksPerFrame));
    const frameBudgetMs = Math.max(1, options.frameBudgetMs);
    let scheduledFrame: number | null = null;
    let awaitingFirstPaint = false;

    const hasRunnableTask = (): boolean => pending.some((task) => !task.cancelled);

    const scheduleDrain = (): void => {
        if (scheduledFrame !== null || !hasRunnableTask()) {
            return;
        }
        scheduledFrame = options.requestFrame(drain);
    };

    const drain = (): void => {
        scheduledFrame = null;
        const startedAt = options.now();
        let completed = 0;

        while (pending.length > 0 && completed < maxTasksPerFrame) {
            const task = pending.shift();
            if (!task || task.cancelled) {
                continue;
            }
            task.run();
            completed += 1;
            if (options.now() - startedAt >= frameBudgetMs) {
                break;
            }
        }

        scheduleDrain();
    };

    const scheduleAfterInitialPaint = (): void => {
        if (scheduledFrame !== null || awaitingFirstPaint || !hasRunnableTask()) {
            return;
        }
        awaitingFirstPaint = true;
        scheduledFrame = options.requestFrame(() => {
            scheduledFrame = null;
            awaitingFirstPaint = false;
            scheduleDrain();
        });
    };

    return {
        enqueue(task) {
            const entry: QueuedTask = { cancelled: false, run: task };
            pending.push(entry);
            if (awaitingFirstPaint || scheduledFrame !== null) {
                return () => {
                    entry.cancelled = true;
                };
            }
            scheduleAfterInitialPaint();
            return () => {
                entry.cancelled = true;
            };
        },
        clear() {
            pending.length = 0;
            if (scheduledFrame !== null) {
                options.cancelFrame(scheduledFrame);
                scheduledFrame = null;
            }
            awaitingFirstPaint = false;
        },
    };
};

let browserQueue: AfterPaintTaskQueue | null = null;

const getBrowserQueue = (): AfterPaintTaskQueue | null => {
    if (typeof window === 'undefined') {
        return null;
    }
    if (browserQueue) {
        return browserQueue;
    }
    browserQueue = createAfterPaintTaskQueue({
        requestFrame: (callback) => window.requestAnimationFrame(callback),
        cancelFrame: (handle) => window.cancelAnimationFrame(handle),
        now: () => performance.now(),
        maxTasksPerFrame: 2,
        frameBudgetMs: 6,
    });
    return browserQueue;
};

export const scheduleAfterPaintTask = (task: () => void): (() => void) => {
    const queue = getBrowserQueue();
    if (!queue) {
        task();
        return () => {};
    }
    return queue.enqueue(task);
};
