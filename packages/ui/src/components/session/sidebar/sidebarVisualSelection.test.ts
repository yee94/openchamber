import { afterEach, describe, expect, test } from 'bun:test';

import {
    cancelPendingSidebarVisualSelection,
    notifySidebarVisualSelectionCommitted,
    requestSidebarVisualSelection,
    syncSidebarVisualSelection,
    useSidebarVisualSelectionStore,
} from './sidebarVisualSelection';
import { announceSessionSwitchIntent } from '@/lib/sessionSwitchIntent';

afterEach(() => {
    cancelPendingSidebarVisualSelection();
    announceSessionSwitchIntent(null);
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

    test('a newer direct navigation intent invalidates an already pending sidebar commit', () => {
        const commits: string[] = [];
        requestSidebarVisualSelection('session-b', () => commits.push('session-b'));

        announceSessionSwitchIntent('session-c');
        notifySidebarVisualSelectionCommitted('session-b');

        expect(commits).toEqual([]);
        expect(useSidebarVisualSelectionStore.getState().sessionId).toBe('session-c');
    });
});
