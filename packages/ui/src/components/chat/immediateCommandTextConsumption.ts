type ImmediateCommandTextConsumption = {
    currentSessionId: string | null;
    cancelDraftPersist: () => void;
    messageRef: { current: string };
    setMessage: (message: string) => void;
    persistDraftImmediately: (sessionId: string | null, draft: string) => void;
};

/** Consumes only the command body before an immediate local action can switch sessions. */
export const consumeImmediateCommandText = ({
    currentSessionId,
    cancelDraftPersist,
    messageRef,
    setMessage,
    persistDraftImmediately,
}: ImmediateCommandTextConsumption): string | null => {
    const sourceSessionId = currentSessionId;
    cancelDraftPersist();
    messageRef.current = '';
    setMessage('');
    persistDraftImmediately(sourceSessionId, '');
    return sourceSessionId;
};
