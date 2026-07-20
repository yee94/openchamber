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
});
