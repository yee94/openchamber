import { useTerminalStore } from '@/stores/useTerminalStore';
import { useUIStore } from '@/stores/useUIStore';

export const createAndActivateTerminalTab = (directory: string): string | null => {
  const key = directory.trim();
  if (!key) {
    return null;
  }

  const store = useTerminalStore.getState();
  const tabId = store.createTab(key);
  if (!tabId || tabId === 'tab-invalid') {
    return null;
  }

  store.setActiveTab(key, tabId);
  return tabId;
};

/** Open the bottom terminal dock if needed, then create and focus a new tab. */
export const openAndCreateTerminalTab = (directory: string): string | null => {
  const key = directory.trim();
  if (!key) {
    return null;
  }

  const uiState = useUIStore.getState();
  if (!uiState.isBottomTerminalOpen && uiState.activeMainTab !== 'terminal') {
    uiState.setBottomTerminalOpen(true);
  }

  return createAndActivateTerminalTab(key);
};

export const switchTerminalTab = (directory: string, direction: -1 | 1): boolean => {
  const key = directory.trim();
  if (!key) {
    return false;
  }

  const store = useTerminalStore.getState();
  const directoryState = store.getDirectoryState(key);
  if (!directoryState || directoryState.tabs.length < 2) {
    return false;
  }

  const currentIndex = directoryState.tabs.findIndex((tab) => tab.id === directoryState.activeTabId);
  const safeIndex = currentIndex >= 0 ? currentIndex : 0;
  const nextIndex = (safeIndex + direction + directoryState.tabs.length) % directoryState.tabs.length;
  const nextTabId = directoryState.tabs[nextIndex]?.id;
  if (!nextTabId || nextTabId === directoryState.activeTabId) {
    return false;
  }

  store.setActiveTab(key, nextTabId);
  return true;
};

export const closeActiveTerminalTab = (directory: string): {
  closed: boolean;
  wasLastTab: boolean;
} => {
  const key = directory.trim();
  if (!key) {
    return { closed: false, wasLastTab: false };
  }

  const store = useTerminalStore.getState();
  const directoryState = store.getDirectoryState(key);
  const activeTabId = directoryState?.activeTabId ?? null;
  if (!directoryState || !activeTabId) {
    return { closed: false, wasLastTab: false };
  }

  const wasLastTab = directoryState.tabs.length === 1;
  void store.closeTab(key, activeTabId);
  return { closed: true, wasLastTab };
};
