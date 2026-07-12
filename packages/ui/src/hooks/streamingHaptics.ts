/**
 * Streaming haptic feedback for Capacitor native mobile apps.
 *
 * Pure logic (platform checks, should-trigger evaluation, dedup state machine)
 * lives here and is tested standalone. The hook wraps it with store subscriptions
 * and a fire-and-forget dynamic import to `@capacitor/haptics`.
 */

import React from 'react';
import { useStreamingStore } from '@/sync/streaming';
import { useSessionUIStore } from '@/sync/session-ui-store';

// ---------------------------------------------------------------------------
// Pure logic – tested without Capacitor or React
// ---------------------------------------------------------------------------

/** True when running inside the Capacitor native shell (iOS / Android). */
export function isCapacitorNativePlatform(): boolean {
  if (typeof window === 'undefined') return false;
  const maybeCapacitor = (window as typeof window & {
    Capacitor?: { isNativePlatform?: () => boolean };
  }).Capacitor;
  return maybeCapacitor?.isNativePlatform?.() === true;
}

/** Platform is Capacitor AND the agent is iOS or Android (not a PWA inside a WebView pretending to be native). */
export function isCapacitorMobileNative(): boolean {
  if (!isCapacitorNativePlatform()) return false;
  const platform = (window as typeof window & {
    Capacitor?: { getPlatform?: () => string };
  }).Capacitor?.getPlatform?.();
  return platform === 'ios' || platform === 'android';
}

/** Snapshot of the store + environment used by the decision function. */
export type HapticsInput = {
  /** The message ID currently streaming for the active session (or null). */
  streamingMsgId: string | null;
  /** The phase + lastUpdateAt for the streaming message (or null). */
  streamState: { phase: string; lastUpdateAt: number } | null;
  /** True when the app is in the foreground (e.g. `oc-native-app-active` class is set). */
  isForeground: boolean;
  /** True when document.visibilityState is 'visible'. */
  isVisible: boolean;
  /** Current wall-clock time used by the cadence limiter. */
  now: number;
};

/** Internal dedup / throttle state. */
export type HapticsState = {
  /** The message ID for which we last fired a haptic. */
  lastTriggeredMsgId: string | null;
  /** Wall-clock time when the latest haptic fired. */
  lastTriggeredAt: number;
};

/** The result of evaluating whether haptics should fire. */
export type HapticsDecision = {
  shouldTrigger: boolean;
  reason: HapticsDecisionReason;
  nextState: HapticsState;
};

type HapticsDecisionReason =
  | 'trigger'
  | 'no-message'
  | 'background'
  | 'hidden'
  | 'not-streaming'
  | 'throttled';

export const STREAMING_HAPTIC_INTERVAL_MS = 40;

/**
 * Pure function: given the current dedup state and the latest snapshot,
 * decides whether a haptic should fire AND returns the next dedup state.
 *
 * Rules (in priority order):
 * 1. No streaming message → skip.
 * 2. App not foreground / document hidden → skip.
 * 3. Not in "streaming" phase → skip.
 * 4. Same message ID within the haptic cadence window → skip.
 * 5. Otherwise → fire and update dedup state.
 */
export function evaluateHaptics(
  state: HapticsState,
  input: HapticsInput,
): HapticsDecision {
  const { streamingMsgId, streamState, isForeground, isVisible, now } = input;

  // 1. Nothing streaming
  if (!streamingMsgId || !streamState) {
    return {
      shouldTrigger: false,
      reason: 'no-message',
      nextState: state,
    };
  }

  // 2. App is backgrounded or hidden
  if (!isForeground) {
    return {
      shouldTrigger: false,
      reason: 'background',
      nextState: state,
    };
  }
  if (!isVisible) {
    return {
      shouldTrigger: false,
      reason: 'hidden',
      nextState: state,
    };
  }

  // 3. Not in streaming phase
  if (streamState.phase !== 'streaming') {
    return {
      shouldTrigger: false,
      reason: 'not-streaming',
      nextState: state,
    };
  }

  // 4. Keep impacts close enough to feel continuous without flooding the native bridge.
  if (
    state.lastTriggeredMsgId === streamingMsgId &&
    now - state.lastTriggeredAt < STREAMING_HAPTIC_INTERVAL_MS
  ) {
    return {
      shouldTrigger: false,
      reason: 'throttled',
      nextState: state,
    };
  }

  // 5. Fire
  return {
    shouldTrigger: true,
    reason: 'trigger',
    nextState: {
      lastTriggeredMsgId: streamingMsgId,
      lastTriggeredAt: now,
    },
  };
}

