import { describe, expect, test } from 'bun:test';
import { evaluateSwipeDirection } from './useEdgeSwipeSessionSwitch';

import type { SwipeDirectionInput } from './useEdgeSwipeSessionSwitch';

/**
 * Pure-function tests for evaluateSwipeDirection.
 *
 * The DOM-dependent part of the hook (touch listeners, interactive-target /
 * scrollable-ancestor detection) exercises touch-event patterns that are
 * verified through component-level smoke on device. These tests cover every
 * geometric gate: axis selection, minimum distance, off-axis ratio, and
 * direction mapping for horizontal swipes.
 */

const baseSwipe = (
  overrides: Partial<SwipeDirectionInput> = {},
): SwipeDirectionInput => ({
  startX: 200,
  startY: 300,
  endX: 200,
  endY: 300,
  ...overrides,
});

describe('evaluateSwipeDirection', () => {
  // -----------------------------------------------------------------------
  // Horizontal: left swipe → next
  // -----------------------------------------------------------------------
  test('left swipe maps to next', () => {
    expect(evaluateSwipeDirection(baseSwipe({ endX: 100, endY: 303 }))).toBe('next');
    // dx = -100, absDx = 100 > 64
  });

  test('left swipe exactly at min distance maps to next', () => {
    // sx = 264, ex = 200, dx = -64
    expect(evaluateSwipeDirection(baseSwipe({ startX: 264, endX: 200, endY: 302 }))).toBe('next');
  });

  // -----------------------------------------------------------------------
  // Horizontal: right swipe → prev
  // -----------------------------------------------------------------------
  test('right swipe maps to prev', () => {
    expect(evaluateSwipeDirection(baseSwipe({ endX: 300, endY: 303 }))).toBe('prev');
    // dx = 100, absDx = 100 > 64
  });

  test('right swipe exactly at min distance maps to prev', () => {
    expect(evaluateSwipeDirection(baseSwipe({ startX: 200, endX: 264, endY: 302 }))).toBe('prev');
  });

  // -----------------------------------------------------------------------
  // Vertical gestures are reserved for composer expansion and page scrolling.
  // -----------------------------------------------------------------------
  test('up swipe is ignored', () => {
    expect(evaluateSwipeDirection(baseSwipe({ endX: 203, endY: 200 }))).toBe(null);
  });

  test('up swipe exactly at horizontal min distance is ignored', () => {
    expect(evaluateSwipeDirection(baseSwipe({ startY: 364, endY: 300, endX: 202 }))).toBe(null);
  });

  // -----------------------------------------------------------------------
  // Vertical: down is ignored
  // -----------------------------------------------------------------------
  test('down swipe is ignored', () => {
    expect(evaluateSwipeDirection(baseSwipe({ endX: 203, endY: 400 }))).toBe(null);
  });

  test('down swipe exactly at horizontal min distance is ignored', () => {
    expect(evaluateSwipeDirection(baseSwipe({ startY: 300, endY: 364, endX: 202 }))).toBe(null);
  });

  // -----------------------------------------------------------------------
  // Axis selection: horizontal wins when |dx| >= |dy|
  // -----------------------------------------------------------------------
  test('horizontal wins when dx dominates and off-axis within tolerance', () => {
    // dx = -110, dy = -60 → absDx=110, absDy=60, off-axis=60/110≈0.545 < 0.6, left → next
    expect(evaluateSwipeDirection(baseSwipe({ endX: 90, endY: 240 }))).toBe('next');
  });

  test('horizontal wins when dx is slightly larger', () => {
    // dx = -100, dy = -55 → absDx=100, absDy=55, off-axis=55/100=0.55 < 0.6, left → next
    expect(evaluateSwipeDirection(baseSwipe({ endX: 100, endY: 245 }))).toBe('next');
  });

  // -----------------------------------------------------------------------
  // Vertical-dominant gestures are ignored
  // -----------------------------------------------------------------------
  test('ignores vertical-dominant upward movement', () => {
    expect(evaluateSwipeDirection(baseSwipe({ endX: 140, endY: 200 }))).toBe(null);
  });

  test('ignores vertical-dominant downward movement', () => {
    expect(evaluateSwipeDirection(baseSwipe({ endX: 210, endY: 450 }))).toBe(null);
  });

  // -----------------------------------------------------------------------
  // Minimum distance: below threshold → null
  // -----------------------------------------------------------------------
  test('returns null when horizontal travel below min distance', () => {
    // dx = -63, dy = 5
    expect(evaluateSwipeDirection(baseSwipe({ endX: 137, endY: 302 }))).toBe(null);
  });

  test('returns null when vertical travel below min distance', () => {
    // dx = 2, dy = -63
    expect(evaluateSwipeDirection(baseSwipe({ endX: 201, endY: 237 }))).toBe(null);
  });

  test('returns null when no movement', () => {
    expect(evaluateSwipeDirection(baseSwipe())).toBe(null);
  });

  // -----------------------------------------------------------------------
  // Off-axis tolerance: horizontal
  // -----------------------------------------------------------------------
  test('horizontal swipe rejected when off-axis ratio exceeds limit', () => {
    // dx = -100, dy = 65 → |dy|/|dx| = 0.65 > 0.6
    expect(evaluateSwipeDirection(baseSwipe({ endX: 100, endY: 365 }))).toBe(null);
  });

  test('horizontal swipe accepted when off-axis within tolerance', () => {
    // dx = -100, dy = 59 → |dy|/|dx| = 0.59 < 0.6
    expect(evaluateSwipeDirection(baseSwipe({ endX: 100, endY: 359 }))).toBe('next');
  });

  // -----------------------------------------------------------------------
  // Off-axis tolerance: vertical
  // -----------------------------------------------------------------------
  test('vertical swipe rejected when off-axis ratio exceeds limit', () => {
    // dx = 65, dy = -100 → |dx|/|dy| = 0.65 > 0.6
    expect(evaluateSwipeDirection(baseSwipe({ endX: 265, endY: 200 }))).toBe(null);
  });

  test('vertical swipe within the old tolerance is ignored', () => {
    expect(evaluateSwipeDirection(baseSwipe({ endX: 259, endY: 200 }))).toBe(null);
  });
});
