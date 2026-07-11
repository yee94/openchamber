import { describe, expect, test } from 'bun:test';

import type { MarkdownWorkerJobRequest } from './markdown-worker-protocol';
import { createMarkdownWorkerTaskQueue } from './markdown-worker-task-queue';

const request = (
  id: number,
  priority: MarkdownWorkerJobRequest['priority'],
): MarkdownWorkerJobRequest => ({
  type: 'highlight',
  id,
  code: String(id),
  lang: 'text',
  priority,
});

const deferred = () => {
  let resolve = () => {};
  const promise = new Promise<void>((next) => {
    resolve = next;
  });
  return { promise, resolve };
};

describe('markdown worker task queue', () => {
  test('visible work overtakes queued background work and cancelled work never starts', async () => {
    const firstTask = deferred();
    const started: number[] = [];
    const queue = createMarkdownWorkerTaskQueue(async (item) => {
      started.push(item.id);
      if (item.id === 1) {
        await firstTask.promise;
      }
    });

    queue.enqueue(request(1, 'background'));
    queue.enqueue(request(2, 'background'));
    queue.enqueue(request(3, 'background'));
    queue.cancel(2);
    queue.enqueue(request(4, 'visible'));

    expect(started).toEqual([1]);
    firstTask.resolve();
    await queue.whenIdle();

    expect(started).toEqual([1, 4, 3]);
  });

  test('a running task may finish but observes cancellation before publishing', async () => {
    const runningTask = deferred();
    let cancelledBeforePublish = false;
    const queue = createMarkdownWorkerTaskQueue(async (item, isCancelled) => {
      if (item.id !== 1) return;
      await runningTask.promise;
      cancelledBeforePublish = isCancelled();
    });

    queue.enqueue(request(1, 'background'));
    queue.cancel(1);
    runningTask.resolve();
    await queue.whenIdle();

    expect(cancelledBeforePublish).toBe(true);
  });

  test('preserves FIFO order within the same priority', async () => {
    const started: number[] = [];
    const queue = createMarkdownWorkerTaskQueue(async (item) => {
      started.push(item.id);
    });

    queue.enqueue(request(1, 'visible'));
    queue.enqueue(request(2, 'visible'));
    queue.enqueue(request(3, 'visible'));
    await queue.whenIdle();

    expect(started).toEqual([1, 2, 3]);
  });

  test('yields between jobs so newly-arrived visible work can overtake background work', async () => {
    const betweenJobs = deferred();
    const started: number[] = [];
    let yieldCount = 0;
    const queue = createMarkdownWorkerTaskQueue(
      async (item) => {
        started.push(item.id);
      },
      async () => {
        yieldCount += 1;
        if (yieldCount === 1) {
          await betweenJobs.promise;
        }
      },
    );

    queue.enqueue(request(1, 'background'));
    queue.enqueue(request(2, 'background'));
    await Promise.resolve();
    queue.enqueue(request(3, 'visible'));

    expect(started).toEqual([1]);
    betweenJobs.resolve();
    await queue.whenIdle();

    expect(started).toEqual([1, 3, 2]);
  });
});
