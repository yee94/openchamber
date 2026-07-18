export type FileMentionAutocompleteInputSource = 'manual' | 'paste';

const SESSION_MENTION_PATTERN = /(^|[\s([{])(@session:([A-Za-z0-9_-]+))(?=$|[\s)\]},.!?;:])/g;

type SessionMentionRange = {
    start: number;
    end: number;
    id: string;
};

export type SessionMentionContext = {
    id: string;
    title: string;
    messages: Array<{
        role: string;
        text: string;
    }>;
};

export const getSessionMentionToken = (sessionId: string): string => `session:${sessionId}`;

export const findSessionMentionRanges = (text: string): SessionMentionRange[] => {
    const ranges: SessionMentionRange[] = [];
    SESSION_MENTION_PATTERN.lastIndex = 0;

    let match: RegExpExecArray | null;
    while ((match = SESSION_MENTION_PATTERN.exec(text)) !== null) {
        const start = match.index + match[1].length;
        ranges.push({ start, end: start + match[2].length, id: match[3] });
    }
    return ranges;
};

export const collectSessionMentionIds = (text: string): string[] => {
    const ids: string[] = [];
    const seen = new Set<string>();
    for (const { id } of findSessionMentionRanges(text)) {
        if (!seen.has(id)) {
            seen.add(id);
            ids.push(id);
        }
    }

    return ids;
};

export const replaceSessionMentionTokens = (text: string, labels: ReadonlyMap<string, string>): string => {
    let result = text;
    for (const range of findSessionMentionRanges(text).reverse()) {
        const label = labels.get(range.id) ?? range.id;
        result = `${result.slice(0, range.start)}@${label}${result.slice(range.end)}`;
    }
    return result;
};

export const resolveSessionMentionDeletion = (
    text: string,
    key: 'Backspace' | 'Delete',
    selectionStart: number,
    selectionEnd: number,
): { text: string; caret: number } | null => {
    const range = findSessionMentionRanges(text).find((candidate) => {
        if (selectionStart !== selectionEnd) {
            return selectionStart < candidate.end && selectionEnd > candidate.start;
        }
        return key === 'Backspace'
            ? selectionStart > candidate.start && selectionStart <= candidate.end
            : selectionStart >= candidate.start && selectionStart < candidate.end;
    });
    if (!range) return null;

    const removeEnd = text[range.end] === ' ' ? range.end + 1 : range.end;
    return {
        text: `${text.slice(0, range.start)}${text.slice(removeEnd)}`,
        caret: range.start,
    };
};

export const buildSessionMentionInstruction = (
    contexts: SessionMentionContext[],
    maxChars = 36_000,
): string | null => {
    if (contexts.length === 0) return null;

    const prefix = 'The user explicitly referenced these loaded OpenCode sessions. Use their conversation content as context for this request. Some content may be omitted to fit the context limit.\n';
    const payloadBudget = maxChars - prefix.length;
    if (payloadBudget < 2) return prefix.slice(0, maxChars);

    const separatorsLength = contexts.length + 1;
    const contextBudget = Math.max(2, Math.floor((payloadBudget - separatorsLength) / contexts.length));
    const payloads = contexts.map((context) => {
        const fitted: SessionMentionContext = {
            id: context.id,
            title: context.title,
            messages: [],
        };

        if (JSON.stringify(fitted).length > contextBudget) {
            let low = 0;
            let high = fitted.title.length;
            let fittedTitle = '';
            while (low <= high) {
                const middle = Math.floor((low + high) / 2);
                const candidateTitle = `${fitted.title.slice(0, middle)}...`;
                if (JSON.stringify({ ...fitted, title: candidateTitle }).length <= contextBudget) {
                    fittedTitle = candidateTitle;
                    low = middle + 1;
                } else {
                    high = middle - 1;
                }
            }
            fitted.title = fittedTitle;
        }

        for (const message of context.messages) {
            const nextMessages = [...fitted.messages, message];
            if (JSON.stringify({ ...fitted, messages: nextMessages }).length <= contextBudget) {
                fitted.messages = nextMessages;
                continue;
            }

            let low = 0;
            let high = message.text.length;
            let truncatedText = '';
            while (low <= high) {
                const middle = Math.floor((low + high) / 2);
                const candidateText = `${message.text.slice(0, middle)}\n[Message truncated]`;
                const candidate = { ...fitted, messages: [...fitted.messages, { ...message, text: candidateText }] };
                if (JSON.stringify(candidate).length <= contextBudget) {
                    truncatedText = candidateText;
                    low = middle + 1;
                } else {
                    high = middle - 1;
                }
            }
            if (truncatedText) fitted.messages.push({ ...message, text: truncatedText });
            break;
        }

        return JSON.stringify(fitted);
    });
    const instruction = `${prefix}[${payloads.join(',')}]`;
    return instruction.slice(0, maxChars);
};

export const getFileMentionAutocompleteQuery = ({
    value,
    cursorPosition,
    inputSource = 'manual',
    insertedText,
}: {
    value: string;
    cursorPosition: number;
    inputSource?: FileMentionAutocompleteInputSource;
    insertedText?: string;
}): string | null => {
    if (inputSource === 'paste' && insertedText?.includes('@')) {
        return null;
    }

    const textBeforeCursor = value.substring(0, cursorPosition);
    const lastAtSymbol = textBeforeCursor.lastIndexOf('@');
    if (lastAtSymbol === -1) {
        return null;
    }

    const charBefore = lastAtSymbol > 0 ? textBeforeCursor[lastAtSymbol - 1] : null;
    const textAfterAt = textBeforeCursor.substring(lastAtSymbol + 1);
    const isWordBoundary = !charBefore || /\s/.test(charBefore);
    if (!isWordBoundary || textAfterAt.includes(' ') || textAfterAt.includes('\n')) {
        return null;
    }

    return textAfterAt;
};
