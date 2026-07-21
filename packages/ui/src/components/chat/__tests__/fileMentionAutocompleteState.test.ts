import { describe, expect, test } from 'bun:test';

import {
    collectSessionMentionIds,
    findSessionMentionRanges,
    getFileMentionAutocompleteQuery,
    getSessionMentionToken,
    getVisibleSessionMentionCandidates,
    replaceSessionMentionTokens,
    resolveSessionMentionDeletion,
} from '../fileMentionAutocompleteState';
import { buildSessionMentionInstruction, type SessionMentionContext } from '@/composer/delivery';
import type { Session } from '@opencode-ai/sdk/v2';

describe('getFileMentionAutocompleteQuery', () => {
    test('opens file mention autocomplete for manually typed boundary @ text', () => {
        expect(getFileMentionAutocompleteQuery({
            value: '@config',
            cursorPosition: '@config'.length,
            inputSource: 'manual',
        })).toBe('config');

        expect(getFileMentionAutocompleteQuery({
            value: 'check @main.ts',
            cursorPosition: 'check @main.ts'.length,
            inputSource: 'manual',
        })).toBe('main.ts');

        expect(getFileMentionAutocompleteQuery({
            value: 'check @docs',
            cursorPosition: 'check @docs'.length,
        })).toBe('docs');
    });

    test('does not open file mention autocomplete when pasted text contains @', () => {
        const pastedValues = [
            '@config',
            '@/path/to/file',
            'Use @main.ts',
        ];

        for (const value of pastedValues) {
            expect(getFileMentionAutocompleteQuery({
                value,
                cursorPosition: value.length,
                inputSource: 'paste',
                insertedText: value,
            })).toBeNull();
        }
    });

    test('does not open file mention autocomplete for pasted package and email text', () => {
        const pastedValues = [
            'user@email.com',
            'npx @scope/pkg@latest',
        ];

        for (const value of pastedValues) {
            expect(getFileMentionAutocompleteQuery({
                value,
                cursorPosition: value.length,
                inputSource: 'paste',
                insertedText: value,
            })).toBeNull();
        }
    });

    test('keeps autocomplete open when pasting a query fragment after a manually typed @', () => {
        expect(getFileMentionAutocompleteQuery({
            value: '@config',
            cursorPosition: '@config'.length,
            inputSource: 'paste',
            insertedText: 'config',
        })).toBe('config');
    });

    test('uses current value when paste source lacks inserted text context', () => {
        expect(getFileMentionAutocompleteQuery({
            value: '@config',
            cursorPosition: '@config'.length,
            inputSource: 'paste',
        })).toBe('config');
    });
});

describe('session mentions', () => {
    test('searches every loaded global session while the empty menu stays bounded', () => {
        const sessions = [
            { id: 'ses_1', title: 'Alpha', time: { created: 1, updated: 1 } },
            { id: 'ses_2', title: 'Beta', time: { created: 2, updated: 2 } },
            { id: 'ses_3', title: 'Gamma', time: { created: 3, updated: 3 } },
            { id: 'ses_4', title: 'Delta', time: { created: 4, updated: 4 } },
        ] as Session[];

        expect(getVisibleSessionMentionCandidates({
            sessions,
            currentSessionId: null,
            searchQuery: '',
        }).map((session) => session.id)).toEqual(['ses_4', 'ses_3', 'ses_2']);

        expect(getVisibleSessionMentionCandidates({
            sessions,
            currentSessionId: null,
            searchQuery: 'a',
        }).map((session) => session.id)).toEqual(['ses_4', 'ses_3', 'ses_2', 'ses_1']);
    });

    test('creates stable tokens and collects unique session IDs in message order', () => {
        expect(getSessionMentionToken('ses_123')).toBe('session:ses_123');
        expect(collectSessionMentionIds('Compare @session:ses_123 with @session:ses_456 and @session:ses_123.')).toEqual([
            'ses_123',
            'ses_456',
        ]);
        expect(collectSessionMentionIds('email@session:ses_123')).toEqual([]);
        expect(findSessionMentionRanges('Use (@session:ses_123)')).toEqual([
            { start: 5, end: 21, id: 'ses_123' },
        ]);
    });

    test('renders readable labels and deletes a session tag atomically', () => {
        const text = 'Compare @session:ses_123 with this';
        expect(replaceSessionMentionTokens(text, new Map([['ses_123', 'Previous implementation']]))).toBe(
            'Compare @Previous implementation with this',
        );
        expect(resolveSessionMentionDeletion(text, 'Backspace', 20, 20)).toEqual({
            text: 'Compare with this',
            caret: 8,
        });
        expect(resolveSessionMentionDeletion(text, 'Delete', 8, 8)).toEqual({
            text: 'Compare with this',
            caret: 8,
        });
    });

    test('builds bounded loaded-session context', () => {
        const instruction = buildSessionMentionInstruction([
            {
                id: 'ses_123',
                title: 'Previous implementation',
                messages: [{ role: 'user', text: 'Implement grouped mentions' }],
            },
        ]);

        expect(instruction).toContain('ses_123');
        expect(instruction).toContain('Implement grouped mentions');
        expect(buildSessionMentionInstruction([], 100)).toBeNull();
        const boundedInstruction = buildSessionMentionInstruction([
            { id: 'ses_123', title: 'Long', messages: [{ role: 'user', text: 'x'.repeat(500) }] },
            { id: 'ses_456', title: 'Second', messages: [{ role: 'assistant', text: 'y'.repeat(500) }] },
        ], 500);
        expect((boundedInstruction?.length ?? 0) <= 500).toBe(true);
        const payload = boundedInstruction?.slice((boundedInstruction.indexOf('\n') ?? -1) + 1) ?? '';
        const parsed = JSON.parse(payload) as SessionMentionContext[];
        expect(parsed.map((context) => context.id)).toEqual(['ses_123', 'ses_456']);
        expect(parsed[0].messages[0]?.text).toContain('[Message truncated]');
    });
});
