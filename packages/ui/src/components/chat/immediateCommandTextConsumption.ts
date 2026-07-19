type ImmediateCommandTextConsumption = {
    currentSessionId: string | null;
    messageRef: { current: string };
    replacePlainDocument: (message: string) => void;
};

/** Consumes only the command body before an immediate local action can switch sessions. */
export const consumeImmediateCommandText = ({
    currentSessionId,
    messageRef,
    replacePlainDocument,
}: ImmediateCommandTextConsumption): string | null => {
    const sourceSessionId = currentSessionId;
    messageRef.current = '';
    replacePlainDocument('');
    return sourceSessionId;
};
