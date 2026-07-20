import { expect, test } from 'bun:test';
import { isMessageQueueRoute } from './messageQueueRoute';

test('identifies only message queue server routes', () => {
  expect(isMessageQueueRoute('/api/openchamber/message-queue')).toBe(true);
  expect(isMessageQueueRoute('/api/openchamber/message-queue/worktrees/order')).toBe(true);
  expect(isMessageQueueRoute('/api/openchamber/tunnel/status')).toBe(false);
});
