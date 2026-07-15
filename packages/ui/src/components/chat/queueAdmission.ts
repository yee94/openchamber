type QueueAdmissionConsumption<TDraft> = {
    admit: () => void;
    drafts: readonly TDraft[];
    consumeDraft: (draft: TDraft) => void;
    consumeBody: () => void;
    consumeAttachments: () => void;
};

type ChatInputQueueAdmission<TDraft, TQueueItem> = Omit<QueueAdmissionConsumption<TDraft>, 'admit'> & {
    bindLegacy: () => void;
    addComposer: () => TQueueItem;
};

export const admitQueueMessageAndConsumeResources = <TDraft>({
    admit,
    drafts,
    consumeDraft,
    consumeBody,
    consumeAttachments,
}: QueueAdmissionConsumption<TDraft>): void => {
    admit();
    for (const draft of drafts) {
        consumeDraft(draft);
    }
    consumeBody();
    consumeAttachments();
};

export const admitChatInputQueueMessageAndConsumeResources = <TDraft, TQueueItem>({
    bindLegacy,
    addComposer,
    drafts,
    consumeDraft,
    consumeBody,
    consumeAttachments,
}: ChatInputQueueAdmission<TDraft, TQueueItem>): TQueueItem => {
    bindLegacy();
    let queueItem: TQueueItem;
    admitQueueMessageAndConsumeResources({
        admit: () => {
            queueItem = addComposer();
        },
        drafts,
        consumeDraft,
        consumeBody,
        consumeAttachments,
    });
    return queueItem!;
};
