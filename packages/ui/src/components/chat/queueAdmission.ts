type QueueAdmissionConsumption<TDraft> = {
    admit: () => void;
    drafts: readonly TDraft[];
    consumeDraft: (draft: TDraft) => void;
    consumeBody: () => void;
    consumeAttachments: () => void;
};

type ChatInputQueueAdmission<TDraft, TQueueItem> = Omit<QueueAdmissionConsumption<TDraft>, 'admit'> & {
    bindLegacy: () => void;
    addComposer: () => { ok: true; item: TQueueItem } | { ok: false; reason: 'invalid-composer-document' | 'invalid-composer-mentions' };
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
}: ChatInputQueueAdmission<TDraft, TQueueItem>): { ok: true; item: TQueueItem } | { ok: false; reason: 'invalid-composer-document' | 'invalid-composer-mentions' } => {
    const result = addComposer();
    if (!result.ok) return result;
    bindLegacy();
    admitQueueMessageAndConsumeResources({
        admit: () => {},
        drafts,
        consumeDraft,
        consumeBody,
        consumeAttachments,
    });
    return result;
};
