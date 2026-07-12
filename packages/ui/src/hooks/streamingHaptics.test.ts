import { describe, expect, test } from 'bun:test';
import {
  evaluateHaptics,
  INITIAL_HAPTICS_STATE,
  isCapacitorMobileNative,
  isCapacitorNativePlatform,
  type HapticsInput,
  type HapticsState,
} from './streamingHaptics';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const baseInput = (overrides: Partial<HapticsInput> = {}): HapticsInput => ({
  streamingMsgId: 'msg_1',
  streamState: { phase: 'streaming', lastUpdateAt: 1000 },
  isForeground: true,
  isVisible: true,
  ...overrides,
});

// Advance the heartbeat by the canonical 1s step.
const nextHeartbeat = (prev: HapticsInput): HapticsInput => ({
  ...prev,
  streamState: prev.streamState
    ? { ...prev.streamState, lastUpdateAt: prev.streamState.lastUpdateAt + 1000 }
    : null,
});

// ---------------------------------------------------------------------------
// Platform checks
// ---------------------------------------------------------------------------

describe('isCapacitorNativePlatform', () => {
  test('returns false when window is undefined', () => {
    // @ts-expect-error testing SSR / undefined window
    globalThis.window = undefined;
    expect(isCapacitorNativePlatform()).toBe(false);
    // Restore – bun's test runner has a real window.
  });

  test('returns false when Capacitor is absent', () => {
    expect(isCapacitorNativePlatform()).toBe(false);
  });
});