/** Initial (reset) dedup state. */
export const INITIAL_HAPTICS_STATE: HapticsState = {
  lastTriggeredMsgId: null,
  lastTriggeredAt: 0,
};

// ---------------------------------------------------------------------------
// Dynamic import cache – prevents repeated imports of the Capacitor plugin
// ---------------------------------------------------------------------------

let hapticsImportPromise: Promise<typeof import('@capacitor/haptics')> | null = null;

function getHapticsModule(): Promise<typeof import('@capacitor/haptics')> {
  if (!hapticsImportPromise) {
    hapticsImportPromise = import('@capacitor/haptics');
  }
  return hapticsImportPromise;
}

let hapticsModuleCache: typeof import('@capacitor/haptics') | null = null;
let hapticsModuleCacheValid = false;

async function getHapticsModuleCached(): Promise<typeof import('@capacitor/haptics') | null> {
  if (hapticsModuleCacheValid) return hapticsModuleCache;
  try {
    hapticsModuleCache = await getHapticsModule();
    hapticsModuleCacheValid = true;
    return hapticsModuleCache;
  } catch {
    hapticsModuleCacheValid = true; // don't retry after failure
    return null;
  }
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

/**
 * Subscribes to the streaming store and fires a light haptic (`ImpactStyle.Light`)
 * every 40ms while the current session is streaming.
 *
 * - Only active on Capacitor iOS / Android native builds.
 * - Starts immediately and keeps a dense, typewriter-like cadence.
 * - Stops when the session switches, streaming finishes, app backgrounds,
 *   or the document is hidden.
 */
export function useStreamingHaptics(): void {
  React.useEffect(() => {
    if (!isCapacitorMobileNative()) return;

    let disposed = false;
    let state = INITIAL_HAPTICS_STATE;
    let hapticInFlight = false;

    // Keep at most one native bridge call in flight so slow devices do not build a queue.
    const fireHaptic = () => {
      if (hapticInFlight) return;
      hapticInFlight = true;
      void getHapticsModuleCached().then((mod) => {
        if (!mod || disposed) return;
        return mod.Haptics.impact({ style: mod.ImpactStyle.Light }).catch(() => undefined);
      }).finally(() => {
        hapticInFlight = false;
      });
    };

    const tick = () => {
      if (disposed) return;

      const currentSessionId = useSessionUIStore.getState().currentSessionId;
      if (!currentSessionId) {
        // No active session → reset dedup so next streaming session fires fresh.
        state = INITIAL_HAPTICS_STATE;
        return;
      }

      const streamingStore = useStreamingStore.getState();
      const streamingMsgId = streamingStore.streamingMessageIds.get(currentSessionId) ?? null;
      const streamState = streamingMsgId
        ? streamingStore.messageStreamStates.get(streamingMsgId) ?? null
        : null;

      // Detect foreground via the CSS class set by useNativeMobileLifecycle.
      const isForeground = document.documentElement.classList.contains('oc-native-app-active');

      const decision = evaluateHaptics(state, {
        streamingMsgId,
        streamState: streamState
          ? { phase: streamState.phase, lastUpdateAt: streamState.lastUpdateAt }
          : null,
        isForeground,
        isVisible: document.visibilityState === 'visible',
        now: Date.now(),
      });

      state = decision.nextState;

      if (decision.shouldTrigger) {
        fireHaptic();
      }
    };

    tick();
    const intervalId = window.setInterval(tick, STREAMING_HAPTIC_INTERVAL_MS);

    return () => {
      disposed = true;
      window.clearInterval(intervalId);
      state = INITIAL_HAPTICS_STATE;
    };
  }, []);
}
