import { describe, expect, test } from 'bun:test';

import { resolveChatPromptAvailability } from './chatPromptAvailability';

describe('resolveChatPromptAvailability', () => {
    test('keeps the primary composer mounted while session identity is temporarily pending', () => {
        expect(resolveChatPromptAvailability({
            readOnly: false,
            sessionIdentityPending: true,
            isSubagentSession: false,
            allowPromptingSubagentSessions: false,
        })).toEqual({
            showReadOnlyBanner: false,
            blockSubmission: true,
        });
    });

    test('shows the read-only banner for subagent and explicitly read-only surfaces', () => {
        expect(resolveChatPromptAvailability({
            readOnly: false,
            sessionIdentityPending: false,
            isSubagentSession: true,
            allowPromptingSubagentSessions: false,
        }).showReadOnlyBanner).toBe(true);
        expect(resolveChatPromptAvailability({
            readOnly: true,
            sessionIdentityPending: false,
            isSubagentSession: false,
            allowPromptingSubagentSessions: true,
        }).showReadOnlyBanner).toBe(true);
    });

    test('keeps prompting available for known primary sessions and enabled subagent sessions', () => {
        expect(resolveChatPromptAvailability({
            readOnly: false,
            sessionIdentityPending: false,
            isSubagentSession: false,
            allowPromptingSubagentSessions: false,
        })).toEqual({
            showReadOnlyBanner: false,
            blockSubmission: false,
        });
        expect(resolveChatPromptAvailability({
            readOnly: false,
            sessionIdentityPending: false,
            isSubagentSession: true,
            allowPromptingSubagentSessions: true,
        })).toEqual({
            showReadOnlyBanner: false,
            blockSubmission: false,
        });
    });
});
