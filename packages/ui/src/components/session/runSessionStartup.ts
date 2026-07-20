import { releaseSessionStartupBarrier } from '@/lib/session-startup-barrier';
import { startGlobalSessionIndexStartup } from '@/stores/useGlobalSessionsStore';

type SessionStartupWorktree = { path: string };

const normalizeDirectory = (value: string): string => value.replace(/\\/g, '/').replace(/\/+$/, '') || '/';

export const collectSessionStartupDirectories = (
  projectDirectories: Iterable<string>,
  worktreesByProject: ReadonlyMap<string, readonly SessionStartupWorktree[]>,
): string[] => {
  const directories = new Set<string>();

  for (const projectDirectory of projectDirectories) {
    if (!projectDirectory.trim()) continue;
    const normalizedProject = normalizeDirectory(projectDirectory);
    directories.add(normalizedProject);

    for (const [catalogProject, worktrees] of worktreesByProject) {
      if (normalizeDirectory(catalogProject) !== normalizedProject) continue;
      for (const worktree of worktrees) {
        if (worktree.path.trim()) directories.add(normalizeDirectory(worktree.path));
      }
    }
  }

  return [...directories];
};

export const runSessionStartup = async (
  directories: string[],
  start = startGlobalSessionIndexStartup,
): Promise<void> => {
  try {
    await start(directories);
  } catch (error) {
    console.warn('[SessionStartup] Initial session index sync failed:', error);
  } finally {
    releaseSessionStartupBarrier();
  }
};

export const runSessionStartupAfterSettingsHydration = async (
  settingsHydration: Promise<unknown> | null,
  getDirectories: () => string[],
  start = startGlobalSessionIndexStartup,
): Promise<void> => {
  await settingsHydration;
  await runSessionStartup(getDirectories(), start);
};
