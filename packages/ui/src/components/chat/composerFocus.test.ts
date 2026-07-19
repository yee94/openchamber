import { describe, expect, test } from 'bun:test';
import type { RefObject } from 'react';

import { focusComposerTextarea, resolveComposerTextarea, shouldApplyComposerDomCorrection } from './composerFocus';

type FakeTextarea = {
    isConnected: boolean;
    disabled: boolean;
    focus: (options?: FocusOptions) => void;
};

const createTextarea = () => {
    const focusCalls: FocusOptions[] = [];
    const textarea: FakeTextarea = {
        isConnected: true,
        disabled: false,
        focus: (options) => focusCalls.push(options ?? {}),
    };
    return { focusCalls, textarea };
};

const textareaRef = (current: FakeTextarea | null): RefObject<HTMLTextAreaElement | null> => (
    { current: current as HTMLTextAreaElement | null }
);

describe('composerFocus', () => {
    test('resolves and focuses only the textarea owned by the ref', () => {
        const globalTextarea = createTextarea();
        const currentTextarea = createTextarea();
        const ref = textareaRef(currentTextarea.textarea);

        expect(resolveComposerTextarea(ref)).toBe(currentTextarea.textarea);
        expect(focusComposerTextarea(ref)).toBe(true);
        expect(currentTextarea.focusCalls).toEqual([{ preventScroll: true }]);
        expect(globalTextarea.focusCalls).toEqual([]);
    });

    for (const [state, properties] of [
        ['disconnected', { isConnected: false, disabled: false }],
        ['disabled', { isConnected: true, disabled: true }],
    ] as const) {
        test(`does not focus a ${state} textarea`, () => {
            const target = createTextarea();
            Object.assign(target.textarea, properties);
            const ref = textareaRef(target.textarea);

            expect(resolveComposerTextarea(ref)).toBeNull();
            expect(focusComposerTextarea(ref)).toBe(false);
            expect(target.focusCalls).toEqual([]);
        });
    }

    test('does not focus when the ref is null', () => {
        const ref = textareaRef(null);

        expect(resolveComposerTextarea(ref)).toBeNull();
        expect(focusComposerTextarea(ref)).toBe(false);
    });

    test('keeps native IME composition ownership over value and selection correction', () => {
        expect(shouldApplyComposerDomCorrection(true, true)).toBe(false);
        expect(shouldApplyComposerDomCorrection(true, false)).toBe(true);
        expect(shouldApplyComposerDomCorrection(false, false)).toBe(false);
    });
});
