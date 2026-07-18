import { describe, expect, test } from 'bun:test';

import { resolveDirectoryExplorerMobileLayout } from './directoryExplorerLayout';

describe('DirectoryExplorerDialog mobile layout', () => {
  test('uses device detection when forceMobile is undefined', () => {
    expect(resolveDirectoryExplorerMobileLayout(undefined, true)).toBe(true);
    expect(resolveDirectoryExplorerMobileLayout(undefined, false)).toBe(false);
  });

  test('uses forceMobile when supplied', () => {
    expect(resolveDirectoryExplorerMobileLayout(true, false)).toBe(true);
    expect(resolveDirectoryExplorerMobileLayout(false, true)).toBe(false);
  });
});
