/**
 * Haptic feedback for Capacitor native mobile apps.
 *
 * Pure logic (platform checks, should-trigger evaluation, dedup state machine)
 * lives here and is tested standalone. The hook wraps it with store subscriptions
 * and a fire-and-forget dynamic import to `@capacitor/haptics`.
 */

import React from 'react';
import {
  createStreamingHapticEventDeduper,
  createStreamingHapticEventQueue,
  subscribeToStreamingHapticEvents,
} from '@/sync/streaming-haptic-events';
import { useSessionUIStore } from '@/sync/session-ui-store';

export const HAPTIC_MIN_INTERVAL_MS = 20;
const useIsomorphicLayoutEffect = typeof window !== 'undefined' ? React.useLayoutEffect : React.useEffect;

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

export function shouldTriggerHaptic(lastTriggeredAt: number, now: number): boolean {
  return now - lastTriggeredAt >= HAPTIC_MIN_INTERVAL_MS;
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
let lastHapticAt = Number.NEGATIVE_INFINITY;

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

/** Fires one light haptic while the Capacitor mobile app is visible and active. */
export function triggerMobileHaptic(): boolean {
  if (!isCapacitorMobileNative()) return false;
  if (document.visibilityState !== 'visible' || !document.documentElement.classList.contains('oc-native-app-active')) return false;

  const now = Date.now();
  if (!shouldTriggerHaptic(lastHapticAt, now)) return false;
  lastHapticAt = now;

  void getHapticsModuleCached().then((mod) => {
    if (!mod) return;
    return mod.Haptics.impact({ style: mod.ImpactStyle.Light }).catch(() => undefined);
  });
  return true;
}

const MOBILE_PRESS_TARGET_SELECTOR = 'button, [role="button"]';

/** Adds light feedback after enabled mobile controls complete a real user click. */
export function useMobilePressHaptics(): void {
  React.useEffect(() => {
    if (!isCapacitorMobileNative()) return;

    const handleClick = (event: MouseEvent) => {
      if (!event.isTrusted || !(event.target instanceof Element)) return;
      const control = event.target.closest<HTMLElement>(MOBILE_PRESS_TARGET_SELECTOR);
      if (!control) return;
      if (control.matches(':disabled, [aria-disabled="true"], [data-mobile-press-feedback="none"]')) return;
      triggerMobileHaptic();
    };

    document.addEventListener('click', handleClick);
    return () => document.removeEventListener('click', handleClick);
  }, []);
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

/**
 * Fires a light haptic (`ImpactStyle.Light`) when a visible streaming part updates.
 *
 * - Only active on Capacitor iOS / Android native builds.
 * - Visible assistant text changes repeat; reasoning and tool appearances fire once per part.
 */
export function useStreamingHaptics(): void {
  useIsomorphicLayoutEffect(() => {
    if (!isCapacitorMobileNative()) return;

    let disposed = false;
    let timer: number | null = null;
    const shouldProcessEvent = createStreamingHapticEventDeduper();
    const queue = createStreamingHapticEventQueue();

    const canProcessEvent = (event: Parameters<typeof evaluateHaptics>[0]) => evaluateHaptics(event).shouldTrigger;
    const clearTimer = () => {
      if (timer === null) return;
      window.clearTimeout(timer);
      timer = null;
    };
    const schedule = (delay = 0) => {
      if (disposed || timer !== null || queue.size() === 0) return;
      timer = window.setTimeout(() => {
        timer = null;
        const event = queue.peek();
        if (!event || disposed) return;

        const currentSessionId = useSessionUIStore.getState().currentSessionId;
        const isForeground = document.documentElement.classList.contains('oc-native-app-active');
        if (!canProcessEvent({
          eventSessionId: event.sessionID,
          currentSessionId,
          isForeground,
          isVisible: document.visibilityState === 'visible',
        })) {
          queue.dequeue();
          schedule();
          return;
        }

        if (!triggerMobileHaptic()) {
          schedule(HAPTIC_MIN_INTERVAL_MS);
          return;
        }

        queue.dequeue();
        schedule(HAPTIC_MIN_INTERVAL_MS);
      }, delay);
    };

    const unsubscribe = subscribeToStreamingHapticEvents((event) => {
      if (disposed) return;
      if (!shouldProcessEvent(event)) return;

      const currentSessionId = useSessionUIStore.getState().currentSessionId;
      const isForeground = document.documentElement.classList.contains('oc-native-app-active');

      const decision = evaluateHaptics({
        eventSessionId: event.sessionID,
        currentSessionId,
        isForeground,
        isVisible: document.visibilityState === 'visible',
      });

      if (!decision.shouldTrigger) return;
      queue.enqueue(event);
      schedule();
    });

    return () => {
      disposed = true;
      clearTimer();
      queue.clear();
      unsubscribe();
    };
  }, []);
}
