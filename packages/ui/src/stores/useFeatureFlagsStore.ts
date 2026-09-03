import { create } from 'zustand';

// This 1.18 TanStack branch keeps @tanstack/react-virtual as the runtime
// default chat list. Main's LegendList / TimelineList path remains available
// only as an explicit opt-in: set `oc:legend-timeline` to `1` and refresh.
// Do not treat LegendList, StickToBottom, or Virtua as the default here.
const LEGEND_TIMELINE_STORAGE_KEY = 'oc:legend-timeline';

export const isLegendTimelineExplicitlyEnabled = (stored: string | null): boolean => (
  stored === '1'
);

const readLegendTimelineEnabled = (): boolean => {
  try {
    if (typeof localStorage === 'undefined') return false;
    return isLegendTimelineExplicitlyEnabled(localStorage.getItem(LEGEND_TIMELINE_STORAGE_KEY));
  } catch {
    return false;
  }
};

type FeatureFlagsStore = {
  legendTimelineEnabled: boolean;
  setLegendTimelineEnabled: (enabled: boolean) => void;
};

export const useFeatureFlagsStore = create<FeatureFlagsStore>((set) => ({
  legendTimelineEnabled: readLegendTimelineEnabled(),
  setLegendTimelineEnabled: (enabled) => {
    try {
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem(LEGEND_TIMELINE_STORAGE_KEY, enabled ? '1' : '0');
      }
    } catch {
      // Persisting the choice is best-effort; the in-memory flag still applies.
    }
    set({ legendTimelineEnabled: enabled });
  },
}));
