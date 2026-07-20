import { describe, expect, test } from 'bun:test';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const titlebarSource = readFileSync(join(__dirname, '..', 'TitlebarLeftControls.tsx'), 'utf-8');
const sessionSidebarSource = readFileSync(join(__dirname, '..', '..', 'session', 'SessionSidebar.tsx'), 'utf-8');

describe('Electron global search placement', () => {
  test('renders global search beside the sidebar brand', () => {
    const topContentIndex = sessionSidebarSource.indexOf('const topContent =');
    expect(topContentIndex).toBeGreaterThan(-1);

    const topContentSource = sessionSidebarSource.slice(topContentIndex, topContentIndex + 1_200);
    const brandIndex = topContentSource.indexOf('<SidebarBrandMark className="min-w-0 flex-1" />');
    const searchIndex = topContentSource.indexOf('<GlobalSearchButton className="ml-auto shrink-0" />');

    expect(topContentSource).toContain('<div className="flex items-center justify-between">');
    expect(brandIndex).toBeGreaterThan(-1);
    expect(searchIndex).toBeGreaterThan(brandIndex);
    expect(searchIndex - brandIndex).toBeLessThan(200);
  });

  test('keeps the titlebar trigger available while the Electron sidebar is collapsed', () => {
    expect(titlebarSource).toContain(
      'const showGlobalSearchInTitlebar = !isDesktopShellRuntime || !isSidebarOpen;',
    );
    expect(titlebarSource).toContain(
      '{showGlobalSearchInTitlebar ? <GlobalSearchButton /> : null}',
    );
  });
});
