import { describe, expect, test } from 'bun:test';
import {
  createHeaderSwipeGestureState,
  evaluateHeaderSwipe,
  updateHeaderSwipeGestureState,
} from './useHeaderSwipeToSessions';

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
  // Happy path: clean rightward swipe across the open threshold
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
  // 35%-viewport threshold
  // -----------------------------------------------------------------------
  test('rejects swipe below the open threshold', () => {
    expect(evaluateHeaderSwipe(base({ startX: 100, endX: 162, viewportWidth: 180 })).open).toBe(false);
  });

  test('accepts swipe exactly at the open threshold', () => {
    expect(evaluateHeaderSwipe(base({ startX: 100, endX: 163, viewportWidth: 180 })).open).toBe(true);
  });

  test('accepts swipe beyond the open threshold', () => {
    expect(evaluateHeaderSwipe(base({ startX: 100, endX: 164, viewportWidth: 180 })).open).toBe(true);
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

describe('updateHeaderSwipeGestureState', () => {
  const viewportWidth = 200;

  const update = (
    state: ReturnType<typeof createHeaderSwipeGestureState>,
    clientX: number,
    clientY = 0,
  ) => updateHeaderSwipeGestureState(state, { clientX, clientY }, viewportWidth);

  test('reopens after a rightward candidate is cancelled by leftward travel', () => {
    let state = createHeaderSwipeGestureState({ clientX: 0, clientY: 0 });
    state = update(state, 101);
    expect(state.open).toBe(true);
    state = update(state, 0);
    expect(state.open).toBe(false);
    state = update(state, 101);
    expect(state.open).toBe(true);
  });

  test('keeps the candidate cancelled after a final leftward segment', () => {
    let state = createHeaderSwipeGestureState({ clientX: 0, clientY: 0 });
    state = update(state, 101);
    state = update(state, 0);

    expect(state.open).toBe(false);
  });

  test('keeps the candidate open through a small release-direction jitter', () => {
    let state = createHeaderSwipeGestureState({ clientX: 0, clientY: 0 });
    state = update(state, 101);
    state = update(state, 100);

    expect(state.open).toBe(true);
    expect(state.segmentStart.clientX).toBe(0);
  });

  test('cancels after a deliberate reversal reaches the intent distance', () => {
    let state = createHeaderSwipeGestureState({ clientX: 0, clientY: 0 });
    state = update(state, 101);
    state = update(state, 94);
    expect(state.open).toBe(true);
    state = update(state, 93);

    expect(state.open).toBe(false);
    expect(state.segmentStart.clientX).toBe(101);
  });

  test('anchors a reversed segment at the local turning point', () => {
    let state = createHeaderSwipeGestureState({ clientX: 100, clientY: 0 });
    state = update(state, 220);
    state = update(state, 180);
    state = update(state, 281);

    expect(state.segmentStart.clientX).toBe(180);
    expect(state.open).toBe(true);
  });

  test('keeps the candidate unchanged for an off-axis segment', () => {
    let state = createHeaderSwipeGestureState({ clientX: 0, clientY: 0 });
    state = update(state, 101);
    state = update(state, 0);
    state = update(state, 101, 60);

    expect(state.open).toBe(false);
  });
});
