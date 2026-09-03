import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { describe, expect, test } from 'vitest';

import { isLegendTimelineExplicitlyEnabled } from '@/stores/useFeatureFlagsStore';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '../../../../..');

describe('chat list engine runtime default', () => {
  test('TanStack Virtual is the runtime default; LegendList is opt-in only', () => {
    expect(isLegendTimelineExplicitlyEnabled(null)).toBe(false);
    expect(isLegendTimelineExplicitlyEnabled('0')).toBe(false);
    expect(isLegendTimelineExplicitlyEnabled('')).toBe(false);
    expect(isLegendTimelineExplicitlyEnabled('1')).toBe(true);

    const flags = readFileSync(join(here, '../../stores/useFeatureFlagsStore.ts'), 'utf8');
    expect(flags).toContain("if (typeof localStorage === 'undefined') return false");
    expect(flags).toContain('isLegendTimelineExplicitlyEnabled');
    expect(flags).not.toContain('return localStorage.getItem(LEGEND_TIMELINE_STORAGE_KEY) !== \'0\'');

    const messageList = readFileSync(join(here, 'MessageList.tsx'), 'utf8');
    expect(messageList).toContain("import { elementScroll, useVirtualizer as useTanstackVirtualizer");
    expect(messageList).toContain("const historyEngine: HistoryEngine = shouldVirtualizeHistory ? 'tanstack' : 'none'");
    expect(messageList).toContain('if (legendTimelineEnabled)');
    expect(messageList).toContain('tanstackVirtualizerRef.current.scrollToEnd()');
    expect(messageList).not.toContain('use-stick-to-bottom');
    expect(messageList).not.toMatch(/from ['"]virtua['"]/);

    const chatContainer = readFileSync(join(here, 'ChatContainer.tsx'), 'utf8');
    expect(chatContainer).toContain('enabled: active && !legendTimelineEnabled');
    expect(chatContainer).toContain("scrollPhysics: () => (");
    expect(chatContainer).toContain("messageListRef.current?.isHistoryVirtualized() ? 'tanstack' : 'dom'");
  });

  test('pins the patched TanStack Virtual versions used by the default engine', () => {
    const uiPackage = JSON.parse(readFileSync(join(repoRoot, 'packages/ui/package.json'), 'utf8')) as {
      dependencies: Record<string, string>;
    };
    const rootPackage = JSON.parse(readFileSync(join(repoRoot, 'package.json'), 'utf8')) as {
      patchedDependencies: Record<string, string>;
    };
    const patch = readFileSync(join(repoRoot, 'patches/@tanstack%2Fvirtual-core@3.17.8.patch'), 'utf8');

    expect(uiPackage.dependencies['@tanstack/react-virtual']).toBe('3.14.10');
    expect(rootPackage.patchedDependencies['@tanstack/virtual-core@3.17.8']).toBe(
      'patches/@tanstack%2Fvirtual-core@3.17.8.patch',
    );
    expect(patch).toContain('const maxScrollOffset = Math.max(this.getTotalSize() - outerSize, 0)');
    expect(patch).toContain('const effectiveScrollOffset = Math.min(Math.max(scrollOffset, 0), maxScrollOffset)');
    expect(patch).toContain('effectiveScrollOffset');
  });
});
