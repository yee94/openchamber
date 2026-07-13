import { beforeEach, describe, expect, test } from 'bun:test';
import { useUIStore } from './useUIStore';

beforeEach(() => {
  useUIStore.setState({
    contextPanelByDirectory: {},
    contextPanelsOpenBeforeRightSidebarCollapse: [],
    isRightSidebarOpen: false,
  });
});

describe('useUIStore context panel tabs', () => {
  test('updates readOnly when an existing chat tab is reopened', () => {
    const directory = '/repo';

    useUIStore.getState().openContextPanelTab(directory, {
      mode: 'chat',
      dedupeKey: 'session:ses_1',
      label: 'Session',
      readOnly: true,
    });

    useUIStore.getState().openContextPanelTab(directory, {
      mode: 'chat',
      dedupeKey: 'session:ses_1',
      label: 'Session',
      readOnly: false,
    });

    const tabs = useUIStore.getState().contextPanelByDirectory[directory]?.tabs ?? [];
    expect(tabs).toHaveLength(1);
    expect(tabs[0]?.readOnly).toBe(false);
  });

  test('closeActiveContextPanelTab closes the active tab and shuts the panel when empty', () => {
    const directory = '/repo';

    useUIStore.getState().openContextPanelTab(directory, { mode: 'context' });
    useUIStore.getState().openContextPanelTab(directory, {
      mode: 'file',
      targetPath: '/repo/install.sh',
    });

    const before = useUIStore.getState().contextPanelByDirectory[directory];
    expect(before?.isOpen).toBe(true);
    expect(before?.tabs).toHaveLength(2);

    const closedFirst = useUIStore.getState().closeActiveContextPanelTab(directory);
    expect(closedFirst).toBe(true);
    expect(useUIStore.getState().contextPanelByDirectory[directory]?.tabs).toHaveLength(1);
    expect(useUIStore.getState().contextPanelByDirectory[directory]?.isOpen).toBe(true);

    const closedLast = useUIStore.getState().closeActiveContextPanelTab(directory);
    expect(closedLast).toBe(true);
    const after = useUIStore.getState().contextPanelByDirectory[directory];
    expect(after?.tabs).toHaveLength(0);
    expect(after?.isOpen).toBe(false);

    expect(useUIStore.getState().closeActiveContextPanelTab(directory)).toBe(false);
  });

  test('toggles open context panels with the right sidebar and restores them', () => {
    const firstDirectory = '/repo-one';
    const secondDirectory = '/repo-two';
    const store = useUIStore.getState();

    store.openContextPanelTab(firstDirectory, { mode: 'context' });
    store.openContextPanelTab(secondDirectory, { mode: 'plan' });
    store.toggleRightSidebar();

    expect(useUIStore.getState().isRightSidebarOpen).toBe(true);
    store.toggleRightSidebar();

    expect(useUIStore.getState().isRightSidebarOpen).toBe(false);
    expect(useUIStore.getState().contextPanelByDirectory[firstDirectory]?.isOpen).toBe(false);
    expect(useUIStore.getState().contextPanelByDirectory[secondDirectory]?.isOpen).toBe(false);

    store.toggleRightSidebar();

    expect(useUIStore.getState().contextPanelByDirectory[firstDirectory]?.isOpen).toBe(true);
    expect(useUIStore.getState().contextPanelByDirectory[secondDirectory]?.isOpen).toBe(true);
  });
});
