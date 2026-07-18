import { describe, expect, test } from 'bun:test';
import {
    createPastedTextReference,
    expandPastedTextReferences,
    findPastedTextReferenceRanges,
    insertPastedTextReference,
    mergePastedTextReferences,
    parsePastedTextReferences,
    parsePastedTextDraft,
    prunePastedTextReferences,
    resolvePastedTextReferenceDeletion,
    serializePastedTextReferences,
    serializePastedTextDraft,
    shouldCompactPastedText,
    type PastedTextReference,
} from './pastedTextReferences';

const reference = (id: string, token: string, text: string, index = 1): PastedTextReference => ({
    id,
    token,
    text,
    characterCount: Array.from(text).length,
    index,
});

describe('pastedTextReferences', () => {
    test('compacts at 500 Unicode code points including emoji', () => {
        expect(shouldCompactPastedText('a'.repeat(499))).toBe(false);
        expect(shouldCompactPastedText('a'.repeat(500))).toBe(true);
        expect(shouldCompactPastedText('😀'.repeat(499))).toBe(false);
        expect(shouldCompactPastedText('😀'.repeat(500))).toBe(true);
    });

    test('creates stable unique references around message and existing tokens', () => {
        const first = createPastedTextReference('long text', '[Paste 1]', [], ({ index }) => `Paste ${index}`);
        const second = createPastedTextReference('😀'.repeat(500), first.token, [first], ({ index, count }) => `Paste ${index}/${count}`);

        expect(first.id.startsWith('pasted-text-2-')).toBe(true);
        expect(first.token).toBe('[Paste 2]');
        expect(first.index).toBe(2);
        expect(second.token).toBe('[Paste 1/500]');
        expect(second.index).toBe(1);
        expect(second.characterCount).toBe(500);
        expect(createPastedTextReference('long text', '[Paste 1]', [], ({ index }) => `Paste ${index}`)).toEqual(first);
    });

    test('starts new tokens from the supplied monotonic index', () => {
        const item = createPastedTextReference('long text', '', [], ({ index }) => `Paste ${index}`, 8);
        expect(item.index).toBe(8);
        expect(item.token).toBe('[Paste 8]');
    });

    test('replaces a middle selection and separates adjacent text', () => {
        expect(insertPastedTextReference('hello removed world', 6, 13, '[Paste 1]')).toEqual({
            text: 'hello [Paste 1] world',
            caret: 15,
        });
    });

    test('keeps a large fenced-code paste out of the composer text path', () => {
        const pasted = `\`\`\`ts\n${'const value = 1;\n'.repeat(600)}\`\`\``;
        const item = createPastedTextReference(pasted, '', [], ({ index, count }) => `Paste ${index}/${count}`);
        const compacted = insertPastedTextReference('', 0, 0, item.token).text;

        expect(compacted.length).toBeLessThan(40);
        expect(compacted.includes('```')).toBe(false);
        expect(expandPastedTextReferences(compacted, [item])).toBe(pasted);
    });

    test('finds and expands every registered token in message order while retaining similar tokens', () => {
        const one = reference('one', '[Paste 1]', 'first', 1);
        const two = reference('two', '[Paste 2]', 'second', 2);
        const message = '[Paste 2] [Paste 20] [Paste 1] [Paste 2] [unknown]';

        expect(findPastedTextReferenceRanges(message, [one, two]).map((range) => range.reference.id)).toEqual(['two', 'one', 'two']);
        expect(expandPastedTextReferences(message, [one, two])).toBe('second [Paste 20] first second [unknown]');
    });

    test('prunes references whose tokens are absent', () => {
        const one = reference('one', '[Paste 1]', 'first');
        const two = reference('two', '[Paste 2]', 'second', 2);
        expect(prunePastedTextReferences('keep [Paste 2]', [one, two])).toEqual([two]);
    });

    test('merges restored references without token or id collisions', () => {
        const one = reference('one', '[Paste 1]', 'first');
        const duplicateToken = reference('two', '[Paste 1]', 'second', 2);
        const two = reference('two', '[Paste 2]', 'second', 2);
        expect(mergePastedTextReferences([one], [duplicateToken, two])).toEqual([one, two]);
    });

    test('removes whole references for Backspace, Delete, selections, and Alt deletion', () => {
        const item = reference('one', '[Paste 1]', 'first');
        const message = 'a [Paste 1] b';
        expect(resolvePastedTextReferenceDeletion(message, [item], { key: 'Backspace', selectionStart: 3, selectionEnd: 3 })).toEqual({ text: 'a  b', caret: 2, removedIds: ['one'] });
        expect(resolvePastedTextReferenceDeletion(message, [item], { key: 'Delete', selectionStart: 2, selectionEnd: 2 })).toEqual({ text: 'a  b', caret: 2, removedIds: ['one'] });
        expect(resolvePastedTextReferenceDeletion(message, [item], { key: 'Delete', selectionStart: 4, selectionEnd: 6 })).toEqual({ text: 'a  b', caret: 2, removedIds: ['one'] });
        expect(resolvePastedTextReferenceDeletion(message, [item], { key: 'Backspace', selectionStart: 12, selectionEnd: 12, altKey: true })).toEqual({ text: 'a b', caret: 2, removedIds: ['one'] });
    });

    test('keeps a reference when deletion leaves another token occurrence', () => {
        const item = reference('one', '[Paste 1]', 'first');
        const deletion = resolvePastedTextReferenceDeletion('[Paste 1] and [Paste 1]', [item], {
            key: 'Delete', selectionStart: 0, selectionEnd: 1,
        });
        expect(deletion?.text).toBe(' and [Paste 1]');
        expect(prunePastedTextReferences(deletion?.text ?? '', [item])).toEqual([item]);
    });

    test('round-trips serialization and rejects malformed, mismatched, and duplicate entries', () => {
        const items = [reference('one', '[Paste 1]', '😀 text')];
        expect(parsePastedTextReferences(serializePastedTextReferences(items))).toEqual(items);
        expect(parsePastedTextReferences('{')).toEqual([]);
        expect(parsePastedTextReferences(JSON.stringify([{ ...items[0], characterCount: 99 }]))).toEqual([]);
        expect(parsePastedTextReferences(JSON.stringify([items[0], { ...items[0], token: '[Paste 2]' }]))).toEqual([]);
        expect(parsePastedTextReferences(JSON.stringify([items[0], { ...items[0], id: 'two' }]))).toEqual([]);
    });

    test('round-trips versioned drafts and preserves legacy raw text', () => {
        const draft = { text: 'keep [Paste 1]', references: [reference('one', '[Paste 1]', 'first')] };
        expect(parsePastedTextDraft(serializePastedTextDraft(draft))).toEqual(draft);
        expect(parsePastedTextDraft('legacy draft')).toEqual({ text: 'legacy draft', references: [] });
        expect(parsePastedTextDraft('{"foo":1}')).toEqual({ text: '{"foo":1}', references: [] });
        expect(parsePastedTextDraft('{"version":1,"text":"user JSON"}')).toEqual({
            text: '{"version":1,"text":"user JSON"}',
            references: [],
        });
        expect(parsePastedTextDraft('[1,2]')).toEqual({ text: '[1,2]', references: [] });
        expect(parsePastedTextDraft('"hello"')).toEqual({ text: '"hello"', references: [] });
        expect(parsePastedTextDraft('{"type":"openchamber-pasted-text-draft","version":1,"text":42,"references":[]}')).toBeNull();
        expect(parsePastedTextDraft('{')).toEqual({ text: '{', references: [] });
    });
});
