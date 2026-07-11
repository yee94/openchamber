export type SessionSwitchIntent = Readonly<{
    revision: number;
    sessionId: string | null;
}>;

type SessionSwitchIntentListener = (intent: SessionSwitchIntent) => void;

let currentIntent: SessionSwitchIntent = {
    revision: 0,
    sessionId: null,
};
const listeners = new Set<SessionSwitchIntentListener>();

/**
 * Announces navigation intent before any expensive session work starts.
 * Every announcement gets a unique revision, including A -> B -> A, so stale
 * delayed callbacks cannot mistake the second A for the first one.
 */
export const announceSessionSwitchIntent = (sessionId: string | null): SessionSwitchIntent => {
    currentIntent = {
        revision: currentIntent.revision + 1,
        sessionId,
    };
    for (const listener of listeners) {
        listener(currentIntent);
    }
    return currentIntent;
};

export const getSessionSwitchIntent = (): SessionSwitchIntent => currentIntent;

export const subscribeSessionSwitchIntent = (listener: SessionSwitchIntentListener): (() => void) => {
    listeners.add(listener);
    return () => listeners.delete(listener);
};
