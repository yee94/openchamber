import React from 'react';

import { getRuntimeKey } from '@/lib/runtime-switch';
import { getSettingsHydrationPromise } from '@/lib/settingsStartup';
import { useProjectsStore } from '@/stores/useProjectsStore';
import { runSessionStartupAfterSettingsHydration } from './runSessionStartup';

/** Owns the runtime session index cold-start restore and root-list refresh. */
export const SessionStartupCoordinator: React.FC = () => {
  const startedRef = React.useRef(false);

  React.useLayoutEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;

    const settingsHydration = getSettingsHydrationPromise(getRuntimeKey());
    void runSessionStartupAfterSettingsHydration(
      settingsHydration,
      () => useProjectsStore.getState().projects.map((project) => project.path),
    );
  }, []);

  return null;
};
