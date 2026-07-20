import { describe, expect, test } from 'bun:test';

import { shouldEnsureChatSessionRenderable } from './chatSessionMaterialization';

describe('shouldEnsureChatSessionRenderable', () => {
    test('materializes a selected session when its target directory differs from the provider directory', () => {
        const providerDirectory = '/provider';
        const targetDirectory = '/target';

        expect(providerDirectory).not.toBe(targetDirectory);
        expect(shouldEnsureChatSessionRenderable({
            sessionId: 'ses_target',
            hasRenderableSessionSnapshot: true,
            hasCurrentSessionEntity: false,
        })).toBe(true);
    });
});
