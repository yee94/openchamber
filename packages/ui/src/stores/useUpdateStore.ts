import { create } from 'zustand';
import type { UpdateInfo, UpdateProgress } from '@/lib/desktop';
import {
  checkForDesktopUpdates,
  downloadDesktopUpdate,
  restartToApplyUpdate,
  isDesktopLocalOriginActive,
  isTauriShell,
  isWebRuntime,
} from '@/lib/desktop';

export type UpdateState = {
  checking: boolean;
  available: boolean;
  downloading: boolean;
  downloaded: boolean;
  info: UpdateInfo | null;
  progress: UpdateProgress | null;
  error: string | null;
  runtimeType: 'desktop' | 'web' | 'vscode' | null;
  lastChecked: number | null;
};

interface UpdateStore extends UpdateState {
  checkForUpdates: () => Promise<void>;
  downloadUpdate: () => Promise<void>;
  restartToUpdate: () => Promise<void>;
  dismiss: () => void;
  reset: () => void;
}

async function checkForWebUpdates(): Promise<UpdateInfo | null> {
  try {
    const response = await fetch('/api/openchamber/update-check', {
      method: 'GET',
      headers: { Accept: 'application/json' },
    });

    if (!response.ok) {
      throw new Error(`Server responded with ${response.status}`);
    }

    const data = await response.json();
    return {
      available: data.available ?? false,
      version: data.version,
      currentVersion: data.currentVersion ?? 'unknown',
      body: data.body,
      packageManager: data.packageManager,
      updateCommand: data.updateCommand,
    };
  } catch (error) {
    console.warn('Failed to check for web updates:', error);
    return null;
  }
}

function detectRuntimeType(): 'desktop' | 'web' | 'vscode' | null {
  if (isTauriShell()) {
    // Only use Tauri updater when we're on the local instance.
    // When viewing a remote host inside the desktop shell, treat update as web update.
    return isDesktopLocalOriginActive() ? 'desktop' : 'web';
  }
  if (isWebRuntime()) return 'web';
  return null;
}

const initialState: UpdateState = {
  checking: false,
  available: false,
  downloading: false,
  downloaded: false,
  info: null,
  progress: null,
  error: null,
  runtimeType: null,
  lastChecked: null,
};

export const useUpdateStore = create<UpdateStore>()((set, get) => ({
  ...initialState,

  checkForUpdates: async () => {
    const runtime = detectRuntimeType();
    if (!runtime) return;

    set({ checking: true, error: null, runtimeType: runtime });

    try {
      let info: UpdateInfo | null = null;

      if (runtime === 'desktop') {
        info = await checkForDesktopUpdates();
      } else if (runtime === 'web') {
        info = await checkForWebUpdates();
      }

      set({
        checking: false,
        available: info?.available ?? false,
        info,
        lastChecked: Date.now(),
      });
    } catch (error) {
      set({
        checking: false,
        error: error instanceof Error ? error.message : 'Failed to check for updates',
      });
    }
  },

  downloadUpdate: async () => {
    const { available, runtimeType } = get();

    // For web runtime, there's no download - user uses in-app update or CLI
    if (runtimeType !== 'desktop' || !available) {
      return;
    }

    set({ downloading: true, error: null, progress: null });

    try {
      const ok = await downloadDesktopUpdate((progress) => {
        set({ progress });
      });
      if (!ok) {
        throw new Error('Desktop update only works on Local instance');
      }
      set({ downloading: false, downloaded: true });
    } catch (error) {
      set({
        downloading: false,
        error: error instanceof Error ? error.message : 'Failed to download update',
      });
    }
  },

  restartToUpdate: async () => {
    const { downloaded, runtimeType } = get();

    if (runtimeType !== 'desktop' || !downloaded) {
      return;
    }

    try {
      const ok = await restartToApplyUpdate();
      if (!ok) {
        throw new Error('Desktop restart only works on Local instance');
      }
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to restart',
      });
    }
  },

  dismiss: () => {
    set({ available: false, downloaded: false, info: null });
  },

  reset: () => {
    set(initialState);
  },
}));
