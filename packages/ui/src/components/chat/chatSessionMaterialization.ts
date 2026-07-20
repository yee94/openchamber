export const shouldEnsureChatSessionRenderable = (input: {
    sessionId: string | null;
    hasRenderableSessionSnapshot: boolean;
    hasCurrentSessionEntity: boolean;
}) => Boolean(input.sessionId)
    && !(input.hasRenderableSessionSnapshot && input.hasCurrentSessionEntity);
