import { afterEach, describe, expect, test } from 'bun:test';

import {
    cancelPendingSidebarVisualSelection,
    notifySidebarVisualSelectionCommitted,
    requestSidebarVisualSelection,
    syncSidebarVisualSelection,
    useSidebarVisualSelectionStore,
} from './sidebarVisualSelection';

afterEach(() => {
    cancelPendingSidebarVisualSelection();
    syncSidebarVisualSelection(null);
});

describe('sidebarVisualSelection', () => {
    test('commits authority only after the selected row reports a DOM commit', () => {
        let commits = 0;
        requestSidebarVisualSelection('session-a', () => {
            commits += 1;
        });

        expect(useSidebarVisualSelectionStore.getState().sessionId).toBe('session-a');
        expect(commits).toBe(0);

        notifySidebarVisualSelectionCommitted('session-a');

        expect(commits).toBe(1);
    });

    test('cancels an intermediate selection during rapid switching', () => {
        const commits: string[] = [];
        requestSidebarVisualSelection('session-a', () => commits.push('session-a'));
        requestSidebarVisualSelection('session-b', () => commits.push('session-b'));

        notifySidebarVisualSelectionCommitted('session-a');
        expect(commits).toEqual([]);

        notifySidebarVisualSelectionCommitted('session-b');
        expect(commits).toEqual(['session-b']);
    });
});
