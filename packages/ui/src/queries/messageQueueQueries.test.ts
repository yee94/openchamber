import { describe, expect, test } from 'bun:test';
import { QueryClient } from '@tanstack/react-query';
import { clearMessageQueueScope, messageQueueScopeQueryOptions, messageQueueSnapshotQueryOptions, replaceMessageQueueScope } from './messageQueueQueries';

describe('message queue queries', () => {
  test('pins every cache key to transport identity and scope revision', () => {
    expect(messageQueueSnapshotQueryOptions('runtime-a').queryKey).toEqual(['runtime-a', 'messageQueue', 'snapshot']);
    expect(messageQueueScopeQueryOptions('scope-a', 7, 'runtime-a').queryKey).toEqual(['runtime-a', 'messageQueue', 'scope', 'scope-a', 7]);
  });

  test('writes a precise first scope page', () => {
    const client = new QueryClient();
    const scope = { scopeID: 'scope-a', revision: 7, directory: '/repo', sessionID: 'session-a', worktreeState: 'active', itemCount: 0, items: [] };
    replaceMessageQueueScope(client, scope, 'runtime-a');
    expect(client.getQueryData(['runtime-a', 'messageQueue', 'scope', 'scope-a', 7])).toEqual({ pages: [scope], pageParams: [0] });
  });

  test('clears every revision for one transport-scoped catalog removal', () => {
    const client = new QueryClient();
    for (const revision of [1, 2]) replaceMessageQueueScope(client, { scopeID: 'scope-a', revision, directory: '/repo', sessionID: 'session-a', worktreeState: 'active', itemCount: 0, items: [] }, 'runtime-a');
    replaceMessageQueueScope(client, { scopeID: 'scope-b', revision: 1, directory: '/repo', sessionID: 'session-b', worktreeState: 'active', itemCount: 0, items: [] }, 'runtime-a');
    clearMessageQueueScope(client, 'scope-a', 'runtime-a');
    expect(client.getQueryData(['runtime-a', 'messageQueue', 'scope', 'scope-a', 1])).toBe(undefined);
    expect(client.getQueryData(['runtime-a', 'messageQueue', 'scope', 'scope-a', 2])).toBe(undefined);
    expect(client.getQueryData(['runtime-a', 'messageQueue', 'scope', 'scope-b', 1])).toBeDefined();
  });
});
