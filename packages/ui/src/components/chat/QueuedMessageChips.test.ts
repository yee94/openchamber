import { beforeEach, describe, expect, test } from 'bun:test';
import { legacyQueueScope, setMessageQueueMutationFence, useMessageQueueStore, type QueueItem, type QueueScope } from '@/stores/messageQueueStore';
import { canSendQueuedMessage, canSendServerQueuedMessage, mergeQueuedMessageScopes, popQueuedMessageForEdit, queueModeAllowsMutations, reorderServerQueueItems, serverQueueEditInput, serverQueueItemMutationInput } from './queuedMessageChipsState';
import type { MessageQueueItem, MessageQueueScope } from '@/lib/message-queue-server';
import { sessionDraftKey } from '@/sync/input-draft-types';

const scope: Extract<QueueScope, { state: 'bound' }> = {
    state: 'bound',
    transportIdentity: 'runtime-a',
    directory: '/project',
    sessionID: 'session-a',
};
const add = (target: QueueScope, content: string): QueueItem => {
    const result = useMessageQueueStore.getState().addToQueue(target, { content });
    if (!result.ok) throw new Error(result.reason);
    return result.item;
};
const serverItem = (queueItemID: string, status = 'queued', rowVersion = 1): MessageQueueItem => ({ queueItemID, operationID: `operation-${queueItemID}`, messageID: `msg_${queueItemID}`, content: queueItemID, status, attemptCount: 0, position: 0, rowVersion, createdAt: 1 });
const serverScope = (items: MessageQueueItem[]): MessageQueueScope => ({ scopeID: 'scope-a', revision: 7, directory: '/project', sessionID: 'session-a', worktreeState: 'active', items, itemCount: items.length });

describe('QueuedMessageChips production queue boundary', () => {
    beforeEach(() => {
        setMessageQueueMutationFence('open');
        useMessageQueueStore.setState({ queuedMessages: {}, followUpBehavior: 'queue' });
    });

    test('merges a visible legacy row before bound rows and edits from its owner scope', () => {
        const actions = useMessageQueueStore.getState();
        const legacyScope = legacyQueueScope(scope.sessionID);
        const legacy = add(legacyScope, 'legacy');
        const bound = add(scope, 'bound');
        const visible = mergeQueuedMessageScopes(
            actions.getQueueForScope(legacyScope),
            actions.getQueueForScope(scope),
        );

        expect(visible).toEqual([legacy, bound]);
        expect(popQueuedMessageForEdit(visible[0]!, actions.popToInput)).toBe(legacy);
        expect(actions.getQueueForScope(legacyScope)).toEqual([]);
        expect(actions.getQueueForScope(scope)).toEqual([bound]);
    });
    test('enables Send for each recoverable row and disables all rows for a visible dispatch lock', () => {
        const item = add(scope, 'queued');
        expect(canSendQueuedMessage(item, false)).toBe(true);
        expect(canSendQueuedMessage({ ...item, status: 'retrying' }, false)).toBe(true);
        expect(canSendQueuedMessage({ ...item, status: 'failed' }, false)).toBe(true);
        expect(canSendQueuedMessage({ ...item, status: 'unresolved' }, false)).toBe(true);
        expect(canSendQueuedMessage(item, true)).toBe(false);
    });

    test('keeps server order and status locks aligned with the legacy chip behavior', () => {
        const items = [serverItem('first'), serverItem('sending', 'sending'), serverItem('failed', 'failed'), serverItem('unresolved', 'unresolved')];
        expect(items.map((item) => item.queueItemID)).toEqual(['first', 'sending', 'failed', 'unresolved']);
        expect(canSendServerQueuedMessage(items[0]!, false)).toBe(true);
        expect(canSendServerQueuedMessage(items[1]!, false)).toBe(false);
        expect(canSendServerQueuedMessage(items[2]!, false)).toBe(true);
        expect(canSendServerQueuedMessage(items[3]!, false)).toBe(true);
        expect(canSendServerQueuedMessage(items[0]!, true)).toBe(false);
    });

    test('builds remove and manual-send CAS input from scope revision and row version', () => {
        const item = serverItem('queue-a', 'failed', 11);
        const input = serverQueueItemMutationInput(serverScope([item]), item, '00000000-0000-4000-8000-000000000001');
        expect(input).toEqual({ requestID: '00000000-0000-4000-8000-000000000001', scopeID: 'scope-a', revision: 7, item });
        expect(input.item.rowVersion).toBe(11);
    });

    test('builds a revision-pinned server reorder without changing source items', () => {
        const scope = serverScope([serverItem('first'), serverItem('second'), serverItem('third')]);
        expect(reorderServerQueueItems(scope, 'first', 'third', '00000000-0000-4000-8000-000000000002')).toEqual({
            requestID: '00000000-0000-4000-8000-000000000002',
            scopeID: 'scope-a',
            revision: 7,
            queueItemIDs: ['second', 'third', 'first'],
        });
        expect(scope.items.map((item) => item.queueItemID)).toEqual(['first', 'second', 'third']);
    });

    test('passes the current draft key and expected revision to server edit', () => {
        const item = serverItem('queue-a');
        const key = sessionDraftKey({ transportIdentity: 'runtime-a' }, 'session-a');
        expect(serverQueueEditInput(serverScope([item]), item, key, 9)).toEqual({ scopeID: 'scope-a', scopeRevision: 7, item, targetKey: key, expectedRevision: 9 });
    });

    test('freezes every queue control while legacy and server ownership keep controls available', () => {
        expect(queueModeAllowsMutations('frozen')).toBe(false);
        expect(queueModeAllowsMutations('legacy')).toBe(true);
        expect(queueModeAllowsMutations('server')).toBe(true);
    });
});
