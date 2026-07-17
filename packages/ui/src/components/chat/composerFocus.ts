import type { RefObject } from 'react';

export const resolveComposerTextarea = (
    textareaRef: RefObject<HTMLTextAreaElement | null>,
): HTMLTextAreaElement | null => {
    const textarea = textareaRef.current;
    if (!textarea || !textarea.isConnected || textarea.disabled) {
        return null;
    }
    return textarea;
};

export const focusComposerTextarea = (
    textareaRef: RefObject<HTMLTextAreaElement | null>,
): boolean => {
    const textarea = resolveComposerTextarea(textareaRef);
    if (!textarea) {
        return false;
    }
    textarea.focus({ preventScroll: true });
    return true;
};
