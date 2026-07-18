import React from 'react';

import {
  MOBILE_SHEET_COLLAPSED_SNAP,
  MOBILE_SHEET_EXPANDED_SNAP,
  type MobileSheetSnapController,
} from './useMobileSheetSnap';

export const MobileSheetSnapHandle: React.FC<{
  controller: MobileSheetSnapController;
  ariaLabel: string;
}> = ({ controller, ariaLabel }) => (
  <div
    data-mobile-sheet-snap-handle
    role="separator"
    tabIndex={0}
    aria-label={ariaLabel}
    aria-orientation="horizontal"
    aria-valuemin={MOBILE_SHEET_COLLAPSED_SNAP * 100}
    aria-valuemax={MOBILE_SHEET_EXPANDED_SNAP * 100}
    aria-valuenow={Math.round(controller.snapPoint * 100)}
    className="flex min-h-8 cursor-ns-resize touch-none justify-center pt-2.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[var(--interactive-focus-ring)]"
    onPointerDown={controller.handlePointerDown}
    onPointerMove={controller.handlePointerMove}
    onPointerUp={controller.handlePointerUp}
    onPointerCancel={controller.handlePointerCancel}
    onClick={controller.handleClick}
    onKeyDown={controller.handleKeyDown}
  >
    <div className="h-1.5 w-11 rounded-full bg-[var(--interactive-border)]" />
  </div>
);
