export const MOBILE_OVERLAY_ACTIVE_ATTRIBUTE = 'data-mobile-overlay-active';

type MobileOverlayElement = Pick<Element, 'getAttribute'>;

export const hasActiveMobileOverlay = (elements: Iterable<MobileOverlayElement>): boolean => (
  Array.from(elements).some((element) => element.getAttribute(MOBILE_OVERLAY_ACTIVE_ATTRIBUTE) !== 'false')
);
