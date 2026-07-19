import { canAddPasteComposerReference, validateComposerDocument, type ComposerDocument } from '@/composer/document';

const PASTED_TEXT_COMPACTION_THRESHOLD = 500;

export interface PastedTextReference {
    id: string;
    token: string;
    text: string;
    characterCount: number;
    index: number;
}

const codePointCount = (text: string): number => Array.from(text).length;

const hashText = (text: string): string => {
    let hash = 2166136261;
    for (const char of text) {
        hash ^= char.codePointAt(0) ?? 0;
        hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(36);
};

export const shouldCompactPastedText = (text: string): boolean => codePointCount(text) >= PASTED_TEXT_COMPACTION_THRESHOLD;

/** Allocates the next durable Paste label from the currently valid document. */
export const getNextPastedTextReferenceIndex = (document: ComposerDocument): number => {
    const valid = validateComposerDocument(document.text, document.references).document.references;
    const maximum = valid.reduce((max, reference) => {
        const index = reference.kind === 'paste' ? (reference as { index: unknown }).index : 0;
        return typeof index === 'number' && Number.isSafeInteger(index) && index >= 1 ? Math.max(max, index) : max;
    }, 0);
    if (maximum < Number.MAX_SAFE_INTEGER) return maximum + 1;
    const used = new Set(valid.flatMap((reference) => reference.kind === 'paste' && typeof reference.index === 'number' && Number.isSafeInteger(reference.index) && reference.index >= 1 ? [reference.index] : []));
    for (let index = 1; index <= valid.length + 1; index += 1) {
        if (!used.has(index)) return index;
    }
    return 1;
};

/** A compact token is valid only when its sidecar payload can serialize completely. */
export const canCompactPastedText = (documentOrText: ComposerDocument | string, candidateText?: string): boolean => {
    const text = candidateText ?? documentOrText;
    if (typeof text !== 'string' || !shouldCompactPastedText(text)) return false;
    return typeof documentOrText === 'string'
        ? canAddPasteComposerReference({ text: '', references: [] }, text)
        : canAddPasteComposerReference(documentOrText, text);
};

/** Builds the localized visible token and payload consumed by ComposerDocument insertion. */
export const createPastedTextReference = (
    text: string,
    currentMessage: string,
    existingReferences: PastedTextReference[],
    formatLabel: (input: { index: number; count: number }) => string,
    startingIndex = 1,
): PastedTextReference => {
    const characterCount = codePointCount(text);
    const usedTokens = new Set(existingReferences.map((reference) => reference.token));
    for (let index = startingIndex; index < Number.MAX_SAFE_INTEGER; index += 1) {
        const token = `[${formatLabel({ index, count: characterCount })}]`;
        if (currentMessage.includes(token) || usedTokens.has(token)) continue;
        return { id: `pasted-text-${index}-${hashText(text)}`, token, text, characterCount, index };
    }
    throw new Error('Unable to create a unique pasted text reference');
};
