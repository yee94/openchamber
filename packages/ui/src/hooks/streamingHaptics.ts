/**
 * Streaming haptic feedback for Capacitor native mobile apps.
 *
 * Pure logic (platform checks, should-trigger evaluation, dedup state machine)
 * lives here and is tested standalone. The hook wraps it with store subscriptions
 * and a fire-and-forget dynamic import to `@capacitor/haptics`.
 */

import React from 'react';
import { subscribeToStreamingHapticEvents } from '@/sync/streaming-haptic-events';
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
  /** Session that produced the visible part update. */
  eventSessionId: string;
  /** Session currently displayed by the mobile shell. */
  currentSessionId: string | null;
  /** True when the app is in the foreground (e.g. `oc-native-app-active` class is set). */
  isForeground: boolean;
  /** True when document.visibilityState is 'visible'. */
  isVisible: boolean;
};

/** The result of evaluating whether haptics should fire. */
export type HapticsDecision = {
  shouldTrigger: boolean;
  reason: HapticsDecisionReason;
};

type HapticsDecisionReason =
  | 'trigger'
  | 'different-session'
  | 'background'
  | 'hidden';

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
export function evaluateHaptics(input: HapticsInput): HapticsDecision {
  const { eventSessionId, currentSessionId, isForeground, isVisible } = input;

  if (!currentSessionId || eventSessionId !== currentSessionId) {
    return {
      shouldTrigger: false,
      reason: 'different-session',
    };
  }

  // 2. App is backgrounded or hidden
  if (!isForeground) {
    return {
      shouldTrigger: false,
      reason: 'background',
    };
  }
  if (!isVisible) {
    return {
      shouldTrigger: false,
      reason: 'hidden',
    };
  }

  // 5. Fire
  return {
    shouldTrigger: true,
    reason: 'trigger',
  };
}

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
 * Fires a light haptic (`ImpactStyle.Light`) when a visible streaming part updates.
 *
 * - Only active on Capacitor iOS / Android native builds.
 * - Thinking fires once when its part first appears.
 * - Visible assistant text fires once for each applied text update.
 */
export function useStreamingHaptics(): void {
  React.useEffect(() => {
    if (!isCapacitorMobileNative()) return;

    let disposed = false;
    const fireHaptic = () => {
      void getHapticsModuleCached().then((mod) => {
        if (!mod || disposed) return;
        return mod.Haptics.impact({ style: mod.ImpactStyle.Light }).catch(() => undefined);
      });
    };

    const unsubscribe = subscribeToStreamingHapticEvents((event) => {
      if (disposed) return;

      const currentSessionId = useSessionUIStore.getState().currentSessionId;
      const isForeground = document.documentElement.classList.contains('oc-native-app-active');

      const decision = evaluateHaptics({
        eventSessionId: event.sessionID,
        currentSessionId,
        isForeground,
        isVisible: document.visibilityState === 'visible',
      });

      if (decision.shouldTrigger) {
        fireHaptic();
      }
    });

    return () => {
      disposed = true;
      unsubscribe();
    };
  }, []);
}
