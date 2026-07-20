import { describe, expect, test } from 'bun:test';

import { resolveChatPromptAvailability, resolveComposerActionAvailability } from './chatPromptAvailability';

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

    test('shows the read-only banner only for confirmed subagent sessions', () => {
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
        }).showReadOnlyBanner).toBe(false);
        expect(resolveChatPromptAvailability({
            readOnly: true,
            sessionIdentityPending: true,
            isSubagentSession: false,
            allowPromptingSubagentSessions: false,
        }).showReadOnlyBanner).toBe(false);
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

describe('resolveComposerActionAvailability', () => {
    test('disables Send and Queue visibly while submission is blocked', () => {
        expect(resolveComposerActionAvailability({
            canSend: true,
            hasSessionTarget: true,
            draftSubmitting: false,
            submissionBlocked: true,
            queueFrozen: false,
        })).toEqual({
            sendDisabled: true,
            queueDisabled: true,
            disabledClass: 'opacity-30 pointer-events-none',
        });
    });

    test('disables Queue visibly while queue admission is frozen', () => {
        expect(resolveComposerActionAvailability({
            canSend: true,
            hasSessionTarget: true,
            draftSubmitting: false,
            submissionBlocked: false,
            queueFrozen: true,
        })).toEqual({
            sendDisabled: false,
            queueDisabled: true,
            disabledClass: 'opacity-30 pointer-events-none',
        });
    });
});
