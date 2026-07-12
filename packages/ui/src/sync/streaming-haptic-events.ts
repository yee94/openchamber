type StreamingHapticEvent = {
  sessionID: string;
  messageID: string;
  partID: string;
  kind: 'thinking' | 'text';
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
