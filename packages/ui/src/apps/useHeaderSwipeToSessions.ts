import React from 'react';

/**
 * Phone-only header right-swipe gesture to open the sessions / project sheet.
 *
 * A horizontal left-to-right swipe in the MobileHeader area opens the
 * sessions sheet — a natural complement to the header's hamburger button.
 *
 * - Only active on phone (not iPad), gated by the caller via `disabled`.
 * - Disabled when any overlay (sessions sheet, settings, files, etc.) is
 *   already open so the gesture doesn't stack sheets or compete with
 *   overlay dismiss gestures.
 * - Interactive controls (buttons, links, inputs) and horizontally-scrollable
 *   ancestors are excluded so the gesture never fights scrolling or steals
 *   taps from the header's own toolbar buttons.
 * - Only `touchstart` / `touchend` are observed (both passive), so this
 *   never blocks scrolling.
 */

const MIN_DISTANCE = 72; // px of horizontal rightward travel required
const MAX_OFF_AXIS_RATIO = 0.55; // |dy| must stay below |dx| × this

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
  /** whether the gesture is disabled (iPad or overlay open) */
  disabled: boolean;
  /** whether the touch started on an interactive / horizontally-scrollable target */
  startedOnInteractive: boolean;
}

interface HeaderSwipeResult {
  /** Whether the gesture should trigger opening the sessions sheet */
  open: boolean;
}

/**
 * Pure function: determine whether a completed touch gesture on the header
 * should open the sessions sheet. Callers inject the gate flags; this function
 * only evaluates the geometric and interactive constraints.
 */
export const evaluateHeaderSwipe = (input: HeaderSwipeInput): HeaderSwipeResult => {
  if (input.disabled) return { open: false };
  if (input.startedOnInteractive) return { open: false };

  const dx = input.endX - input.startX;
  const dy = input.endY - input.startY;

  // Must be a horizontal rightward swipe (left-to-right)
  if (dx <= 0) return { open: false };
  if (Math.abs(dx) < MIN_DISTANCE) return { open: false };

  // Suppress off-axis (vertical) gestures so diagonal scrolls don't open the sheet
  if (Math.abs(dy) > Math.abs(dx) * MAX_OFF_AXIS_RATIO) return { open: false };

  return { open: true };
};

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

interface HeaderSwipeToSessionsOptions {
  /** Called when a qualifying swipe is detected. */
  onOpen: () => void;
  /** Whether the gesture is currently disabled (iPad or overlay open). */
  disabled: boolean;
}

export const useHeaderSwipeToSessions = (
  ref: React.RefObject<HTMLElement | null>,
  options: HeaderSwipeToSessionsOptions,
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

      const { open } = evaluateHeaderSwipe({
        startX,
        startY,
        endX: touch.clientX,
        endY: touch.clientY,
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
