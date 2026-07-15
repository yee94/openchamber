import type { QueueScope, QueuedMessage } from '@/stores/messageQueueStore';

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
