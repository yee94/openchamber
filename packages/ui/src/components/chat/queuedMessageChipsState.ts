import type { QueueScope, QueuedMessage } from '@/stores/messageQueueStore';
import type { MessageQueueItem, MessageQueueScope } from '@/lib/message-queue-server';
import type { DraftKey } from '@/sync/input-draft-types';
import type { DraftCommitInput } from '@/sync/input-store';

export const queueModeAllowsMutations = (mode: 'legacy' | 'server' | 'frozen'): boolean => mode !== 'frozen';

export const mergeQueuedMessageScopes = (
    legacyQueuedMessages: QueuedMessage[],
    boundQueuedMessages: QueuedMessage[],
): QueuedMessage[] => {
    if (legacyQueuedMessages.length === 0) return boundQueuedMessages;
    if (boundQueuedMessages.length === 0) return legacyQueuedMessages;
    return [...legacyQueuedMessages, ...boundQueuedMessages];
};

export const popQueuedMessageForEdit = (
    message: QueuedMessage,
    popToInput: (scope: QueueScope, queueItemID: string, operationID: string | undefined) => QueuedMessage | null,
): QueuedMessage | null => {
    if (!message.owner) return null;
    return popToInput(message.owner, message.queueItemID ?? message.id, message.operationID);
};

export const canSendQueuedMessage = (message: QueuedMessage, hasDispatchLock: boolean): boolean => {
    const status = message.status ?? 'queued';
    return !hasDispatchLock && (status === 'queued' || status === 'retrying' || status === 'failed' || status === 'unresolved');
};

export const canSendServerQueuedMessage = (message: MessageQueueItem, hasDispatchLock: boolean): boolean => (
    !hasDispatchLock && ['queued', 'retrying', 'failed', 'unresolved'].includes(message.status)
);

export const serverQueueItemMutationInput = (scope: MessageQueueScope, item: MessageQueueItem, requestID: string) => ({
    requestID,
    scopeID: scope.scopeID,
    revision: scope.revision,
    item,
});

export const serverQueueEditInput = (scope: MessageQueueScope, item: MessageQueueItem, targetKey: DraftKey, expectedRevision: DraftCommitInput['expectedRevision']) => ({
    scopeID: scope.scopeID,
    scopeRevision: scope.revision,
    item,
    targetKey,
    expectedRevision,
});

export const reorderServerQueueItems = (
    scope: MessageQueueScope,
    activeID: string,
    overID: string,
    requestID: string,
): { requestID: string; scopeID: string; revision: number; queueItemIDs: string[] } | null => {
    const from = scope.items.findIndex((item) => item.queueItemID === activeID);
    const to = scope.items.findIndex((item) => item.queueItemID === overID);
    if (from < 0 || to < 0 || from === to) return null;
    const queueItemIDs = scope.items.map((item) => item.queueItemID);
    const [moved] = queueItemIDs.splice(from, 1);
    if (!moved) return null;
    queueItemIDs.splice(to, 0, moved);
    return { requestID, scopeID: scope.scopeID, revision: scope.revision, queueItemIDs };
};
