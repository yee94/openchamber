import { create } from 'zustand';
import { flushSync } from 'react-dom';

import { scheduleAfterPaintTask } from '@/lib/afterPaintTaskQueue';
import { beginSessionSwitchMeasure, markSessionSwitchHighlightPainted } from '@/lib/sessionSwitchPerf';

type SidebarVisualSelectionState = {
    sessionId: string | null;
    setSessionId: (sessionId: string | null) => void;
};

type PendingSelection = {
    cancelCommit: () => void;
    commit: () => void;
    commitFrame: number | null;
    fallbackTimer: number | null;
    paintFrame: number | null;
    scheduled: boolean;
    sessionId: string;
};

export const useSidebarVisualSelectionStore = create<SidebarVisualSelectionState>()((set) => ({
    sessionId: null,
    setSessionId: (sessionId) => set((state) => (
        state.sessionId === sessionId ? state : { sessionId }
    )),
}));

let pendingSelection: PendingSelection | null = null;

const cancelFrames = (pending: PendingSelection): void => {
    if (typeof window === 'undefined') {
        return;
    }
    if (pending.commitFrame !== null) {
        window.cancelAnimationFrame(pending.commitFrame);
    }
    if (pending.paintFrame !== null) {
        window.cancelAnimationFrame(pending.paintFrame);
    }
    if (pending.fallbackTimer !== null) {
        window.clearTimeout(pending.fallbackTimer);
    }
};

export const cancelPendingSidebarVisualSelection = (): void => {
    if (!pendingSelection) {
        return;
    }
    pendingSelection.cancelCommit();
    cancelFrames(pendingSelection);
    pendingSelection = null;
};

export const requestSidebarVisualSelection = (sessionId: string, commit: () => void): void => {
    cancelPendingSidebarVisualSelection();
    beginSessionSwitchMeasure(true);
    pendingSelection = {
        cancelCommit: () => {},
        commit,
        commitFrame: null,
        fallbackTimer: null,
        paintFrame: null,
        scheduled: false,
        sessionId,
    };
    flushSync(() => {
        useSidebarVisualSelectionStore.getState().setSessionId(sessionId);
    });
    if (typeof window !== 'undefined') {
        pendingSelection.fallbackTimer = window.setTimeout(() => {
            notifySidebarVisualSelectionCommitted(sessionId);
        }, 150);
    }
};

export const notifySidebarVisualSelectionCommitted = (sessionId: string): void => {
    const pending = pendingSelection;
    if (!pending || pending.sessionId !== sessionId || pending.scheduled) {
        return;
    }
    pending.scheduled = true;
    if (typeof window !== 'undefined' && pending.fallbackTimer !== null) {
        window.clearTimeout(pending.fallbackTimer);
        pending.fallbackTimer = null;
    }

    if (typeof window !== 'undefined') {
        pending.commitFrame = window.requestAnimationFrame(() => {
            pending.paintFrame = window.requestAnimationFrame(markSessionSwitchHighlightPainted);
        });
    }

    pending.cancelCommit = scheduleAfterPaintTask(() => {
        if (pendingSelection !== pending) {
            return;
        }
        pendingSelection = null;
        pending.commit();
    });
};

export const syncSidebarVisualSelection = (sessionId: string | null): void => {
    if (pendingSelection) {
        return;
    }
    useSidebarVisualSelectionStore.getState().setSessionId(sessionId);
};
