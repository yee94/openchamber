import { beforeEach, describe, expect, test } from 'bun:test';
import { legacyQueueScope, useMessageQueueStore, type QueueScope } from '@/stores/messageQueueStore';
import { canSendQueuedMessage, mergeQueuedMessageScopes, popQueuedMessageForEdit } from './queuedMessageChipsState';

const scope: Extract<QueueScope, { state: 'bound' }> = {
    state: 'bound',
    transportIdentity: 'runtime-a',
    directory: '/project',
    sessionID: 'session-a',
};

describe('QueuedMessageChips production queue boundary', () => {
    beforeEach(() => {
        useMessageQueueStore.setState({ queuedMessages: {}, followUpBehavior: 'queue' });
    });

    test('merges a visible legacy row before bound rows and edits from its owner scope', () => {
        const actions = useMessageQueueStore.getState();
        const legacyScope = legacyQueueScope(scope.sessionID);
        const legacy = actions.addToQueue(legacyScope, { content: 'legacy' });
        const bound = actions.addToQueue(scope, { content: 'bound' });
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
        const item = useMessageQueueStore.getState().addToQueue(scope, { content: 'queued' });
        expect(canSendQueuedMessage(item, false)).toBe(true);
        expect(canSendQueuedMessage({ ...item, status: 'retrying' }, false)).toBe(true);
        expect(canSendQueuedMessage({ ...item, status: 'failed' }, false)).toBe(true);
        expect(canSendQueuedMessage({ ...item, status: 'unresolved' }, false)).toBe(true);
        expect(canSendQueuedMessage(item, true)).toBe(false);
    });
});
