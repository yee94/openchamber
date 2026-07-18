import React from 'react';

import { evaluateSwipeThresholdHaptic, triggerMobileHaptic } from '@/hooks/streamingHaptics';

/**
 * Phone-only content right-swipe gesture to open the session panel.
 *
 * A horizontal left-to-right swipe across roughly one third of the viewport opens
 * the session panel.
 *
 * - Only active on phone (not iPad), gated by the caller via `disabled`.
 * - Disabled when any overlay (sessions sheet, settings, files, etc.) is
 *   already open so the gesture doesn't stack sheets or compete with
 *   overlay dismiss gestures.
 * - Tappable content remains a click candidate until horizontal intent wins.
 * - The listener runs in capture phase so nested tools cannot interrupt an
 *   already-recognized swipe.
 * - Composer surfaces and horizontally-scrollable ancestors are excluded so
 *   the gesture stays separate from session switching and horizontal scrolling.
 */

const MAX_OFF_AXIS_RATIO = 0.55; // |dy| must stay below |dx| × this
const INTENT_DISTANCE = 8;
const THRESHOLD_HYSTERESIS = 8;
const OPEN_DISTANCE_RATIO = 0.35;

// ---------------------------------------------------------------------------
// Pure helpers — exported for targeted testing
// ---------------------------------------------------------------------------

export interface HeaderSwipeInput {
  /** touchstart clientX */
  startX: number;
  /** touchstart clientY */
  startY: number;
  /** touchend clientX */
  endX: number;
  /** touchend clientY */
  endY: number;
  /** current viewport width in CSS pixels */
  viewportWidth: number;
  /** whether the gesture is disabled (iPad or overlay open) */
  disabled: boolean;
  /** whether the touch started on the composer or a horizontally-scrollable target */
  startedOnExcludedTarget: boolean;
}

interface HeaderSwipeResult {
  /** Whether the gesture should trigger opening the sessions sheet */
  open: boolean;
}

interface HeaderSwipePoint {
  clientX: number;
  clientY: number;
}

interface HeaderSwipeGestureState {
  segmentStart: HeaderSwipePoint;
  lastTouch: HeaderSwipePoint;
  open: boolean;
}

export const createHeaderSwipeGestureState = (
  touch: HeaderSwipePoint,
): HeaderSwipeGestureState => ({
  segmentStart: touch,
  lastTouch: touch,
  open: false,
});

/**
 * Updates the opening candidate from one continuous horizontal direction
 * segment. A direction reversal anchors its new segment at the prior touch.
 */
export const updateHeaderSwipeGestureState = (
  state: HeaderSwipeGestureState,
  touch: HeaderSwipePoint,
  viewportWidth: number,
): HeaderSwipeGestureState => {
  const previousSegmentDx = state.lastTouch.clientX - state.segmentStart.clientX;
  const movementDx = touch.clientX - state.lastTouch.clientX;
  const reversed = previousSegmentDx !== 0
    && movementDx !== 0
    && Math.sign(previousSegmentDx) !== Math.sign(movementDx);
  if (reversed && Math.abs(movementDx) < INTENT_DISTANCE) return state;
  const segmentStart = reversed ? state.lastTouch : state.segmentStart;
  const dx = touch.clientX - segmentStart.clientX;
  const dy = touch.clientY - segmentStart.clientY;
  const exceedsThreshold = Math.abs(dx) >= viewportWidth * OPEN_DISTANCE_RATIO;
  const staysOnAxis = Math.abs(dy) <= Math.abs(dx) * MAX_OFF_AXIS_RATIO;

  return {
    segmentStart,
    lastTouch: touch,
    open: exceedsThreshold && staysOnAxis && dx > 0,
  };
};

/**
 * Pure function: determine whether a completed touch gesture on the header
 * should open the sessions sheet. Callers inject the gate flags; this function
 * only evaluates the geometric and interactive constraints.
 */
export const evaluateHeaderSwipe = (input: HeaderSwipeInput): HeaderSwipeResult => {
  if (input.disabled) return { open: false };
  if (input.startedOnExcludedTarget) return { open: false };

  return {
    open: updateHeaderSwipeGestureState(
      createHeaderSwipeGestureState({ clientX: input.startX, clientY: input.startY }),
      { clientX: input.endX, clientY: input.endY },
      input.viewportWidth,
    ).open,
  };
};

// ---------------------------------------------------------------------------
// Interactive / scrollable exclusion helpers
// ---------------------------------------------------------------------------

const hasHorizontallyScrollableAncestor = (element: Element | null): boolean => {
  let current: Element | null = element;
  while (current && current !== document.body && current !== document.documentElement) {
    const style = window.getComputedStyle(current);
    const overflowX = style.overflowX;
    if (overflowX === 'auto' || overflowX === 'scroll') {
      if (current.scrollWidth > current.clientWidth) return true;
    }
    current = current.parentElement;
  }
  return false;
};

const isExcludedTarget = (touch: Touch): boolean => {
  const element = document.elementFromPoint(touch.clientX, touch.clientY);
  return Boolean(element?.closest('[data-session-swipe-surface="true"]'))
    || hasHorizontallyScrollableAncestor(element);
};

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

interface HeaderSwipeToSessionsOptions {
  /** Called when a qualifying swipe is detected. */
  onOpen: () => void;
  /** Mounts the sessions surface when horizontal intent is first recognized. */
  onPreviewStart?: () => void;
  /** Closes a mounted preview when the gesture is cancelled. */
  onPreviewCancel?: () => void;
  /** Drives the mounted sessions surface while the finger moves. */
  onProgress?: (progress: number | null) => void;
  /** Whether the gesture is currently disabled (iPad or overlay open). */
  disabled: boolean;
}

