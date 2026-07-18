import { describe, expect, test } from 'bun:test';
import {
  getMobileWindowMotionDismissCommitDistance,
  getMobileWindowMotionDismissDistance,
  getMobileWindowMotionDismissProgress,
  getMobileWindowMotionDismissVelocity,
  isMobileWindowMotionDismissIntent,
  isMobileWindowMotionDismissScrollBoundary,
  shouldCommitMobileWindowMotionDismiss,
} from './useMobileWindowMotionDismissGesture';

describe('MobileWindowMotion dismiss gesture', () => {
  test('accepts each edge direction and abandons reverse directions', () => {
    expect(getMobileWindowMotionDismissDistance('bottom', 0, 20)).toBe(20);
    expect(getMobileWindowMotionDismissDistance('top', 0, -20)).toBe(20);
    expect(getMobileWindowMotionDismissDistance('right', 20, 0)).toBe(20);
    expect(getMobileWindowMotionDismissDistance('left', -20, 0)).toBe(20);
    expect(isMobileWindowMotionDismissIntent('bottom', 0, -20, 8, 1)).toBe(false);
    expect(isMobileWindowMotionDismissIntent('top', 0, 20, 8, 1)).toBe(false);
    expect(isMobileWindowMotionDismissIntent('right', -20, 0, 8, 1)).toBe(false);
    expect(isMobileWindowMotionDismissIntent('left', 20, 0, 8, 1)).toBe(false);
  });

  test('applies the configured strict off-axis ratio', () => {
    expect(isMobileWindowMotionDismissIntent('right', 20, 20, 8, 1)).toBe(false);
    expect(isMobileWindowMotionDismissIntent('right', 20, 10, 8, 1)).toBe(true);
    expect(isMobileWindowMotionDismissIntent('right', 20, 30, 8, 2)).toBe(true);
    expect(isMobileWindowMotionDismissIntent('right', 20, 40, 8, 2)).toBe(false);
  });

  test('uses the matching scroll boundary for every edge', () => {
    const container = { scrollTop: 0.5, scrollLeft: 0.5, scrollHeight: 300, clientHeight: 100, scrollWidth: 300, clientWidth: 100 } as HTMLElement;
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'bottom')).toBe(true);
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'right')).toBe(true);
    container.scrollTop = 1.1;
    container.scrollLeft = 1.1;
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'bottom')).toBe(false);
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'right')).toBe(false);
    container.scrollTop = 199.5;
    container.scrollLeft = 199.5;
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'top')).toBe(true);
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'left')).toBe(true);
    container.scrollTop = 198.9;
    container.scrollLeft = 198.9;
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'top')).toBe(false);
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'left')).toBe(false);
  });

  test('uses the matching negative scrollLeft boundaries in RTL', () => {
    const container = {
      scrollTop: 0,
      scrollLeft: 0,
      scrollHeight: 300,
      clientHeight: 100,
      scrollWidth: 300,
      clientWidth: 100,
      matches: (selector: string) => selector === ':dir(rtl)',
    } as unknown as HTMLElement;
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'right')).toBe(true);
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'left')).toBe(false);
    container.scrollLeft = -199.5;
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'right')).toBe(false);
    expect(isMobileWindowMotionDismissScrollBoundary(container, 'left')).toBe(true);
  });

  test('keeps a recent move velocity through a stationary release frame', () => {
    expect(getMobileWindowMotionDismissVelocity(0.8, 0, 5, 5, 1)).toBe(0.8);
    expect(getMobileWindowMotionDismissVelocity(0.8, 0, 90, 90, 1)).toBe(0);
    expect(getMobileWindowMotionDismissVelocity(0.8, 16, 20, 20, -1)).toBe(-0.8);
  });

  test('maps motion progress to surface travel and clamps it', () => {
    expect(getMobileWindowMotionDismissProgress(120, 240)).toBe(0.5);
    expect(getMobileWindowMotionDismissProgress(480, 240)).toBe(1);
    expect(getMobileWindowMotionDismissProgress(-1, 240)).toBe(0);
  });

  test('commits by distance or fling and cancels short slow gestures', () => {
    const threshold = getMobileWindowMotionDismissCommitDistance(720, 0.1, 40, 64);
    expect(threshold).toBe(64);
    expect(shouldCommitMobileWindowMotionDismiss(64, 0, threshold, 0.65, 12)).toBe(true);
    expect(shouldCommitMobileWindowMotionDismiss(12, 0.65, threshold, 0.65, 12)).toBe(true);
    expect(shouldCommitMobileWindowMotionDismiss(11, 0.64, threshold, 0.65, 12)).toBe(false);
  });
});
