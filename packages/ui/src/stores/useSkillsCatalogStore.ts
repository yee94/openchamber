import { create } from 'zustand';
import { devtools } from 'zustand/middleware';

import type {
  SkillsCatalogResponse,
  SkillsCatalogSource,
  SkillsCatalogItem,
  SkillsRepoScanRequest,
  SkillsRepoScanResponse,
  SkillsInstallRequest,
  SkillsInstallResponse,
  SkillsInstallError,
} from '@/lib/api/types';

import { useSkillsStore } from '@/stores/useSkillsStore';
import { opencodeClient } from '@/lib/opencode/client';

const getCurrentDirectory = (): string | null => {
  const opencodeDirectory = opencodeClient.getDirectory();
  if (typeof opencodeDirectory === 'string' && opencodeDirectory.trim().length > 0) {
    return opencodeDirectory;
  }

  try {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const store = (window as any).__zustand_directory_store__;
    if (store) {
      return store.getState().currentDirectory;
    }
  } catch {
    // ignore
  }

  return null;
};

export interface SkillsCatalogState {
  sources: SkillsCatalogSource[];
  itemsBySource: Record<string, SkillsCatalogItem[]>;
  selectedSourceId: string | null;

  isLoadingCatalog: boolean;
  isScanning: boolean;
  isInstalling: boolean;

  lastCatalogError: SkillsCatalogResponse['error'] | null;
  lastScanError: SkillsRepoScanResponse['error'] | null;
  lastInstallError: SkillsInstallError | null;

  scanResults: SkillsCatalogItem[] | null;

  setSelectedSource: (id: string | null) => void;

  loadCatalog: (options?: { refresh?: boolean }) => Promise<boolean>;
  scanRepo: (request: SkillsRepoScanRequest) => Promise<SkillsRepoScanResponse>;
  installSkills: (request: SkillsInstallRequest) => Promise<SkillsInstallResponse>;
}

export const useSkillsCatalogStore = create<SkillsCatalogState>()(
  devtools(
    (set, get) => ({
      sources: [],
      itemsBySource: {},
      selectedSourceId: null,

      isLoadingCatalog: false,
      isScanning: false,
      isInstalling: false,

      lastCatalogError: null,
      lastScanError: null,
      lastInstallError: null,

      scanResults: null,

      setSelectedSource: (id) => set({ selectedSourceId: id }),

      loadCatalog: async (options) => {
        set({ isLoadingCatalog: true, lastCatalogError: null });

        const previous = {
          sources: get().sources,
          itemsBySource: get().itemsBySource,
        };

        let lastError: SkillsCatalogResponse['error'] | null = null;

        try {
          for (let attempt = 0; attempt < 3; attempt++) {
            try {
              const currentDirectory = getCurrentDirectory();
              const refresh = options?.refresh ? '&refresh=true' : '';
              const queryParams = currentDirectory
                ? `?directory=${encodeURIComponent(currentDirectory)}${refresh}`
                : refresh
                  ? `?refresh=true`
                  : '';

              const response = await fetch(`/api/config/skills/catalog${queryParams}`, {
                method: 'GET',
                headers: { Accept: 'application/json' },
              });

              const payload = (await response.json().catch(() => null)) as SkillsCatalogResponse | null;
              if (!response.ok || !payload?.ok) {
                lastError = payload?.error || { kind: 'unknown', message: `Failed to load catalog (${response.status})` };
                const waitMs = 200 * (attempt + 1);
                await new Promise((resolve) => setTimeout(resolve, waitMs));
                continue;
              }

          const sources = payload.sources || [];
          const itemsBySource = payload.itemsBySource || {};
          const currentSelected = get().selectedSourceId;
          const selectedSourceId =
            (currentSelected && sources.some((s) => s.id === currentSelected))
              ? currentSelected
              : (sources[0]?.id ?? null);

          set({ sources, itemsBySource, selectedSourceId });
          return true;

            } catch (error) {
              lastError = { kind: 'unknown', message: error instanceof Error ? error.message : String(error) };
              const waitMs = 200 * (attempt + 1);
              await new Promise((resolve) => setTimeout(resolve, waitMs));
            }
          }

          set({
            sources: previous.sources,
            itemsBySource: previous.itemsBySource,
            lastCatalogError: lastError || { kind: 'unknown', message: 'Failed to load catalog' },
          });

          return false;
        } finally {
          set({ isLoadingCatalog: false });
        }
      },

      scanRepo: async (request) => {
        set({ isScanning: true, lastScanError: null, scanResults: null });
        try {
          const currentDirectory = getCurrentDirectory();
          const queryParams = currentDirectory ? `?directory=${encodeURIComponent(currentDirectory)}` : '';

          const response = await fetch(`/api/config/skills/scan${queryParams}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
            body: JSON.stringify(request),
          });

          const payload = (await response.json().catch(() => null)) as SkillsRepoScanResponse | null;
          if (!response.ok || !payload) {
            const error = payload?.error || { kind: 'unknown', message: 'Failed to scan repository' };
            set({ lastScanError: error });
            return { ok: false, error };
          }

          if (!payload.ok) {
            set({ lastScanError: payload.error || { kind: 'unknown', message: 'Failed to scan repository' } });
            return payload;
          }

          set({ scanResults: payload.items || [] });
          return payload;
        } finally {
          set({ isScanning: false });
        }
      },

      installSkills: async (request) => {
        set({ isInstalling: true, lastInstallError: null });
        try {
          const currentDirectory = getCurrentDirectory();
          const queryParams = currentDirectory ? `?directory=${encodeURIComponent(currentDirectory)}` : '';

          const response = await fetch(`/api/config/skills/install${queryParams}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
            body: JSON.stringify(request),
          });

          const payload = (await response.json().catch(() => null)) as SkillsInstallResponse | null;
          if (!payload) {
            const error = { kind: 'unknown', message: 'Failed to install skills' } as SkillsInstallError;
            set({ lastInstallError: error });
            return { ok: false, error };
          }

          if (!response.ok || !payload.ok) {
            const error = payload.error || ({ kind: 'unknown', message: 'Failed to install skills' } as SkillsInstallError);
            set({ lastInstallError: error });
            return { ok: false, error };
          }

          // Refresh installed skills list.
          void useSkillsStore.getState().loadSkills();

          return payload;
        } catch (error) {
          const err = { kind: 'unknown', message: error instanceof Error ? error.message : String(error) } as SkillsInstallError;
          set({ lastInstallError: err });
          return { ok: false, error: err };
        } finally {
          set({ isInstalling: false });
        }
      },
    }),
    { name: 'skills-catalog-store' }
  )
);
