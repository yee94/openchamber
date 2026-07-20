import { describe, expect, test } from 'bun:test';
import { parseOpenchamberEventEnvelope } from './openchamberEvents';

describe('parseOpenchamberEventEnvelope', () => {
  test('parses ready and valid topology envelopes', () => {
    expect(parseOpenchamberEventEnvelope({ type: 'openchamber:event-stream-ready', properties: {} })).toEqual({ type: 'event-stream-ready' });
    expect(parseOpenchamberEventEnvelope({ type: 'openchamber:worktree-topology-changed', properties: { projectDirectory: '/repo', directory: '/repo/feature', operation: 'added', occurredAt: 1 } })).toEqual({ type: 'worktree-topology-changed', projectDirectory: '/repo', directory: '/repo/feature', operation: 'added', occurredAt: 1 });
  });

  test('rejects malformed topology payloads', () => {
    expect(parseOpenchamberEventEnvelope({ type: 'openchamber:worktree-topology-changed', properties: { projectDirectory: '/repo', operation: 'added', occurredAt: 1 } })).toBeNull();
    expect(parseOpenchamberEventEnvelope({ type: 'openchamber:worktree-topology-changed', properties: { projectDirectory: '/repo', directory: '/repo/feature', operation: 'moved', occurredAt: '1' } })).toBeNull();
  });

  test('parses session-index and message-queue tip envelopes', () => {
    expect(parseOpenchamberEventEnvelope({
      type: 'openchamber:session-index-changed',
      properties: { revision: 3, occurredAt: 10, sync: { active: true, enriching: false } },
    })).toEqual({
      type: 'session-index-changed',
      revision: 3,
      occurredAt: 10,
      sync: { active: true, enriching: false },
    });
    expect(parseOpenchamberEventEnvelope({
      type: 'openchamber:message-queue-changed',
      properties: { revision: 7, occurredAt: 20 },
    })).toEqual({ type: 'message-queue-changed', revision: 7, occurredAt: 20 });
  });

  test('rejects malformed session-index and message-queue tip payloads', () => {
    expect(parseOpenchamberEventEnvelope({ type: 'openchamber:session-index-changed', properties: { revision: -1, occurredAt: 1 } })).toBeNull();
    expect(parseOpenchamberEventEnvelope({ type: 'openchamber:session-index-changed', properties: { revision: 1 } })).toBeNull();
    expect(parseOpenchamberEventEnvelope({ type: 'openchamber:message-queue-changed', properties: { revision: '1', occurredAt: 1 } })).toBeNull();
    expect(parseOpenchamberEventEnvelope({ type: 'openchamber:message-queue-changed', properties: { revision: 1, occurredAt: Number.NaN } })).toBeNull();
  });
});
