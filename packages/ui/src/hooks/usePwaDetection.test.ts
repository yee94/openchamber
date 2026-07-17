import { describe, expect, mock, test } from 'bun:test';

let externalStore: {
  subscribe: (listener: () => void) => () => void;
  getSnapshot: () => unknown;
  getServerSnapshot: () => unknown;
} | undefined;

mock.module('react', () => ({
  createContext: () => ({}),
  default: {
    createContext: () => ({}),
    useSyncExternalStore: (
      subscribe: (listener: () => void) => () => void,
      getSnapshot: () => unknown,
      getServerSnapshot: () => unknown,
    ) => {
      externalStore = { subscribe, getSnapshot, getServerSnapshot };
      return getSnapshot();
    },
  },
}));

const { usePwaDetection } = await import('./usePwaDetection');

describe('usePwaDetection', () => {
  test('shares browser subscriptions and provides a stable SSR snapshot', () => {
    const queryListeners = new Set<() => void>();
    const windowListeners = new Map<string, Set<() => void>>();
    let addedQueries = 0;
    let removedQueries = 0;
    let addedWindowListeners = 0;
    let removedWindowListeners = 0;
    const query = {
      matches: false,
      media: '',
      onchange: null,
      addEventListener: (_: string, listener: () => void) => {
        addedQueries++;
        queryListeners.add(listener);
      },
      removeEventListener: (_: string, listener: () => void) => {
        removedQueries++;
        queryListeners.delete(listener);
      },
      addListener: undefined,
      removeListener: undefined,
      dispatchEvent: () => true,
    } as unknown as MediaQueryList;
    const fakeWindow = {
      navigator: {},
      matchMedia: () => query,
      addEventListener: (type: string, listener: () => void) => {
        addedWindowListeners++;
        const listeners = windowListeners.get(type) ?? new Set<() => void>();
        listeners.add(listener);
        windowListeners.set(type, listeners);
      },
      removeEventListener: (type: string, listener: () => void) => {
        removedWindowListeners++;
        windowListeners.get(type)?.delete(listener);
      },
    };
    const previousWindow = Object.getOwnPropertyDescriptor(globalThis, 'window');
    const previousDocument = Object.getOwnPropertyDescriptor(globalThis, 'document');
    Object.defineProperty(globalThis, 'window', { configurable: true, value: fakeWindow });
    Object.defineProperty(globalThis, 'document', { configurable: true, value: { referrer: '' } });

    try {
      expect(usePwaDetection()).toEqual({ displayMode: 'browser', installed: false, browserTab: true });
      const store = externalStore;
      if (!store) throw new Error('external store was not registered');
      expect(store.getServerSnapshot()).toEqual({ displayMode: 'browser', installed: false, browserTab: true });

      const unsubscribeFirst = store.subscribe(() => {});
      const unsubscribeSecond = store.subscribe(() => {});
      expect(addedQueries).toBe(4);
      expect(addedWindowListeners).toBe(2);

      unsubscribeFirst();
      expect(removedQueries).toBe(0);
      unsubscribeSecond();
      expect(removedQueries).toBe(4);
      expect(removedWindowListeners).toBe(2);
    } finally {
      if (previousWindow) {
        Object.defineProperty(globalThis, 'window', previousWindow);
      } else {
        Reflect.deleteProperty(globalThis, 'window');
      }
      if (previousDocument) {
        Object.defineProperty(globalThis, 'document', previousDocument);
      } else {
        Reflect.deleteProperty(globalThis, 'document');
      }
    }
  });
});
