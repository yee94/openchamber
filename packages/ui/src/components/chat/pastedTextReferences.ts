const PASTED_TEXT_COMPACTION_THRESHOLD = 500;

export interface PastedTextReference {
    id: string;
    token: string;
    text: string;
    characterCount: number;
    index: number;
}

interface PastedTextDraft {
    text: string;
    references: PastedTextReference[];
}

const PASTED_TEXT_DRAFT_VERSION = 1;
const PASTED_TEXT_DRAFT_TYPE = 'openchamber-pasted-text-draft';

interface PastedTextReferenceRange {
    start: number;
    end: number;
    reference: PastedTextReference;
}

interface PastedTextReferenceDeletionIntent {
    key: 'Backspace' | 'Delete';
    selectionStart: number;
    selectionEnd: number;
    altKey?: boolean;
}

interface PastedTextReferenceDeletionResult {
    text: string;
    caret: number;
    removedIds: string[];
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

const clamp = (value: number, maximum: number): number => Math.max(0, Math.min(value, maximum));

export const shouldCompactPastedText = (text: string): boolean => (
    codePointCount(text) >= PASTED_TEXT_COMPACTION_THRESHOLD
);

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

        return {
            id: `pasted-text-${index}-${hashText(text)}`,
            token,
            text,
            characterCount,
            index,
        };
    }

    throw new Error('Unable to create a unique pasted text reference');
};

export const insertPastedTextReference = (
    message: string,
    start: number,
    end: number,
    token: string,
): { text: string; caret: number } => {
    const selectionStart = clamp(start, message.length);
    const selectionEnd = Math.max(selectionStart, clamp(end, message.length));
    const before = message.slice(0, selectionStart);
    const after = message.slice(selectionEnd);
    const prefix = before.length > 0 && !/\s$/.test(before) ? ' ' : '';
    const suffix = after.length > 0 && !/^\s/.test(after) ? ' ' : '';

    return {
        text: `${before}${prefix}${token}${suffix}${after}`,
        caret: before.length + prefix.length + token.length,
    };
};

export const findPastedTextReferenceRanges = (
    message: string,
    references: PastedTextReference[],
): PastedTextReferenceRange[] => {
    const seenTokens = new Set<string>();
    const ranges: PastedTextReferenceRange[] = [];

    for (const reference of references) {
        if (seenTokens.has(reference.token)) continue;
        seenTokens.add(reference.token);
        let start = message.indexOf(reference.token);
        while (start >= 0) {
            ranges.push({ start, end: start + reference.token.length, reference });
            start = message.indexOf(reference.token, start + reference.token.length);
        }
    }

    return ranges.sort((left, right) => left.start - right.start);
};

export const expandPastedTextReferences = (
    message: string,
    references: PastedTextReference[],
): string => {
    const ranges = findPastedTextReferenceRanges(message, references);
    let expanded = message;

    for (let index = ranges.length - 1; index >= 0; index -= 1) {
        const range = ranges[index];
        expanded = `${expanded.slice(0, range.start)}${range.reference.text}${expanded.slice(range.end)}`;
    }

    return expanded;
};

export const prunePastedTextReferences = (
    message: string,
    references: PastedTextReference[],
): PastedTextReference[] => (
    references.filter((reference) => message.includes(reference.token))
);

export const mergePastedTextReferences = (
    first: PastedTextReference[],
    second: PastedTextReference[],
): PastedTextReference[] => {
    const ids = new Set<string>();
    const tokens = new Set<string>();
    return [...first, ...second].filter((reference) => {
        if (ids.has(reference.id) || tokens.has(reference.token)) return false;
        ids.add(reference.id);
        tokens.add(reference.token);
        return true;
    });
};

const getWordDeletionRange = (
    text: string,
    key: PastedTextReferenceDeletionIntent['key'],
    cursor: number,
): { start: number; end: number } => {
    if (key === 'Backspace') {
        let start = cursor;
        while (start > 0 && /\s/.test(text[start - 1])) start -= 1;
        while (start > 0 && !/\s/.test(text[start - 1])) start -= 1;
        return { start, end: cursor };
    }

    let end = cursor;
    while (end < text.length && /\s/.test(text[end])) end += 1;
    while (end < text.length && !/\s/.test(text[end])) end += 1;
    return { start: cursor, end };
};

