import { describe, expect, test } from 'bun:test';

import {
  clampMobileWindowMotionProgress,
  getMobileWindowMotionFrame,
  getMobileWindowMotionControlledTarget,
  getMobileWindowMotionOperationTarget,
  getMobileWindowMotionSurfaceLayout,
  getMobileWindowMotionVisibleProgress,
} from './MobileWindowMotionRecipe';

describe('MobileWindowMotion recipe', () => {
  test('maps every edge to its closed transform', () => {
    expect(getMobileWindowMotionFrame('left', 0).surfaceTransform).toBe('translate3d(-100%, 0, 0)');
    expect(getMobileWindowMotionFrame('right', 0).surfaceTransform).toBe('translate3d(100%, 0, 0)');
    expect(getMobileWindowMotionFrame('top', 0).surfaceTransform).toBe('translate3d(0, -100%, 0)');
    expect(getMobileWindowMotionFrame('bottom', 0).surfaceTransform).toBe('translate3d(0, 100%, 0)');
  });

  test('clamps progress and derives compositor opacity', () => {
    expect(clampMobileWindowMotionProgress(-2)).toBe(0);
    expect(clampMobileWindowMotionProgress(2)).toBe(1);
    const frame = getMobileWindowMotionFrame('bottom', 0.5);
    expect(frame.progress).toBe(0.5);
    expect(frame.scrimOpacity).toBe(0.5);
    expect(frame.surfaceOpacity).toBe(0.5);
    expect(frame.surfaceTransform).toBe('translate3d(0, 50%, 0)');
  });

  test('maps present commit to the visible endpoint', () => {
    expect(getMobileWindowMotionOperationTarget('present', 'commit')).toBe(1);
  });

  test('maps present cancel to the hidden endpoint', () => {
    expect(getMobileWindowMotionOperationTarget('present', 'cancel')).toBe(0);
  });

  test('maps dismiss commit to the hidden endpoint', () => {
    expect(getMobileWindowMotionOperationTarget('dismiss', 'commit')).toBe(0);
  });

  test('maps dismiss cancel to the visible endpoint', () => {
    expect(getMobileWindowMotionOperationTarget('dismiss', 'cancel')).toBe(1);
  });

  test('maps operation progress to visible progress', () => {
    expect(getMobileWindowMotionVisibleProgress('present', 0.25)).toBe(0.25);
    expect(getMobileWindowMotionVisibleProgress('dismiss', 0.25)).toBe(0.75);
  });

  test('maps controlled state to its visual endpoint', () => {
    expect(getMobileWindowMotionControlledTarget(true)).toBe(1);
    expect(getMobileWindowMotionControlledTarget(false)).toBe(0);
  });

  test('maps every sheet edge to its anchored layout', () => {
    expect(getMobileWindowMotionSurfaceLayout('sheet', 'bottom')).toContain('mt-auto');
    expect(getMobileWindowMotionSurfaceLayout('sheet', 'bottom')).toContain('mx-auto');
    expect(getMobileWindowMotionSurfaceLayout('sheet', 'bottom')).toContain('pwa-overlay-panel');
    expect(getMobileWindowMotionSurfaceLayout('sheet', 'top')).toContain('mb-auto');
    expect(getMobileWindowMotionSurfaceLayout('sheet', 'top')).toContain('mx-auto');
    expect(getMobileWindowMotionSurfaceLayout('sheet', 'left')).toContain('rounded-r-xl');
    expect(getMobileWindowMotionSurfaceLayout('sheet', 'right')).toContain('rounded-l-xl');
    for (const edge of ['left', 'right', 'top', 'bottom'] as const) {
      const layout = getMobileWindowMotionSurfaceLayout('page', edge);
      expect(layout).toContain('flex min-h-0 flex-col bg-background shadow-none');
      expect(layout).toContain('h-full w-full');
      expect(layout).not.toContain('pwa-overlay-panel');
    }
  });
});
