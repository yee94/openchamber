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
});
