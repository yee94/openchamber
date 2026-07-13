type SettingsStartupDependencies = {
  runtimeKey: string;
  initializeAppearance: () => Promise<void>;
  syncSettings: () => Promise<void>;
  applyDirectory: () => Promise<void>;
  onError: (stage: 'appearance' | 'secondary', error: unknown) => void;
};

const hydrationByRuntime = new Map<string, Promise<boolean>>();

export const getSettingsHydrationPromise = (runtimeKey: string): Promise<boolean> | null => {
  return hydrationByRuntime.get(runtimeKey) ?? null;
};

export const ensureSettingsHydrated = ({
  runtimeKey,
  initializeAppearance,
  syncSettings,
  applyDirectory,
  onError,
}: SettingsStartupDependencies, options: { force?: boolean } = {}): Promise<boolean> => {
  const existing = hydrationByRuntime.get(runtimeKey);
  if (existing && !options.force) return existing;

  const hydration = (async () => {
    if (existing) await existing;

    try {
      await initializeAppearance();
    } catch (error) {
      onError('appearance', error);
      return false;
    }

    try {
      await Promise.all([syncSettings(), applyDirectory()]);
    } catch (error) {
      onError('secondary', error);
    }
    return true;
  })();
  hydrationByRuntime.set(runtimeKey, hydration);
  return hydration;
};

export const runSettingsStartup = async ({
  runtimeKey,
  initializeAppearance,
  syncSettings,
  applyDirectory,
  startWatchers,
  onError,
}: SettingsStartupDependencies & { startWatchers: () => void }): Promise<void> => {
  const appearanceReady = await ensureSettingsHydrated({
    runtimeKey,
    initializeAppearance,
    syncSettings,
    applyDirectory,
    onError,
  });
  if (!appearanceReady) return;

  // Autosave observes Zustand changes. Starting it before hydration finishes
  // writes transient/default values back to the server during cold startup.
  startWatchers();
};
