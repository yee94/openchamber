import React from 'react';
import { useSessionFoldersStore } from '@/stores/useSessionFoldersStore';
import { getArchivedScopeKey } from '../utils';

type NormalizedProject = {
  id: string;
  normalizedPath: string;
};

type Args = {
  isSessionsLoading: boolean;
  fullCatalogSessionIds: Set<string>;
  fullCatalogGeneration: number;
  normalizedProjects: NormalizedProject[];
  cleanupSessions: (scopeKey: string, validSessionIds: Set<string>) => void;
};

export const useSessionFolderCleanup = (args: Args): void => {
  const {
    isSessionsLoading,
    fullCatalogSessionIds,
    fullCatalogGeneration,
    normalizedProjects,
    cleanupSessions,
  } = args;

  React.useEffect(() => {
    if (isSessionsLoading || fullCatalogGeneration === 0) {
      return;
    }

    const currentFoldersMap = useSessionFoldersStore.getState().foldersMap;
    const allScopeKeys = new Set([...Object.keys(currentFoldersMap), ...normalizedProjects.map((project) => getArchivedScopeKey(project.normalizedPath))]);
    allScopeKeys.forEach((scopeKey) => {
      cleanupSessions(scopeKey, fullCatalogSessionIds);
    });
  }, [
    cleanupSessions,
    fullCatalogGeneration,
    fullCatalogSessionIds,
    isSessionsLoading,
    normalizedProjects,
  ]);
};
