import { describe, expect, test } from 'bun:test';
import { evaluateHeaderSwipe } from './useHeaderSwipeToSessions';

import type { HeaderSwipeInput } from './useHeaderSwipeToSessions';

/**
 * Pure-function tests for evaluateHeaderSwipe.
 *
 * The DOM-dependent part of the hook (touch listeners, interactive-target
 * detection) exercises touch-event patterns that are verified through
 * component-level smoke on device. These tests cover every geometric
 * gate: direction, minimum distance, off-axis ratio, and disabled /
 * interactive bypass rules.
 */

const base = (
  overrides: Partial<HeaderSwipeInput> = {},
): HeaderSwipeInput => ({
  startX: 100,
  startY: 30,
  endX: 200,
  endY: 35,
  disabled: false,
  startedOnInteractive: false,
  ...overrides,
});

describe('evaluateHeaderSwipe', () => {
  // -----------------------------------------------------------------------
  // Happy path: clean rightward swipe on header
  // -----------------------------------------------------------------------
  test('opens on clean horizontal rightward swipe', () => {
    expect(evaluateHeaderSwipe(base()).open).toBe(true);
  });

  // -----------------------------------------------------------------------
  // Direction: must be left-to-right (dx > 0)
  // -----------------------------------------------------------------------
  test('rejects leftward swipe (right-to-left)', () => {
    expect(evaluateHeaderSwipe(base({ startX: 200, endX: 100 })).open).toBe(false);
    expect(evaluateHeaderSwipe(base({ startX: 200, endX: 190 })).open).toBe(false);
  });

  test('rejects stationary touch (no horizontal movement)', () => {
    expect(evaluateHeaderSwipe(base({ startX: 200, endX: 200 })).open).toBe(false);
  });

  // -----------------------------------------------------------------------
  // Minimum distance
  // -----------------------------------------------------------------------
  test('rejects swipe below minimum distance', () => {
    // dx = 71 < 72
    expect(evaluateHeaderSwipe(base({ startX: 100, endX: 171 })).open).toBe(false);
  });

  test('accepts swipe exactly at minimum distance', () => {
    // dx = 72
    expect(evaluateHeaderSwipe(base({ startX: 100, endX: 172 })).open).toBe(true);
  });

  test('accepts swipe well above minimum distance', () => {
    // dx = 200
    expect(evaluateHeaderSwipe(base({ startX: 100, endX: 300 })).open).toBe(true);
  });

  // -----------------------------------------------------------------------
  // Off-axis (vertical) rejection
  // -----------------------------------------------------------------------
  test('rejects primarily vertical swipe', () => {
    // dx = 100, dy = -200, |dy|/|dx| = 2.0 > 0.55
    expect(evaluateHeaderSwipe(base({ startX: 100, startY: 200, endX: 200, endY: 0 })).open).toBe(false);
  });

  test('rejects diagonal with strong vertical component', () => {
    // dx = 100, dy = -60, |60/100| = 0.6 > 0.55
    expect(evaluateHeaderSwipe(base({ startX: 100, startY: 100, endX: 200, endY: 40 })).open).toBe(false);
  });

  test('accepts mildly diagonal swipe within off-axis tolerance', () => {
    // dx = 200, dy = -80, |80/200| = 0.4 < 0.55
    expect(evaluateHeaderSwipe(base({ startX: 100, startY: 100, endX: 300, endY: 20 })).open).toBe(true);
  });

  // -----------------------------------------------------------------------
  // Disabled gate
  // -----------------------------------------------------------------------
  test('rejects when disabled', () => {
    expect(evaluateHeaderSwipe(base({ disabled: true })).open).toBe(false);
  });

  // -----------------------------------------------------------------------
  // Interactive target gate
  // -----------------------------------------------------------------------
  test('rejects when started on interactive element', () => {
    expect(evaluateHeaderSwipe(base({ startedOnInteractive: true })).open).toBe(false);
  });
});
