type QueuedTask = {
    cancelled: boolean;
    consumed: boolean;
    next: QueuedTask | null;
    previous: QueuedTask | null;
    priority: AfterPaintTaskPriority;
    run: () => void;
};

type TaskLane = {
    head: QueuedTask | null;
    tail: QueuedTask | null;
};

type AfterPaintTaskPriority = 'user-blocking' | 'visible' | 'background';

type AfterPaintTaskOptions = {
    priority?: AfterPaintTaskPriority;
};

type AfterPaintTaskQueueOptions = {
    requestFrame: (callback: FrameRequestCallback) => number;
    cancelFrame: (handle: number) => void;
    now: () => number;
    maxTasksPerFrame: number;
    frameBudgetMs: number;
};

type AfterPaintTaskQueue = {
    enqueue: (task: () => void, taskOptions?: AfterPaintTaskOptions) => () => void;
    clear: () => void;
};

const PRIORITY_ORDER: readonly AfterPaintTaskPriority[] = [
    'user-blocking',
    'visible',
    'background',
];

export const createAfterPaintTaskQueue = (
    options: AfterPaintTaskQueueOptions,
): AfterPaintTaskQueue => {
    const pending: Record<AfterPaintTaskPriority, TaskLane> = {
        'user-blocking': { head: null, tail: null },
        visible: { head: null, tail: null },
        background: { head: null, tail: null },
    };
    const maxTasksPerFrame = Math.max(1, Math.floor(options.maxTasksPerFrame));
    const frameBudgetMs = Math.max(1, options.frameBudgetMs);
    let scheduledFrame: number | null = null;
    let awaitingFirstPaint = false;
    let runnableTaskCount = 0;

    const appendTask = (task: QueuedTask): void => {
        const lane = pending[task.priority];
        task.previous = lane.tail;
        if (lane.tail) {
            lane.tail.next = task;
        } else {
            lane.head = task;
        }
        lane.tail = task;
    };

    const removeTask = (task: QueuedTask): void => {
        const lane = pending[task.priority];
        if (task.previous) {
            task.previous.next = task.next;
        } else {
            lane.head = task.next;
        }
        if (task.next) {
            task.next.previous = task.previous;
        } else {
            lane.tail = task.previous;
        }
        task.next = null;
        task.previous = null;
    };

    const takeNextTask = (): QueuedTask | null => {
        for (const priority of PRIORITY_ORDER) {
            const task = pending[priority].head;
            if (task) {
                removeTask(task);
                task.consumed = true;
                runnableTaskCount -= 1;
                return task;
            }
        }
        return null;
    };

    const scheduleDrain = (): void => {
        if (scheduledFrame !== null || runnableTaskCount === 0) {
            return;
        }
        scheduledFrame = options.requestFrame(drain);
    };

    const drain = (): void => {
        scheduledFrame = null;
        const startedAt = options.now();
        let completed = 0;

        while (runnableTaskCount > 0 && completed < maxTasksPerFrame) {
            const task = takeNextTask();
            if (!task) {
                break;
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
        if (scheduledFrame !== null || awaitingFirstPaint || runnableTaskCount === 0) {
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
        enqueue(task, taskOptions) {
            const priority = taskOptions?.priority ?? 'background';
            const entry: QueuedTask = {
                cancelled: false,
                consumed: false,
                next: null,
                previous: null,
                priority,
                run: task,
            };
            appendTask(entry);
            runnableTaskCount += 1;
            const cancel = () => {
                if (entry.cancelled || entry.consumed) return;
                entry.cancelled = true;
                removeTask(entry);
                runnableTaskCount -= 1;
                if (runnableTaskCount === 0) {
                    if (scheduledFrame !== null) {
                        options.cancelFrame(scheduledFrame);
                        scheduledFrame = null;
                    }
                    awaitingFirstPaint = false;
                }
            };
            if (!awaitingFirstPaint && scheduledFrame === null) {
                scheduleAfterInitialPaint();
            }
            return cancel;
        },
        clear() {
            for (const priority of PRIORITY_ORDER) {
                const lane = pending[priority];
                let task = lane.head;
                while (task) {
                    const next = task.next;
                    task.cancelled = true;
                    task.next = null;
                    task.previous = null;
                    task = next;
                }
                lane.head = null;
                lane.tail = null;
            }
            runnableTaskCount = 0;
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

export const scheduleAfterPaintTask = (
    task: () => void,
    options?: AfterPaintTaskOptions,
): (() => void) => {
    const queue = getBrowserQueue();
    if (!queue) {
        task();
        return () => {};
    }
    return queue.enqueue(task, options);
};
