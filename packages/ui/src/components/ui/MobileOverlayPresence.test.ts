import { describe, expect, test } from 'bun:test';

import { hasActiveMobileOverlay, MOBILE_OVERLAY_ACTIVE_ATTRIBUTE } from './MobileOverlayPresence';

const overlay = (active?: boolean) => ({
  getAttribute: (name: string) => name === MOBILE_OVERLAY_ACTIVE_ATTRIBUTE && active !== undefined
    ? String(active)
    : null,
});

describe('mobile overlay presence', () => {
  test('treats ordinary mounted overlays as active', () => {
    expect(hasActiveMobileOverlay([overlay()])).toBe(true);
  });

  test('ignores retained inactive overlays', () => {
    expect(hasActiveMobileOverlay([overlay(false)])).toBe(false);
  });

  test('stays active when another overlay is visible', () => {
    expect(hasActiveMobileOverlay([overlay(false), overlay(true)])).toBe(true);
  });
});
