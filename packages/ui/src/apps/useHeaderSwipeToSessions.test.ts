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
  viewportWidth: 180,
  disabled: false,
  startedOnExcludedTarget: false,
  ...overrides,
});

describe('evaluateHeaderSwipe', () => {
  // -----------------------------------------------------------------------
  // Happy path: clean rightward swipe across more than half the viewport
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
  // Half-viewport threshold
  // -----------------------------------------------------------------------
  test('rejects swipe below half the viewport', () => {
    expect(evaluateHeaderSwipe(base({ startX: 100, endX: 189, viewportWidth: 180 })).open).toBe(false);
  });

  test('accepts swipe exactly at half the viewport', () => {
    expect(evaluateHeaderSwipe(base({ startX: 100, endX: 190, viewportWidth: 180 })).open).toBe(true);
  });

  test('accepts swipe beyond half the viewport', () => {
    expect(evaluateHeaderSwipe(base({ startX: 100, endX: 191, viewportWidth: 180 })).open).toBe(true);
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
  test('rejects when started on an excluded target', () => {
    expect(evaluateHeaderSwipe(base({ startedOnExcludedTarget: true })).open).toBe(false);
  });
});
