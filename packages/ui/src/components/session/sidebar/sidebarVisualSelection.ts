import { create } from 'zustand';
import { flushSync } from 'react-dom';

import { beginSessionSwitchMeasure, markSessionSwitchHighlightPainted } from '@/lib/sessionSwitchPerf';
import {
    announceSessionSwitchIntent,
    getSessionSwitchIntent,
    subscribeSessionSwitchIntent,
    type SessionSwitchIntent,
} from '@/lib/sessionSwitchIntent';

type SidebarVisualSelectionState = {
    sessionId: string | null;
    setSessionId: (sessionId: string | null) => void;
};

type PendingSelection = {
    commit: () => void;
    commitFrame: number | null;
    fallbackTimer: number | null;
    intent: SessionSwitchIntent;
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
    cancelFrames(pendingSelection);
    pendingSelection = null;
};

export const requestSidebarVisualSelection = (sessionId: string, commit: () => void): void => {
    cancelPendingSidebarVisualSelection();
    beginSessionSwitchMeasure(true);
    const intent = announceSessionSwitchIntent(sessionId);
    pendingSelection = {
        commit,
        commitFrame: null,
        fallbackTimer: null,
        intent,
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

    const commitPendingSelection = () => {
        if (pendingSelection !== pending || getSessionSwitchIntent() !== pending.intent) {
            return;
        }
        pendingSelection = null;
        markSessionSwitchHighlightPainted();
        pending.commit();
    };

    if (typeof window === 'undefined') {
        commitPendingSelection();
        return;
    }

    // This interaction owns its paint barrier instead of joining the shared
    // background hydration queue. The first rAF lets the visual row selection
    // paint; the second commits session authority before the following paint.
    pending.commitFrame = window.requestAnimationFrame(() => {
        if (pendingSelection !== pending || getSessionSwitchIntent() !== pending.intent) {
            return;
        }
        pending.paintFrame = window.requestAnimationFrame(commitPendingSelection);
    });
};

export const syncSidebarVisualSelection = (sessionId: string | null): void => {
    if (pendingSelection) {
        return;
    }
    useSidebarVisualSelectionStore.getState().setSessionId(sessionId);
};

subscribeSessionSwitchIntent((intent) => {
    const pending = pendingSelection;
    if (!pending || pending.intent === intent) {
        return;
    }
    cancelPendingSidebarVisualSelection();
    useSidebarVisualSelectionStore.getState().setSessionId(intent.sessionId);
});
