import { describe, expect, test } from 'bun:test';
import { admitChatInputQueueMessageAndConsumeResources, admitQueueMessageAndConsumeResources } from './queueAdmission';
import { legacyQueueScope, useMessageQueueStore, type QueueItem, type QueueScope } from '@/stores/messageQueueStore';

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
        const legacy = add(legacyScope, 'legacy');
        const bound = add(scope, 'bound');
        const composer = admitChatInputQueueMessageAndConsumeResources({
            bindLegacy: () => actions.bindLegacyQueue(legacyScope, scope),
            addComposer: () => actions.addToQueue(scope, { content: 'composer' }),
            drafts: [],
            consumeDraft: () => {},
            consumeBody: () => {},
            consumeAttachments: () => {},
        });
        const queue = actions.getQueueForScope(scope) as QueueItem[];

        expect(composer.ok).toBe(true);
        if (!composer.ok) return;
        expect(queue.map((item) => item.queueItemID)).toEqual([legacy.queueItemID, bound.queueItemID, composer.item.queueItemID]);
        expect(queue.map((item) => item.operationID)).toEqual([legacy.operationID, bound.operationID, composer.item.operationID]);
        expect(queue.map((item) => item.messageID)).toEqual([legacy.messageID, bound.messageID, composer.item.messageID]);
    });

    test('preserves resources when composer admission fails', () => {
        const calls: string[] = [];
        const result = admitChatInputQueueMessageAndConsumeResources({
            bindLegacy: () => calls.push('bind'),
            addComposer: () => ({ ok: false as const, reason: 'invalid-composer-document' as const }),
            drafts: ['draft'],
            consumeDraft: () => calls.push('draft'),
            consumeBody: () => calls.push('body'),
            consumeAttachments: () => calls.push('attachments'),
        });
        expect(result).toEqual({ ok: false, reason: 'invalid-composer-document' });
        expect(calls).toEqual([]);
    });
});
