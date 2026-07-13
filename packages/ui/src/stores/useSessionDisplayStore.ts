import { create } from 'zustand';
import { persist } from 'zustand/middleware';

type SessionDisplayMode = 'default' | 'minimal';

type ProjectSortOrder = 'manual' | 'a-z' | 'z-a' | 'date-added' | 'recent';

type SessionDisplayStore = {
  displayMode: SessionDisplayMode;
  showArchivedSessions: boolean;
  projectSortOrder: ProjectSortOrder;
  setDisplayMode: (mode: SessionDisplayMode) => void;
  setShowArchivedSessions: (show: boolean) => void;
  toggleArchivedSessions: () => void;
  setProjectSortOrder: (order: ProjectSortOrder) => void;
};

export const useSessionDisplayStore = create<SessionDisplayStore>()(
  persist(
    (set) => ({
      displayMode: 'minimal',
      // Default to HIDDEN so the pre-hydration state matches the quiet/safe
      // option: archived sessions must never flash visible on startup and then
      // disappear once the persisted preference rehydrates. Users who opted into
      // showing archived have `true` persisted, which is preserved on rehydrate.
      showArchivedSessions: false,
      projectSortOrder: 'manual',
      setDisplayMode: (mode) => set({ displayMode: mode }),
      setShowArchivedSessions: (show) => set({ showArchivedSessions: show }),
      toggleArchivedSessions: () => set((state) => ({ showArchivedSessions: !state.showArchivedSessions })),
      setProjectSortOrder: (order) => set({ projectSortOrder: order }),
    }),
    {
      name: 'session-display-mode',
      version: 3,
      // v0 shipped 'default' as the only/initial mode, so most existing users
      // have it persisted by accident rather than choice. Nudge everyone onto
      // minimal once so the mode can be evaluated before removing it entirely.
      // v1→v2 adds projectSortOrder defaulting to 'recent'.
      migrate: (persisted, version) => {
        const state = (persisted ?? {}) as Partial<SessionDisplayStore>;
        if (version < 1) {
          return { ...state, displayMode: 'minimal', projectSortOrder: 'manual' };
        }
        if (version < 2) {
          return { ...state, projectSortOrder: 'manual' };
        }
        if (version < 3) {
          return { ...state, projectSortOrder: 'manual' };
        }
        return state;
      },
    },
  ),
);

export type { ProjectSortOrder };
