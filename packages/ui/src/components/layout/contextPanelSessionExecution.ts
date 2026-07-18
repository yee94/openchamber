type ContextPanelSessionExecution = {
    agentName?: string;
    providerId?: string;
    modelId?: string;
};

type SessionMessageRecord = {
    info: unknown;
};

const readNonEmptyString = (value: unknown): string | undefined => {
    if (typeof value !== 'string') return undefined;
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
};

const readMessageInfo = (record: SessionMessageRecord): Record<string, unknown> | undefined => {
    if (!record.info || typeof record.info !== 'object') return undefined;
    return record.info as Record<string, unknown>;
};

const isAssistantMessage = (record: SessionMessageRecord): boolean => (
    readMessageInfo(record)?.role === 'assistant'
);

const fillExecutionFields = (
    execution: ContextPanelSessionExecution,
    record: SessionMessageRecord,
): void => {
    const info = readMessageInfo(record);
    if (!info) return;

    execution.agentName ??= readNonEmptyString(info.agent);
    execution.providerId ??= readNonEmptyString(info.providerID);
    execution.modelId ??= readNonEmptyString(info.modelID);
};

const isComplete = (execution: ContextPanelSessionExecution): boolean => Boolean(
    execution.agentName && execution.providerId && execution.modelId,
);

export const resolveContextPanelSessionExecution = (
    messages: readonly SessionMessageRecord[],
): ContextPanelSessionExecution => {
    const execution: ContextPanelSessionExecution = {};

    for (let index = messages.length - 1; index >= 0; index -= 1) {
        const message = messages[index];
        if (!message || !isAssistantMessage(message)) continue;
        fillExecutionFields(execution, message);
        if (isComplete(execution)) return execution;
    }

    for (let index = messages.length - 1; index >= 0; index -= 1) {
        const message = messages[index];
        if (!message || isAssistantMessage(message)) continue;
        fillExecutionFields(execution, message);
        if (isComplete(execution)) break;
    }

    return execution;
};
