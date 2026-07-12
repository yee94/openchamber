import React from 'react';
import type { Session } from '@opencode-ai/sdk/v2';

import { resolveGlobalSessionDirectory, useGlobalSessionsStore } from '@/stores/useGlobalSessionsStore';
import { useSessionUIStore } from '@/sync/session-ui-store';

/**
 * Touch-swipe gesture to switch sessions in the mobile chat content area.
 *
 * The gesture covers the entire chat container (no edge-zone restriction) and
 * detects four touch directions:
 *
 * - Left  swipe → step +1 (next / older session)
 * - Up    swipe → step +1 (next / older session)
 * - Right swipe → step -1 (prev / newer session)
 * - Down  swipe → step -1 (prev / newer session)
 *
 * The dominant axis is selected at end time by comparing |dx| and |dy|:
 * axis with the larger travel is the primary axis; the other must stay
 * within a reasonable off-axis ratio or the gesture is suppressed.
 *
 * Interactive controls, code blocks, and scrollable ancestors (only in the
 * dominant direction) are excluded so the gesture never fights scrolling or
 * steals taps on buttons / links / inputs / text selections.
 *
 * Navigation walks the same ranked list the rest of the mobile UI uses:
 * top-level sessions (no subtasks) across all projects, newest-first by
 * `time.updated`. The order is computed at gesture time from the store
 * (not subscribed) so it's always fresh and never re-attaches.
 *
 * Only `touchstart` / `touchend` are observed (both passive), so this
 * never blocks scrolling — it just reads where the gesture began and ended.
 */

const MIN_DISTANCE = 64; // px of dominant-axis travel required to commit a switch
const MAX_OFF_AXIS_RATIO = 0.6; // off-axis must stay below dominant-axis × this

// ---------------------------------------------------------------------------
// Interactive / scrollable exclusion helpers
// ---------------------------------------------------------------------------

const INTERACTIVE_SELECTORS = [
  'a[href]',
  'button',
  'input',
  'select',
  'textarea',
  '[contenteditable="true"]',
  '[role="button"]',
  '[role="combobox"]',
  '[role="link"]',
  '[role="dialog"]',
  '[role="listbox"]',
  '[role="menu"]',
  '[role="menuitem"]',
  '[role="option"]',
  '[role="textbox"]',
  '[data-radix-popper-content-wrapper]',
].join(',');

const CODE_SELECTOR = '[class*="code-block"], [class*="codeBlock"], pre, .cm-editor';

const isInteractiveTarget = (element: Element | null): boolean => {
  if (!element) return false;
  return element.matches(INTERACTIVE_SELECTORS)
    || element.closest(INTERACTIVE_SELECTORS) !== null;
};

const isCodeBlock = (element: Element | null): boolean => {
  if (!element) return false;
  return element.matches(CODE_SELECTOR) || element.closest(CODE_SELECTOR) !== null;
};

const hasScrollableAncestorInDirection = (element: Element | null, horizontal: boolean): boolean => {
  let current: Element | null = element;
  while (current && current !== document.body && current !== document.documentElement) {
    const style = window.getComputedStyle(current);
    if (horizontal) {
      const overflowX = style.overflowX;
      if ((overflowX === 'auto' || overflowX === 'scroll') && current.scrollWidth > current.clientWidth) {
        return true;
      }
    } else {
      const overflowY = style.overflowY;
      if ((overflowY === 'auto' || overflowY === 'scroll') && current.scrollHeight > current.clientHeight) {
        return true;
      }
    }
    current = current.parentElement;
  }
  return false;
};

// ---------------------------------------------------------------------------
// Pure helpers — exported for targeted testing
// ---------------------------------------------------------------------------

export interface SwipeDirectionInput {
  /** touchstart clientX */
  startX: number;
  /** touchstart clientY */
  startY: number;
  /** touchend clientX */
  endX: number;
  /** touchend clientY */
  endY: number;
}

export type SwipeDirection = 'prev' | 'next' | null;

/**
 * Pure function: determine swipe direction (prev / next) from raw touch
 * coordinates. Callers inject the gate flags; this function only evaluates
 * the geometric constraints — minimum distance, off-axis ratio, and
 * dominant-axis selection.
 */
