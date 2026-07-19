type ChatPromptAvailability = {
    showReadOnlyBanner: boolean;
    blockSubmission: boolean;
};

export const resolveChatPromptAvailability = (input: {
    readOnly: boolean;
    sessionIdentityPending: boolean;
    isSubagentSession: boolean;
    allowPromptingSubagentSessions: boolean;
}): ChatPromptAvailability => {
    const subagentReadOnly = input.isSubagentSession && !input.allowPromptingSubagentSessions;
    return {
        showReadOnlyBanner: input.readOnly || subagentReadOnly,
        blockSubmission: input.sessionIdentityPending,
    };
};
