import { describe, expect, test } from 'bun:test';

import { createAfterPaintTaskQueue } from './afterPaintTaskQueue';

describe('afterPaintTaskQueue', () => {
    test('waits for a paint opportunity before running queued work', () => {
        const frames: FrameRequestCallback[] = [];
        const calls: string[] = [];
        const queue = createAfterPaintTaskQueue({
            requestFrame: (callback) => {
                frames.push(callback);
                return frames.length;
            },
            cancelFrame: () => {},
            now: () => 0,
            maxTasksPerFrame: 2,
            frameBudgetMs: 6,
        });

        queue.enqueue(() => calls.push('task'));
        expect(calls).toEqual([]);

        frames.shift()?.(0);
        expect(calls).toEqual([]);

        frames.shift()?.(16);
        expect(calls).toEqual(['task']);
    });

    test('limits task fanout per frame', () => {
        const frames: FrameRequestCallback[] = [];
        const calls: number[] = [];
        const queue = createAfterPaintTaskQueue({
            requestFrame: (callback) => {
                frames.push(callback);
                return frames.length;
            },
            cancelFrame: () => {},
            now: () => 0,
            maxTasksPerFrame: 2,
            frameBudgetMs: 6,
        });

        queue.enqueue(() => calls.push(1));
        queue.enqueue(() => calls.push(2));
        queue.enqueue(() => calls.push(3));
        frames.shift()?.(0);
        frames.shift()?.(16);
        expect(calls).toEqual([1, 2]);

        frames.shift()?.(32);
        expect(calls).toEqual([1, 2, 3]);
    });

    test('skips cancelled tasks', () => {
        const frames: FrameRequestCallback[] = [];
        const calls: string[] = [];
        const queue = createAfterPaintTaskQueue({
            requestFrame: (callback) => {
                frames.push(callback);
                return frames.length;
            },
            cancelFrame: () => {},
            now: () => 0,
            maxTasksPerFrame: 2,
            frameBudgetMs: 6,
        });

        const cancel = queue.enqueue(() => calls.push('task'));
        cancel();
        frames.shift()?.(0);
        frames.shift()?.(16);

        expect(calls).toEqual([]);
    });

    test('runs newly queued visible work before an older background backlog', () => {
        const frames: FrameRequestCallback[] = [];
        const calls: string[] = [];
        const queue = createAfterPaintTaskQueue({
            requestFrame: (callback) => {
                frames.push(callback);
                return frames.length;
            },
            cancelFrame: () => {},
            now: () => 0,
            maxTasksPerFrame: 2,
            frameBudgetMs: 6,
        });

        queue.enqueue(() => calls.push('background-1'));
        queue.enqueue(() => calls.push('background-2'));
        queue.enqueue(() => calls.push('visible'), { priority: 'visible' });

        frames.shift()?.(0);
        frames.shift()?.(16);

        expect(calls).toEqual(['visible', 'background-1']);
    });

    test('cancelled backlog cannot hold a newer visible task behind tombstones', () => {
        const frames: FrameRequestCallback[] = [];
        const calls: string[] = [];
        const queue = createAfterPaintTaskQueue({
            requestFrame: (callback) => {
                frames.push(callback);
                return frames.length;
            },
            cancelFrame: () => {},
            now: () => 0,
            maxTasksPerFrame: 1,
            frameBudgetMs: 6,
        });

        const cancellations = Array.from({ length: 1_000 }, (_, index) => (
            queue.enqueue(() => calls.push(`stale-${index}`))
        ));
        cancellations.slice(0, -1).forEach((cancel) => cancel());
        queue.enqueue(() => calls.push('visible'), { priority: 'visible' });

        frames.shift()?.(0);
        frames.shift()?.(16);

        expect(calls).toEqual(['visible']);
    });
});
