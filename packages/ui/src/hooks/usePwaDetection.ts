import React from 'react';
import { getPWADisplayMode, type PWADisplayMode } from '@/lib/pwa';

type PwaDetectionState = {
  displayMode: PWADisplayMode;
  installed: boolean;
  browserTab: boolean;
};

type MediaQueryListWithLegacyListeners = MediaQueryList & {
  addListener?: (listener: () => void) => void;
  removeListener?: (listener: () => void) => void;
};

const SERVER_SNAPSHOT: PwaDetectionState = {
  displayMode: 'browser',
  installed: false,
  browserTab: true,
};

const listeners = new Set<() => void>();
let snapshot = SERVER_SNAPSHOT;
let browserSnapshotInitialized = false;
let stopWatching: (() => void) | undefined;

const getState = (): PwaDetectionState => {
  const displayMode = getPWADisplayMode();
  return {
    displayMode,
    installed: displayMode !== 'browser',
    browserTab: displayMode === 'browser',
  };
};

const getSnapshot = (): PwaDetectionState => {
  if (!browserSnapshotInitialized && typeof window !== 'undefined') {
    snapshot = getState();
    browserSnapshotInitialized = true;
  }
  return snapshot;
};

const notifyListeners = () => {
  const next = getState();
  browserSnapshotInitialized = true;
  if (next.displayMode === snapshot.displayMode) {
    return;
  }
  snapshot = next;
  listeners.forEach((listener) => listener());
};

const startWatching = () => {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') {
    return undefined;
  }

  const queries: MediaQueryListWithLegacyListeners[] = [
    window.matchMedia('(display-mode: standalone)'),
    window.matchMedia('(display-mode: minimal-ui)'),
    window.matchMedia('(display-mode: fullscreen)'),
    window.matchMedia('(display-mode: window-controls-overlay)'),
  ];

  for (const query of queries) {
    if (typeof query.addEventListener === 'function') {
      query.addEventListener('change', notifyListeners);
    } else if (typeof query.addListener === 'function') {
      query.addListener(notifyListeners);
    }
  }

  window.addEventListener('appinstalled', notifyListeners);
  window.addEventListener('focus', notifyListeners);

  return () => {
    for (const query of queries) {
      if (typeof query.removeEventListener === 'function') {
        query.removeEventListener('change', notifyListeners);
      } else if (typeof query.removeListener === 'function') {
        query.removeListener(notifyListeners);
      }
    }
    window.removeEventListener('appinstalled', notifyListeners);
    window.removeEventListener('focus', notifyListeners);
  };
};

const subscribe = (listener: () => void) => {
  listeners.add(listener);
  stopWatching ??= startWatching();
  notifyListeners();

  return () => {
    listeners.delete(listener);
    if (listeners.size === 0) {
      stopWatching?.();
      stopWatching = undefined;
    }
  };
};

export const usePwaDetection = (): PwaDetectionState => {
  return React.useSyncExternalStore(subscribe, getSnapshot, () => SERVER_SNAPSHOT);
};
