import { describe, expect, test } from 'bun:test';
import { COMPOSER_REFERENCE_LIMITS } from '@/composer/document';
import { canCompactPastedText, createPastedTextReference, getNextPastedTextReferenceIndex, shouldCompactPastedText } from './pastedTextReferences';

describe('pastedTextReferences', () => {
    test('compacts at 500 Unicode code points including emoji', () => {
        expect(shouldCompactPastedText('a'.repeat(499))).toBe(false);
        expect(shouldCompactPastedText('😀'.repeat(500))).toBe(true);
    });

    test('keeps oversized payloads as raw text', () => {
        expect(canCompactPastedText('x'.repeat(COMPOSER_REFERENCE_LIMITS.pastePayloadLength + 1))).toBe(false);
        expect(canCompactPastedText('x'.repeat(500))).toBe(true);
    });

    test('creates localized unique tokens with sidecar payload', () => {
        const reference = createPastedTextReference('😀'.repeat(500), '[Paste 1]', [], ({ index, count }) => `Paste ${index}/${count}`);
        expect({ token: reference.token, characterCount: reference.characterCount, index: reference.index }).toEqual({ token: '[Paste 1/500]', characterCount: 500, index: 1 });
    });

    test('derives labels from valid Paste references in each document', () => {
        const document = { text: '[Paste 7]', references: [{ id: 'paste', kind: 'paste' as const, text: 'payload', characterCount: 7, index: 7, display: '[Paste 7]', start: 0, end: 9 }] };
        expect(getNextPastedTextReferenceIndex(document)).toBe(8);
        expect(getNextPastedTextReferenceIndex({ text: '', references: [] })).toBe(1);
        expect(getNextPastedTextReferenceIndex({ text: '[Paste 9]', references: [{ ...document.references[0], index: 9, start: 1, end: 2 }] })).toBe(1);
    });

    test('fills the first unused positive index when an existing label reaches MAX_SAFE_INTEGER', () => {
        const document = { text: '[Paste 1] [Paste max]', references: [
            { id: 'paste-1', kind: 'paste' as const, text: 'payload', characterCount: 7, index: 1, display: '[Paste 1]', start: 0, end: 9 },
            { id: 'paste-max', kind: 'paste' as const, text: 'payload', characterCount: 7, index: Number.MAX_SAFE_INTEGER, display: '[Paste max]', start: 10, end: 21 },
        ] };
        expect(getNextPastedTextReferenceIndex(document)).toBe(2);
    });
});