export const evaluateSwipeDirection = (input: SwipeDirectionInput): SwipeDirection => {
  const dx = input.endX - input.startX;
  const dy = input.endY - input.startY;
  const absDx = Math.abs(dx);
  const absDy = Math.abs(dy);

  // Choose dominant axis
  if (absDx >= absDy) {
    // Horizontal dominant
    if (absDx < MIN_DISTANCE) return null;
    if (absDy > absDx * MAX_OFF_AXIS_RATIO) return null;
    return dx < 0 ? 'next' : 'prev';
  } else {
    // Vertical dominant
    if (absDy < MIN_DISTANCE) return null;
    if (absDx > absDy * MAX_OFF_AXIS_RATIO) return null;
    return dy < 0 ? 'next' : 'prev';
  }
};

// ---------------------------------------------------------------------------
// Session navigation helpers
// ---------------------------------------------------------------------------

const parentIdOf = (session: Session): string | null =>
  (session as Session & { parentID?: string | null }).parentID ?? null;

const updatedAt = (session: Session): number => session.time?.updated ?? session.time?.created ?? 0;

/** Top-level sessions across all projects, newest-first — the list the swipe walks. */
const orderedTopLevelSessions = (): Session[] =>
  useGlobalSessionsStore
    .getState()
    .activeSessions.filter((session) => parentIdOf(session) === null)
    .slice()
    .sort((a, b) => updatedAt(b) - updatedAt(a));

/**
 * Switch to the session `step` positions away from the current one (clamped — no wrap).
 * Returns true if a switch actually happened.
 */
const switchByStep = (step: number): boolean => {
  const ordered = orderedTopLevelSessions();
  if (ordered.length < 2) return false;

  const currentId = useSessionUIStore.getState().currentSessionId;
  const index = ordered.findIndex((session) => session.id === currentId);
  if (index < 0) return false;

  const targetIndex = index + step;
  if (targetIndex < 0 || targetIndex >= ordered.length) return false;

  const target = ordered[targetIndex];
  useSessionUIStore.getState().setCurrentSession(target.id, resolveGlobalSessionDirectory(target));
  return true;
};

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

export interface EdgeSwipeSessionSwitchOptions {
  /** Called after a successful switch, with the travel direction, so the caller can animate. */
  onSwitch?: (direction: 'prev' | 'next') => void;
}

export const useEdgeSwipeSessionSwitch = (
  ref: React.RefObject<HTMLElement | null>,
  options?: EdgeSwipeSessionSwitchOptions,
): void => {
  // Keep onSwitch in a ref so a changing callback identity doesn't re-attach the listeners.
  const onSwitchRef = React.useRef(options?.onSwitch);
  onSwitchRef.current = options?.onSwitch;

  React.useEffect(() => {
    const element = ref.current;
    if (!element) return;

    let tracking = false;
    let startX = 0;
    let startY = 0;
    let startedOnSwallowTarget = false;

    const isSwallowTarget = (touch: Touch): boolean => {
      const target = document.elementFromPoint(touch.clientX, touch.clientY);
      return isInteractiveTarget(target) || isCodeBlock(target);
    };

    const onTouchStart = (event: TouchEvent) => {
      if (event.touches.length !== 1) {
        tracking = false;
        return;
      }
      const touch = event.touches[0];
      tracking = true;
      startX = touch.clientX;
      startY = touch.clientY;
      startedOnSwallowTarget = isSwallowTarget(touch);
    };

    const onTouchEnd = (event: TouchEvent) => {
      if (!tracking) return;
      tracking = false;
      if (startedOnSwallowTarget) return;

      const touch = event.changedTouches[0];
      if (!touch) return;

      const dx = touch.clientX - startX;
      const dy = touch.clientY - startY;
      const absDx = Math.abs(dx);
      const absDy = Math.abs(dy);

      // Check scrollable ancestors in the dominant direction before committing
      const isHorizontal = absDx >= absDy;
      const target = document.elementFromPoint(touch.clientX, touch.clientY);
      if (hasScrollableAncestorInDirection(target, isHorizontal)) return;

      const direction = evaluateSwipeDirection({
        startX,
        startY,
        endX: touch.clientX,
        endY: touch.clientY,
      });

      if (!direction) return;

      const step = direction === 'prev' ? -1 : 1;
      if (switchByStep(step)) {
        onSwitchRef.current?.(direction);
      }
    };

    const onTouchCancel = () => {
      tracking = false;
    };

    element.addEventListener('touchstart', onTouchStart, { passive: true });
    element.addEventListener('touchend', onTouchEnd, { passive: true });
    element.addEventListener('touchcancel', onTouchCancel, { passive: true });
    return () => {
      element.removeEventListener('touchstart', onTouchStart);
      element.removeEventListener('touchend', onTouchEnd);
      element.removeEventListener('touchcancel', onTouchCancel);
    };
  }, [ref]);
};
