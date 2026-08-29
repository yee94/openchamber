import React from 'react';

import { useRuntimeAPIs } from '@/hooks/useRuntimeAPIs';
import { useGitStore } from '@/stores/useGitStore';

const POLL_INTERVAL_MS = 10_000;

const isBrowserActive = (): boolean => {
  if (typeof document !== 'undefined' && document.hidden) {
    return false;
  }
  if (typeof navigator !== 'undefined' && !navigator.onLine) {
    return false;
  }
  return true;
};

/**
 * Keeps `useGitStore` status fresh while a Files or Git surface is the visible
 * consumer. Hidden trees must not start their own interval.
 */
export const useVisibleGitStatusSync = (
  directory: string | null | undefined,
  active: boolean,
) => {
  const { git } = useRuntimeAPIs();
  const ensureStatus = useGitStore((state) => state.ensureStatus);

  React.useEffect(() => {
    if (!active || !directory || !git) {
      return;
    }

    void ensureStatus(directory, git);

    const id = window.setInterval(() => {
      if (!isBrowserActive()) {
        return;
      }
      void ensureStatus(directory, git);
    }, POLL_INTERVAL_MS);

    return () => {
      window.clearInterval(id);
    };
  }, [active, directory, ensureStatus, git]);
};
