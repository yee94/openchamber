import { describe, expect, test } from 'bun:test';
import {
    buildHighlightParts,
    resolveAtomicReferenceSelection,
    resolveSkillMentionDeletion,
    type HighlightRange,
} from './composerHighlight';

describe('buildHighlightParts', () => {
    test('preserves skill names on skill tag parts', () => {
        const ranges: HighlightRange[] = [{
            start: 6,
            end: 16,
            style: 'mentionCommand',
            skillName: 'review-pr',
        }];

        expect(buildHighlightParts('Start /review-pr now', ranges)).toEqual([
            { text: 'Start ', className: 'text-foreground', attachmentName: undefined, skillName: undefined },
            { text: '/review-pr', className: 'text-[var(--primary)]', attachmentName: undefined, skillName: 'review-pr' },
            { text: ' now', className: 'text-foreground', attachmentName: undefined, skillName: undefined },
        ]);
    });

    test('keeps ordinary text in separate plain-text segments around highlights', () => {
        const ranges: HighlightRange[] = [{ start: 6, end: 10, style: 'mentionCommand' }];

        expect(buildHighlightParts('hello /run world', ranges)).toEqual([
            { text: 'hello ', className: 'text-foreground', attachmentName: undefined, skillName: undefined },
            { text: '/run', className: 'text-[var(--primary)]', attachmentName: undefined, skillName: undefined },
            { text: ' world', className: 'text-foreground', attachmentName: undefined, skillName: undefined },
        ]);
    });

    test('keeps adjacent skill tokens with different names separate', () => {
        const ranges: HighlightRange[] = [
            { start: 0, end: 6, style: 'mentionCommand', skillName: 'alpha' },
            { start: 6, end: 11, style: 'mentionCommand', skillName: 'beta' },
        ];

        expect(buildHighlightParts('/alpha/beta', ranges)).toEqual([
            { text: '/alpha', className: 'text-[var(--primary)]', attachmentName: undefined, skillName: 'alpha' },
            { text: '/beta', className: 'text-[var(--primary)]', attachmentName: undefined, skillName: 'beta' },
        ]);
    });
});

describe('resolveSkillMentionDeletion', () => {
    test('deletes a complete skill mention from inside the token', () => {
        expect(resolveSkillMentionDeletion(
            'before /auto-research after',
            ['auto-research'],
            { key: 'Backspace', selectionStart: 15, selectionEnd: 15 },
        )).toEqual({
            text: 'before after',
            caret: 7,
            removedSkillNames: ['auto-research'],
        });
    });

    test('expands a partial selection to the complete skill mention', () => {
        const text = 'before /auto-research after';
        expect(resolveSkillMentionDeletion(
            text,
            ['auto-research'],
            {
                key: 'Delete',
                selectionStart: text.indexOf('auto') + 1,
                selectionEnd: text.indexOf('research') + 3,
            },
        )).toEqual({
            text: 'before after',
            caret: 7,
            removedSkillNames: ['auto-research'],
        });
    });

    test('leaves ordinary text deletion to the textarea', () => {
        expect(resolveSkillMentionDeletion(
            'before /auto-research after',
            ['auto-research'],
            { key: 'Backspace', selectionStart: 3, selectionEnd: 3 },
        )).toBeNull();
    });
});

describe('resolveAtomicReferenceSelection', () => {
    const ranges = [
        { start: 7, end: 21 },
        { start: 23, end: 36 },
    ];

    test('selects the complete reference when the caret enters it', () => {
        expect(resolveAtomicReferenceSelection(12, 12, ranges)).toEqual({ start: 7, end: 21 });
    });

    test('expands a partial selection across every touched reference', () => {
        expect(resolveAtomicReferenceSelection(10, 27, ranges)).toEqual({ start: 7, end: 36 });
    });

    test('keeps ordinary text selection unchanged', () => {
        expect(resolveAtomicReferenceSelection(1, 4, ranges)).toBeNull();
    });
});
