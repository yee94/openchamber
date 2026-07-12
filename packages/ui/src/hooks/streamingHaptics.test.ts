import { describe, expect, test } from 'bun:test';
import {
  evaluateHaptics,
  isCapacitorMobileNative,
  isCapacitorNativePlatform,
  type HapticsInput,
} from './streamingHaptics';

const baseInput = (overrides: Partial<HapticsInput> = {}): HapticsInput => ({
  eventSessionId: 'session-1',
  currentSessionId: 'session-1',
  isForeground: true,
  isVisible: true,
  ...overrides,
});

describe('streaming haptic platform checks', () => {
  test('returns false when window is undefined', () => {
    // @ts-expect-error testing SSR / undefined window
    globalThis.window = undefined;
    expect(isCapacitorNativePlatform()).toBe(false);
  });

  test('returns false outside the Capacitor shell', () => {
    expect(isCapacitorMobileNative()).toBe(false);
  });
});

describe('evaluateHaptics', () => {
  test('fires for a visible update in the current foreground session', () => {
    expect(evaluateHaptics(baseInput())).toEqual({ shouldTrigger: true, reason: 'trigger' });
  });

  test('skips updates from another session', () => {
    expect(evaluateHaptics(baseInput({ eventSessionId: 'session-2' })).reason).toBe('different-session');
  });

  test('skips updates while backgrounded or hidden', () => {
    expect(evaluateHaptics(baseInput({ isForeground: false })).reason).toBe('background');
    expect(evaluateHaptics(baseInput({ isVisible: false })).reason).toBe('hidden');
  });
});