describe('isCapacitorMobileNative', () => {
  test('returns false outside Capacitor shell', () => {
    expect(isCapacitorMobileNative()).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// evaluateHaptics – no streaming message
// ---------------------------------------------------------------------------

describe('evaluateHaptics', () => {
  test('skips when there is no streaming message', () => {
    const decision = evaluateHaptics(INITIAL_HAPTICS_STATE, baseInput({
      streamingMsgId: null,
      streamState: null,
    }));
    expect(decision.shouldTrigger).toBe(false);
    expect(decision.reason).toBe('no-message');
  });

  test('skips when stream state is null even with a msg id', () => {
    const decision = evaluateHaptics(INITIAL_HAPTICS_STATE, baseInput({
      streamState: null,
    }));
    expect(decision.shouldTrigger).toBe(false);
    expect(decision.reason).toBe('no-message');
  });

  // -----------------------------------------------------------------------
  // Background / hidden
  // -----------------------------------------------------------------------

  test('skips when app is not foreground', () => {
    const decision = evaluateHaptics(INITIAL_HAPTICS_STATE, baseInput({
      isForeground: false,
    }));
    expect(decision.shouldTrigger).toBe(false);
    expect(decision.reason).toBe('background');
  });

  test('skips when document is hidden', () => {
    const decision = evaluateHaptics(INITIAL_HAPTICS_STATE, baseInput({
      isVisible: false,
    }));
    expect(decision.shouldTrigger).toBe(false);
    expect(decision.reason).toBe('hidden');
  });

  // -----------------------------------------------------------------------
  // Not streaming phase
  // -----------------------------------------------------------------------

  test('skips when phase is cooldown', () => {
    const decision = evaluateHaptics(INITIAL_HAPTICS_STATE, baseInput({
      streamState: { phase: 'cooldown', lastUpdateAt: 1000 },
    }));
    expect(decision.shouldTrigger).toBe(false);
    expect(decision.reason).toBe('not-streaming');
  });

  test('skips when phase is completed', () => {
    const decision = evaluateHaptics(INITIAL_HAPTICS_STATE, baseInput({
      streamState: { phase: 'completed', lastUpdateAt: 1000 },
    }));
    expect(decision.shouldTrigger).toBe(false);
    expect(decision.reason).toBe('not-streaming');
  });

  // -----------------------------------------------------------------------
  // First heartbeat – should fire
  // -----------------------------------------------------------------------

  test('fires on first heartbeat', () => {
    const decision = evaluateHaptics(INITIAL_HAPTICS_STATE, baseInput());
    expect(decision.shouldTrigger).toBe(true);
    expect(decision.reason).toBe('trigger');
    expect(decision.nextState.lastTriggeredMsgId).toBe('msg_1');
    expect(decision.nextState.lastTriggeredAt).toBe(1000);
  });

  // -----------------------------------------------------------------------
  // Same heartbeat – dedup
  // -----------------------------------------------------------------------

  test('dedup: skips same heartbeat (same msgId, same lastUpdateAt)', () => {
    const state: HapticsState = {
      lastTriggeredMsgId: 'msg_1',
      lastTriggeredAt: 1000,
    };
    const decision = evaluateHaptics(state, baseInput());
    expect(decision.shouldTrigger).toBe(false);
    expect(decision.reason).toBe('same-heartbeat');
    // State unchanged
    expect(decision.nextState.lastTriggeredMsgId).toBe('msg_1');
    expect(decision.nextState.lastTriggeredAt).toBe(1000);
  });

  test('dedup: fires on next heartbeat tick (different lastUpdateAt)', () => {
    const state: HapticsState = {
      lastTriggeredMsgId: 'msg_1',
      lastTriggeredAt: 1000,
    };
    const decision = evaluateHaptics(state, nextHeartbeat(baseInput()));
    expect(decision.shouldTrigger).toBe(true);
    expect(decision.nextState.lastTriggeredMsgId).toBe('msg_1');
    expect(decision.nextState.lastTriggeredAt).toBe(2000);
  });

  // -----------------------------------------------------------------------
  // Session switch – new message ID triggers immediately
  // -----------------------------------------------------------------------

  test('fires immediately when message changes (new streaming turn)', () => {
    const state: HapticsState = {
      lastTriggeredMsgId: 'msg_old',
      lastTriggeredAt: 5000,
    };
    const decision = evaluateHaptics(state, baseInput({
      streamingMsgId: 'msg_new',
      streamState: { phase: 'streaming', lastUpdateAt: 100 },
    }));
    expect(decision.shouldTrigger).toBe(true);
    expect(decision.nextState.lastTriggeredMsgId).toBe('msg_new');
    expect(decision.nextState.lastTriggeredAt).toBe(100);
  });

  // -----------------------------------------------------------------------
  // Restart after completed → fires fresh
  // -----------------------------------------------------------------------

  test('fires again when a new streaming message starts after previous completed', () => {
    // Simulate state after previous stream completed
    const state: HapticsState = {
      lastTriggeredMsgId: 'msg_1',
      lastTriggeredAt: 3000,
    };
    const decision = evaluateHaptics(state, baseInput({
      streamingMsgId: 'msg_2',
      streamState: { phase: 'streaming', lastUpdateAt: 5000 },
    }));
    expect(decision.shouldTrigger).toBe(true);
    expect(decision.nextState.lastTriggeredMsgId).toBe('msg_2');
  });

  // -----------------------------------------------------------------------
  // Multi-step streaming simulation
  // -----------------------------------------------------------------------

  test('full streaming lifecycle: fire once per heartbeat', () => {
    let input: HapticsInput;
    let fireCount = 0;
    let state = INITIAL_HAPTICS_STATE;

    // Heartbeat 1 (first)
    input = baseInput({ streamState: { phase: 'streaming', lastUpdateAt: 1000 } });
    let d = evaluateHaptics(state, input);
    if (d.shouldTrigger) fireCount++;
    state = d.nextState;
    expect(fireCount).toBe(1);

    // Same heartbeat re-evaluation (dedup)
    d = evaluateHaptics(state, input);
    if (d.shouldTrigger) fireCount++;
    state = d.nextState;
    expect(fireCount).toBe(1);

    // Heartbeat 2
    input = nextHeartbeat(input);
    d = evaluateHaptics(state, input);
    if (d.shouldTrigger) fireCount++;
    state = d.nextState;
    expect(fireCount).toBe(2);

    // Heartbeat 3
    input = nextHeartbeat(input);
    d = evaluateHaptics(state, input);
    if (d.shouldTrigger) fireCount++;
    state = d.nextState;
    expect(fireCount).toBe(3);

    // Completed – stops
    d = evaluateHaptics(state, {
      ...input,
      streamState: { phase: 'completed', lastUpdateAt: input.streamState!.lastUpdateAt },
    });
    if (d.shouldTrigger) fireCount++;
    state = d.nextState;
    expect(fireCount).toBe(3);
    expect(d.reason).toBe('not-streaming');
  });

  // -----------------------------------------------------------------------
  // Background → foreground transition
  // -----------------------------------------------------------------------

  test('resumes firing after background → foreground', () => {
    const state: HapticsState = { lastTriggeredMsgId: 'msg_1', lastTriggeredAt: 1000 };
    const input = baseInput();

    // Backgrounded
    let d = evaluateHaptics(state, { ...input, isForeground: false });
    expect(d.shouldTrigger).toBe(false);
    expect(d.reason).toBe('background');

    // Return to foreground – heartbeat hasn't changed, but we already fired
    // for this heartbeat before backgrounding. Dedup should still hold.
    d = evaluateHaptics(state, { ...input, isForeground: true });
    expect(d.shouldTrigger).toBe(false);
    expect(d.reason).toBe('same-heartbeat');

    // Next heartbeat in foreground fires normally
    d = evaluateHaptics(state, nextHeartbeat(input));
    expect(d.shouldTrigger).toBe(true);
  });
});
