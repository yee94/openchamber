export type StreamingHapticEvent = {
  sessionID: string;
  messageID: string;
  partID: string;
  kind: 'thinking' | 'text' | 'tool';
};

export type VisiblePartHapticState = {
  identity: string;
  content: string;
  appeared: boolean;
  wasActive: boolean;
};

type VisiblePartHapticInput = {
  identity: string;
  content: string;
  isActive: boolean;
  mode: 'appearance' | 'changes';
};

export const evaluateVisiblePartHaptic = (
  state: VisiblePartHapticState | null,
  input: VisiblePartHapticInput,
): { shouldEmit: boolean; nextState: VisiblePartHapticState } => {
  const previous = state?.identity === input.identity ? state : null;
  const isVisible = input.content.trim().length > 0;
  const appearedBefore = previous?.appeared ?? false;
  const wasActive = (previous?.wasActive ?? false) || input.isActive;
  const contentChanged = input.content !== (previous?.content ?? '');

  return {
    shouldEmit: input.mode === 'appearance'
      ? wasActive && isVisible && !appearedBefore
      : wasActive && isVisible && contentChanged,
    nextState: {
      identity: input.identity,
      content: input.content,
      appeared: appearedBefore || isVisible,
      wasActive,
    },
  };
};

export const shouldEmitToolAppearanceHaptic = (isInitialObservation: boolean, isActive: boolean): boolean => {
  return !isInitialObservation || isActive;
};

export const createStreamingHapticEventDeduper = (maxEntries = 1000) => {
  const seenAppearances = new Set<string>();
  const entryLimit = Math.max(1, Math.floor(maxEntries));

  return (event: StreamingHapticEvent): boolean => {
    if (event.kind === 'text') return true;

    const key = `${event.sessionID}\u0000${event.messageID}\u0000${event.partID}\u0000${event.kind}`;
    if (seenAppearances.has(key)) return false;

    seenAppearances.add(key);
    while (seenAppearances.size > entryLimit) {
      const oldest = seenAppearances.values().next().value;
      if (typeof oldest !== 'string') break;
      seenAppearances.delete(oldest);
    }
    return true;
  };
};

export type StreamingHapticEventQueue = {
  enqueue: (event: StreamingHapticEvent) => void;
  peek: () => StreamingHapticEvent | undefined;
  dequeue: () => StreamingHapticEvent | undefined;
  size: () => number;
  clear: () => void;
};

/**
 * Keeps one current text pulse while preserving one-shot part appearances in
 * arrival order. The cap bounds memory during a sustained native cadence.
 */
export const createStreamingHapticEventQueue = (maxEntries = 100): StreamingHapticEventQueue => {
  const events: StreamingHapticEvent[] = [];
  const entryLimit = Math.max(1, Math.floor(maxEntries));

  return {
    enqueue: (event) => {
      if (event.kind === 'text') {
        for (let index = events.length - 1; index >= 0; index -= 1) {
          if (events[index].kind === 'text') {
            events.splice(index, 1);
          }
        }
      }

      events.push(event);
      while (events.length > entryLimit) {
        events.shift();
      }
    },
    peek: () => events[0],
    dequeue: () => events.shift(),
    size: () => events.length,
    clear: () => {
      events.length = 0;
    },
  };
};

type Listener = (event: StreamingHapticEvent) => void;

const listeners = new Set<Listener>();

export const hasStreamingHapticSubscribers = (): boolean => listeners.size > 0;

export const emitStreamingHapticEvent = (event: StreamingHapticEvent): void => {
  for (const listener of listeners) listener(event);
};

export const subscribeToStreamingHapticEvents = (listener: Listener): (() => void) => {
  listeners.add(listener);
  return () => listeners.delete(listener);
};
