import React from 'react';

/**
 * Phone-only content-area left-swipe gesture to open the sessions sheet.
 *
 * A horizontal right-to-left swipe inside the chat content area (away from the
 * left/right screen edges) opens the sessions sheet — a natural complement to
 * the mobile header's hamburger button.
 *
 * - Only active on phone (not iPad/desktop, gated by the caller).
 * - Must start > 32 px from both left AND right edges so it never collides
 *   with the edge-swipe session switch (useEdgeSwipeSessionSwitch).
 * - Vertical scrolling, text selections, interactive controls, code blocks,
 *   and horizontally-scrollable ancestors are ignored.
 * - Only touchstart / touchend are observed (both passive), so this never
 *   blocks scrolling.
 * - Does not fire when the sessions sheet or any other overlay is already open.
 */

const EDGE_EXCLUDE = 32; // px from a screen side excluded from this gesture
const MIN_DISTANCE = 72; // px of horizontal leftward travel required
const MAX_OFF_AXIS_RATIO = 0.55; // |dy| must stay below |dx| * this

// ---------------------------------------------------------------------------
// Pure helpers — exported for targeted testing
// ---------------------------------------------------------------------------

export interface SwipeToSessionsInput {
  /** touchstart clientX */
  startX: number;
  /** touchstart clientY */
  startY: number;
  /** touchend clientX */
  endX: number;
  /** touchend clientY */
  endY: number;
  /** clientWidth of the container element */
  containerWidth: number;
  /** whether the sessions sheet or any overlay is already open */
  disabled: boolean;
  /** whether the touch started on an interactive / horizontally-scrollable target */
  startedOnInteractive: boolean;
}

interface SwipeToSessionsResult {
  /** Whether the gesture should trigger opening the sessions sheet */
  open: boolean;
}

/**
 * Pure function: determine whether a completed touch gesture should open the
 * sessions sheet. Callers inject the gate flags; this function only evaluates
 * the geometric and interactive constraints.
 */
export const evaluateSwipeToSessions = (input: SwipeToSessionsInput): SwipeToSessionsResult => {
  if (input.disabled) return { open: false };
  if (input.startedOnInteractive) return { open: false };

  // Must start inside the content area, away from both edges
  if (input.startX <= EDGE_EXCLUDE) return { open: false };
  if (input.startX >= input.containerWidth - EDGE_EXCLUDE) return { open: false };

  const dx = input.endX - input.startX;
  const dy = input.endY - input.startY;

  // Must be a horizontal leftward swipe (right-to-left)
  if (dx >= 0) return { open: false };
  if (Math.abs(dx) < MIN_DISTANCE) return { open: false };

  // Suppress off-axis (vertical) gestures — kept stricter than the edge
  // swipe so diagonal scrolls don't open the sheet.
  if (Math.abs(dy) > Math.abs(dx) * MAX_OFF_AXIS_RATIO) return { open: false };

  return { open: true };
};

// ---------------------------------------------------------------------------
// Helper: did the touch start on an interactive or horizontally-scrollable
// target whose ancestors we should not intercept?
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

const isInteractiveTarget = (element: Element | null): boolean => {
  if (!element) return false;
  return element.matches(INTERACTIVE_SELECTORS)
    || element.closest(INTERACTIVE_SELECTORS) !== null;
};

const hasHorizontallyScrollableAncestor = (element: Element | null): boolean => {
  let current: Element | null = element;
  while (current && current !== document.body && current !== document.documentElement) {
    const style = window.getComputedStyle(current);
    const overflowX = style.overflowX;
    if (overflowX === 'auto' || overflowX === 'scroll') {
      // Only treat as a block if it actually has scrollable width
      if (current.scrollWidth > current.clientWidth) return true;
    }
    current = current.parentElement;
  }
  return false;
};

const isSwallowTarget = (touch: Touch): boolean => {
  const element = document.elementFromPoint(touch.clientX, touch.clientY);
  return isInteractiveTarget(element) || hasHorizontallyScrollableAncestor(element);
};

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

interface ContentSwipeToSessionsOptions {
  /** Called when a qualifying swipe is detected. */
  onOpen: () => void;
  /** Whether the gesture is currently disabled (e.g. overlay open). */
  disabled: boolean;
}

export const useContentSwipeToSessions = (
  ref: React.RefObject<HTMLElement | null>,
  options: ContentSwipeToSessionsOptions,
): void => {
  const onOpenRef = React.useRef(options.onOpen);
  onOpenRef.current = options.onOpen;
  const disabledRef = React.useRef(options.disabled);
  disabledRef.current = options.disabled;

  React.useEffect(() => {
    const element = ref.current;
    if (!element) return;

    let tracking = false;
    let startX = 0;
    let startY = 0;
    let startedOnInteractive = false;

    const onTouchStart = (event: TouchEvent) => {
      if (event.touches.length !== 1) {
        tracking = false;
        return;
      }
      if (disabledRef.current) {
        tracking = false;
        return;
      }

      const touch = event.touches[0];
      const width = element.clientWidth;

      // Exclude edge zones — those belong to the session-switch edge swipe
      if (touch.clientX <= EDGE_EXCLUDE || touch.clientX >= width - EDGE_EXCLUDE) {
        tracking = false;
        return;
      }

      tracking = true;
      startX = touch.clientX;
      startY = touch.clientY;
      startedOnInteractive = isSwallowTarget(touch);
    };

    const onTouchEnd = (event: TouchEvent) => {
      if (!tracking) return;
      tracking = false;
      if (disabledRef.current) return;

      const touch = event.changedTouches[0];
      if (!touch) return;

      const { open } = evaluateSwipeToSessions({
        startX,
        startY,
        endX: touch.clientX,
        endY: touch.clientY,
        containerWidth: element.clientWidth,
        disabled: disabledRef.current,
        startedOnInteractive,
      });

      if (open) {
        onOpenRef.current();
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