export const useHeaderSwipeToSessions = (
  ref: React.RefObject<HTMLElement | null>,
  options: HeaderSwipeToSessionsOptions,
): void => {
  const onOpenRef = React.useRef(options.onOpen);
  onOpenRef.current = options.onOpen;
  const onPreviewStartRef = React.useRef(options.onPreviewStart);
  onPreviewStartRef.current = options.onPreviewStart;
  const onPreviewCancelRef = React.useRef(options.onPreviewCancel);
  onPreviewCancelRef.current = options.onPreviewCancel;
  const onProgressRef = React.useRef(options.onProgress);
  onProgressRef.current = options.onProgress;
  const disabledRef = React.useRef(options.disabled);
  disabledRef.current = options.disabled;

  React.useEffect(() => {
    const element = ref.current;
    if (!element) return;

    let tracking = false;
    let startedOnExcludedTarget = false;
    let horizontalIntent = false;
    let previewStarted = false;
    let thresholdReached = false;
    let thresholdHapticDelivered = false;
    let latestDistance = 0;
    let viewportWidth = 0;
    let gestureState: HeaderSwipeGestureState | null = null;

    const updateThreshold = (distance: number) => {
      const enterThreshold = viewportWidth * OPEN_DISTANCE_RATIO;
      const transition = evaluateSwipeThresholdHaptic({
        thresholdReached,
        distance,
        enterDistance: enterThreshold,
        cancelDistance: enterThreshold - THRESHOLD_HYSTERESIS,
        available: true,
      });
      thresholdReached = transition.thresholdReached;
      if (transition.event === 'enter') thresholdHapticDelivered = triggerMobileHaptic('medium', { bypassCadence: true });
      if (transition.event === 'cancel') {
        triggerMobileHaptic('light', { bypassCadence: true });
        thresholdHapticDelivered = false;
      }
    };

    const finishPreview = (commit: boolean) => {
      onProgressRef.current?.(null);
      if (thresholdReached && !commit) triggerMobileHaptic('light', { bypassCadence: true });
      thresholdReached = false;
      thresholdHapticDelivered = false;
      if (commit) {
        onOpenRef.current();
      } else if (previewStarted) {
        onPreviewCancelRef.current?.();
      }
      previewStarted = false;
    };

    const onTouchStart = (event: TouchEvent) => {
      if (event.touches.length !== 1) {
        tracking = false;
        gestureState = null;
        return;
      }
      if (disabledRef.current) {
        tracking = false;
        gestureState = null;
        return;
      }

      const touch = event.touches[0];
      tracking = true;
      viewportWidth = window.innerWidth;
      startedOnExcludedTarget = isExcludedTarget(touch);
      horizontalIntent = false;
      previewStarted = false;
      thresholdReached = false;
      thresholdHapticDelivered = false;
      latestDistance = 0;
      gestureState = createHeaderSwipeGestureState(touch);
    };

    const onTouchMove = (event: TouchEvent) => {
      if (!tracking || startedOnExcludedTarget || !gestureState) return;
      if (event.touches.length !== 1) {
        if (horizontalIntent) finishPreview(false);
        tracking = false;
        gestureState = null;
        return;
      }
      const touch = event.touches[0];
      gestureState = updateHeaderSwipeGestureState(gestureState, touch, viewportWidth);
      const dx = touch.clientX - gestureState.segmentStart.clientX;
      const dy = touch.clientY - gestureState.segmentStart.clientY;

      if (!horizontalIntent) {
        const absDx = Math.abs(dx);
        if (absDx < INTENT_DISTANCE) return;
        if (dx <= 0 || Math.abs(dy) > absDx * MAX_OFF_AXIS_RATIO) {
          return;
        }
        horizontalIntent = true;
        previewStarted = true;
        onPreviewStartRef.current?.();
      }

      if (Math.abs(dy) > Math.abs(dx) * MAX_OFF_AXIS_RATIO) {
        finishPreview(false);
        horizontalIntent = false;
        return;
      }

      event.preventDefault();
      latestDistance = Math.max(0, dx);
      updateThreshold(latestDistance);
      onProgressRef.current?.(Math.min(latestDistance / (viewportWidth * OPEN_DISTANCE_RATIO), 1));
    };

    const onTouchEnd = (event: TouchEvent) => {
      if (!tracking || !gestureState) return;
      tracking = false;
      const touch = event.changedTouches[0];
      if (touch) gestureState = updateHeaderSwipeGestureState(gestureState, touch, viewportWidth);
      const commit = horizontalIntent && gestureState.open;
      gestureState = null;
      if (!horizontalIntent) return;
      event.preventDefault();
      if (commit && !thresholdHapticDelivered) triggerMobileHaptic('medium', { bypassCadence: true });
      finishPreview(commit);
    };

    const onTouchCancel = () => {
      if (horizontalIntent) finishPreview(false);
      tracking = false;
      gestureState = null;
    };

    element.addEventListener('touchstart', onTouchStart, { passive: true, capture: true });
    element.addEventListener('touchmove', onTouchMove, { passive: false, capture: true });
    element.addEventListener('touchend', onTouchEnd, { passive: false, capture: true });
    element.addEventListener('touchcancel', onTouchCancel, { passive: true, capture: true });
    return () => {
      if (previewStarted) finishPreview(false);
      element.removeEventListener('touchstart', onTouchStart, true);
      element.removeEventListener('touchmove', onTouchMove, true);
      element.removeEventListener('touchend', onTouchEnd, true);
      element.removeEventListener('touchcancel', onTouchCancel, true);
    };
  }, [ref]);
};
