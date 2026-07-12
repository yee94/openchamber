import React from 'react';

import { useProjectsStore } from '@/stores/useProjectsStore';
import { runSessionStartup } from './runSessionStartup';

/** Owns the runtime session index cold-start restore and root-list refresh. */
export const SessionStartupCoordinator: React.FC = () => {
  const projects = useProjectsStore((state) => state.projects);
  const startedRef = React.useRef(false);

  React.useLayoutEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;

    void runSessionStartup(projects.map((project) => project.path));
  }, [projects]);

  return null;
};
