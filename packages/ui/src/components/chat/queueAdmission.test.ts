import { describe, expect, test } from 'bun:test';
import { admitChatInputQueueMessageAndConsumeResources, admitQueueMessageAndConsumeResources } from './queueAdmission';
import { legacyQueueScope, useMessageQueueStore, type QueueItem, type QueueScope } from '@/stores/messageQueueStore';

const scope: Extract<QueueScope, { state: 'bound' }> = {
    state: 'bound',
    transportIdentity: 'runtime-a',
    directory: '/project',
    sessionID: 'session-a',
};

describe('admitQueueMessageAndConsumeResources', () => {
    test('admits before consuming drafts, body, and attachments', () => {
        const calls: string[] = [];

        admitQueueMessageAndConsumeResources({
            admit: () => calls.push('admit'),
            drafts: ['first', 'second'],
            consumeDraft: (draft) => calls.push(`draft:${draft}`),
            consumeBody: () => calls.push('body'),
            consumeAttachments: () => calls.push('attachments'),
        });

        expect(calls).toEqual(['admit', 'draft:first', 'draft:second', 'body', 'attachments']);
    });

    test('preserves every composer resource when admission throws', () => {
        const calls: string[] = [];
        const failure = new Error('admission failed');

        let thrown: unknown;
        try {
            admitQueueMessageAndConsumeResources({
                admit: () => {
                    calls.push('admit');
                    throw failure;
                },
                drafts: ['first'],
                consumeDraft: () => calls.push('draft'),
                consumeBody: () => calls.push('body'),
                consumeAttachments: () => calls.push('attachments'),
            });
        } catch (error) {
            thrown = error;
        }

        expect(thrown).toBe(failure);
        expect(calls).toEqual(['admit']);
    });

    test('ChatInput admits legacy rows before existing bound and composer rows with stable identities', () => {
        useMessageQueueStore.setState({ queuedMessages: {}, followUpBehavior: 'queue' });
        const actions = useMessageQueueStore.getState();
        const legacyScope = legacyQueueScope(scope.sessionID);
        const legacy = actions.addToQueue(legacyScope, { content: 'legacy' });
        const bound = actions.addToQueue(scope, { content: 'bound' });
        const composer = admitChatInputQueueMessageAndConsumeResources({
            bindLegacy: () => actions.bindLegacyQueue(legacyScope, scope),
            addComposer: () => actions.addToQueue(scope, { content: 'composer' }),
            drafts: [],
            consumeDraft: () => {},
            consumeBody: () => {},
            consumeAttachments: () => {},
        });
        const queue = actions.getQueueForScope(scope) as QueueItem[];

        expect(queue.map((item) => item.queueItemID)).toEqual([legacy.queueItemID, bound.queueItemID, composer.queueItemID]);
        expect(queue.map((item) => item.operationID)).toEqual([legacy.operationID, bound.operationID, composer.operationID]);
        expect(queue.map((item) => item.messageID)).toEqual([legacy.messageID, bound.messageID, composer.messageID]);
    });
});
