import { describe, expect, test } from 'bun:test';
import { evaluateSwipeToSessions } from './useContentSwipeToSessions';

import type { SwipeToSessionsInput } from './useContentSwipeToSessions';

/**
 * Focused pure-function tests for evaluateSwipeToSessions.
 *
 * The DOM-dependent part of the hook (touch listeners, interactive-target
 * detection) exercises the same pattern as useEdgeSwipeSessionSwitch and is
 * verified through component-level smoke on device. These tests cover every
 * geometric gate, edge-zone exclusion, direction, and disabled-bypass rule.
 */

const base = (
  overrides: Partial<SwipeToSessionsInput> = {},
): SwipeToSessionsInput => ({
  startX: 200,
  startY: 300,
  endX: 100,
  endY: 310,
  containerWidth: 400,
  disabled: false,
  startedOnInteractive: false,
  ...overrides,
});

describe('evaluateSwipeToSessions', () => {
  // -----------------------------------------------------------------------
  // Happy path: clean leftward swipe
  // -----------------------------------------------------------------------
  test('opens on clean content-area leftward swipe', () => {
    expect(evaluateSwipeToSessions(base()).open).toBe(true);
  });

  // -----------------------------------------------------------------------
  // Edge exclusion
  // -----------------------------------------------------------------------
  test('rejects swipe starting at left edge (<= 32px)', () => {
    expect(evaluateSwipeToSessions(base({ startX: 32 })).open).toBe(false);
    expect(evaluateSwipeToSessions(base({ startX: 0 })).open).toBe(false);
    expect(evaluateSwipeToSessions(base({ startX: 10 })).open).toBe(false);
  });

  test('rejects swipe starting at right edge (>= containerWidth - 32px)', () => {
    expect(evaluateSwipeToSessions(base({ startX: 400 - 32, containerWidth: 400 })).open).toBe(false);
    expect(evaluateSwipeToSessions(base({ startX: 400, containerWidth: 400 })).open).toBe(false);
    expect(evaluateSwipeToSessions(base({ startX: 390, containerWidth: 400 })).open).toBe(false);
  });

  test('accepts swipe starting just inside right edge (< containerWidth - 32px)', () => {
    expect(evaluateSwipeToSessions(base({ startX: 400 - 33, containerWidth: 400 })).open).toBe(true);
  });

  test('accepts swipe starting in the middle of the container', () => {
    expect(evaluateSwipeToSessions(base({ startX: 200, endX: 100, containerWidth: 400 })).open).toBe(true);
  });

  // -----------------------------------------------------------------------
  // Direction: must be right-to-left (dx < 0)
  // -----------------------------------------------------------------------
  test('rejects rightward swipe (left-to-right)', () => {
    expect(evaluateSwipeToSessions(base({ startX: 100, endX: 200 })).open).toBe(false);
    expect(evaluateSwipeToSessions(base({ startX: 200, endX: 210 })).open).toBe(false);
  });

  test('rejects stationary touch (no horizontal movement)', () => {
    expect(evaluateSwipeToSessions(base({ startX: 200, endX: 200 })).open).toBe(false);
  });

  // -----------------------------------------------------------------------
  // Minimum distance
  // -----------------------------------------------------------------------
  test('rejects swipe below minimum distance', () => {
    expect(evaluateSwipeToSessions(base({ startX: 200, endX: 129 })).open).toBe(false);
    // dx = -71 < 72
  });

  test('accepts swipe exactly at minimum distance', () => {
    expect(evaluateSwipeToSessions(base({ startX: 200, endX: 128 })).open).toBe(true);
    // dx = -72
  });

  test('accepts swipe well above minimum distance', () => {
    expect(evaluateSwipeToSessions(base({ startX: 300, endX: 100 })).open).toBe(true);
    // dx = -200
  });

  // -----------------------------------------------------------------------
  // Off-axis (vertical) rejection
  // -----------------------------------------------------------------------
  test('rejects primarily vertical swipe', () => {
    expect(evaluateSwipeToSessions(base({ startX: 200, startY: 300, endX: 100, endY: 100 })).open).toBe(false);
    // dx = -100, dy = -200, |dy|/|dx| = 2.0 > 0.55
  });

  test('rejects diagonal with strong vertical component', () => {
    // dx = -100, dy = -60, |60/100| = 0.6 > 0.55
    expect(evaluateSwipeToSessions(base({ startX: 200, startY: 300, endX: 100, endY: 240 })).open).toBe(false);
  });

  test('accepts mildly diagonal swipe within off-axis tolerance', () => {
    // dx = -200, dy = -80, |80/200| = 0.4 < 0.55
    expect(evaluateSwipeToSessions(base({ startX: 300, startY: 300, endX: 100, endY: 220 })).open).toBe(true);
  });

  // -----------------------------------------------------------------------
  // Disabled gate
  // -----------------------------------------------------------------------
  test('rejects when disabled', () => {
    expect(evaluateSwipeToSessions(base({ disabled: true })).open).toBe(false);
  });

  // -----------------------------------------------------------------------
  // Interactive target gate
  // -----------------------------------------------------------------------
  test('rejects when started on interactive element', () => {
    expect(evaluateSwipeToSessions(base({ startedOnInteractive: true })).open).toBe(false);
  });
});