export const resolvePastedTextReferenceDeletion = (
    message: string,
    references: PastedTextReference[],
    intent: PastedTextReferenceDeletionIntent,
): PastedTextReferenceDeletionResult | null => {
    const selectionStart = clamp(intent.selectionStart, message.length);
    const selectionEnd = Math.max(selectionStart, clamp(intent.selectionEnd, message.length));
    let deletionRange: { start: number; end: number };

    if (selectionStart !== selectionEnd) {
        deletionRange = { start: selectionStart, end: selectionEnd };
    } else if (intent.altKey) {
        deletionRange = getWordDeletionRange(message, intent.key, selectionStart);
    } else if (intent.key === 'Backspace') {
        deletionRange = { start: Math.max(0, selectionStart - 1), end: selectionStart };
    } else {
        deletionRange = { start: selectionStart, end: Math.min(message.length, selectionStart + 1) };
    }

    if (deletionRange.start === deletionRange.end) return null;

    const intersected = findPastedTextReferenceRanges(message, references).filter((range) => (
        range.start < deletionRange.end && range.end > deletionRange.start
    ));
    if (intersected.length === 0) return null;

    const start = Math.min(deletionRange.start, ...intersected.map((range) => range.start));
    const end = Math.max(deletionRange.end, ...intersected.map((range) => range.end));
    return {
        text: `${message.slice(0, start)}${message.slice(end)}`,
        caret: start,
        removedIds: [...new Set(intersected.map((range) => range.reference.id))],
    };
};

export const serializePastedTextReferences = (references: PastedTextReference[]): string => JSON.stringify(references);

const isValidReference = (value: unknown): value is PastedTextReference => {
    if (typeof value !== 'object' || value === null) return false;
    const reference = value as Record<string, unknown>;
    const { id, token, text, characterCount, index } = reference;
    return typeof id === 'string'
        && id.length > 0
        && typeof token === 'string'
        && token.length > 0
        && typeof text === 'string'
        && typeof characterCount === 'number'
        && Number.isSafeInteger(characterCount)
        && characterCount === codePointCount(text)
        && typeof index === 'number'
        && Number.isSafeInteger(index)
        && index >= 1;
};

export const parsePastedTextReferences = (serialized: string): PastedTextReference[] => {
    try {
        const parsed: unknown = JSON.parse(serialized);
        if (!Array.isArray(parsed) || !parsed.every(isValidReference)) return [];

        const ids = new Set<string>();
        const tokens = new Set<string>();
        for (const reference of parsed) {
            if (ids.has(reference.id) || tokens.has(reference.token)) return [];
            ids.add(reference.id);
            tokens.add(reference.token);
        }
        return parsed;
    } catch {
        return [];
    }
};

export const serializePastedTextDraft = (draft: PastedTextDraft): string => JSON.stringify({
    type: PASTED_TEXT_DRAFT_TYPE,
    version: PASTED_TEXT_DRAFT_VERSION,
    text: draft.text,
    references: draft.references,
});

export const parsePastedTextDraft = (serialized: string): PastedTextDraft | null => {
    try {
        const parsed: unknown = JSON.parse(serialized);
        if (typeof parsed !== 'object' || parsed === null || (parsed as Record<string, unknown>).type !== PASTED_TEXT_DRAFT_TYPE) {
            return { text: serialized, references: [] };
        }
        const draft = parsed as Record<string, unknown>;
        if (draft.version !== PASTED_TEXT_DRAFT_VERSION || typeof draft.text !== 'string' || !Array.isArray(draft.references)) {
            return null;
        }
        const references = parsePastedTextReferences(JSON.stringify(draft.references));
        if (references.length !== draft.references.length) return null;
        return { text: draft.text, references };
    } catch {
        return { text: serialized, references: [] };
    }
};
