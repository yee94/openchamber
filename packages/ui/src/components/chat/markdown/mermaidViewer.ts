type MermaidViewBox = {
  x: number;
  y: number;
  width: number;
  height: number;
};

type MermaidViewport = {
  width: number;
  height: number;
};

type MermaidPoint = {
  x: number;
  y: number;
};

type MermaidPinchGesture = {
  center: MermaidPoint;
  distance: number;
};

type MermaidViewerController = {
  zoomIn: () => void;
  zoomOut: () => void;
  fit: () => void;
  cleanup: () => void;
};

type MermaidSvgBoundsSource = {
  viewBox?: string | null;
  width?: string | number | null;
  height?: string | number | null;
};

type MermaidViewerSignatureSource = MermaidSvgBoundsSource & {
  renderMode?: string | null;
  svgMarkup?: string | null;
};

const isPositiveFinite = (value: number): boolean => Number.isFinite(value) && value > 0;

const parseSvgNumber = (value: string | number | null | undefined): number | null => {
  if (typeof value === 'number') {
    return isPositiveFinite(value) ? value : null;
  }
  if (typeof value !== 'string') {
    return null;
  }
  const match = value.trim().match(/^([+-]?(?:(?:\d+\.?\d*)|(?:\.\d+))(?:[eE][+-]?\d+)?)(?:px)?$/);
  if (!match) {
    return null;
  }
  const parsed = Number(match[1]);
  return isPositiveFinite(parsed) ? parsed : null;
};

const clamp = (value: number, min: number, max: number): number => Math.min(max, Math.max(min, value));

const VIEW_BOX_PRECISION = 6;
const ZOOM_STEP = 1.25;
const WHEEL_ZOOM_BASE = 1.0015;
const WHEEL_LINE_DELTA_PX = 16;
const MAX_WHEEL_DELTA_PX = 1_000;
const MIN_SCALE = 0.5;
const MAX_SCALE = 12;
const DRAG_CLICK_SUPPRESSION_THRESHOLD_PX = 3;
const DRAG_CLICK_SUPPRESSION_CLEAR_MS = 400;
export const MERMAID_BLOCK_SELECTOR = '[data-markdown="mermaid-block"]';

export const shouldRefreshMermaidViewers = (container: Pick<HTMLElement, 'querySelector'>): boolean => (
  container.querySelector(MERMAID_BLOCK_SELECTOR) !== null
);

export const formatMermaidViewBox = (box: MermaidViewBox): string => (
  [box.x, box.y, box.width, box.height]
    .map((value) => {
      const rounded = Number(value.toFixed(VIEW_BOX_PRECISION));
      return Object.is(rounded, -0) ? '0' : String(rounded);
    })
    .join(' ')
);

export const getMermaidSvgContentBox = (source: MermaidSvgBoundsSource): MermaidViewBox | null => {
  const viewBoxParts = source.viewBox
    ?.trim()
    .split(/[\s,]+/)
    .map((part) => Number.parseFloat(part));
  if (viewBoxParts?.length === 4) {
    const [x, y, width, height] = viewBoxParts;
    if (
      Number.isFinite(x)
      && Number.isFinite(y)
      && isPositiveFinite(width)
      && isPositiveFinite(height)
    ) {
      return { x, y, width, height };
    }
  }

  const width = parseSvgNumber(source.width);
  const height = parseSvgNumber(source.height);
  if (width === null || height === null) {
    return null;
  }

  return { x: 0, y: 0, width, height };
};

const hashMermaidSignaturePart = (value: string): string => {
  let hash = 2166136261;
  for (let i = 0; i < value.length; i += 1) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(36);
};

export const getMermaidViewerSignature = (source: MermaidViewerSignatureSource): string => {
  const renderMode = source.renderMode || 'unknown';
  const svgMarkup = source.svgMarkup ?? '';
  if (!svgMarkup) {
    const bounds = [source.viewBox ?? '', source.width ?? '', source.height ?? ''];
    return bounds.some((part) => part !== '') ? `${renderMode}:bounds:${bounds.join(':')}` : `${renderMode}:no-svg`;
  }

  return [
    renderMode,
    hashMermaidSignaturePart(svgMarkup),
  ].join(':');
};

export const fitMermaidViewBox = (contentBox: MermaidViewBox, viewport: MermaidViewport): MermaidViewBox => {
  if (!isPositiveFinite(viewport.width) || !isPositiveFinite(viewport.height)) {
    return contentBox;
  }

  const contentAspect = contentBox.width / contentBox.height;
  const viewportAspect = viewport.width / viewport.height;
  if (contentAspect > viewportAspect) {
    const height = contentBox.width / viewportAspect;
    return {
      x: contentBox.x,
      y: contentBox.y - (height - contentBox.height) / 2,
      width: contentBox.width,
      height,
    };
  }

  const width = contentBox.height * viewportAspect;
  return {
    x: contentBox.x - (width - contentBox.width) / 2,
    y: contentBox.y,
    width,
    height: contentBox.height,
  };
};

export const panMermaidViewBox = ({
  currentBox,
  viewport,
  delta,
}: {
  currentBox: MermaidViewBox;
  viewport: MermaidViewport;
  delta: MermaidPoint;
}): MermaidViewBox => {
  if (
    !isPositiveFinite(viewport.width)
    || !isPositiveFinite(viewport.height)
    || !isPositiveFinite(currentBox.width)
    || !isPositiveFinite(currentBox.height)
  ) {
    return currentBox;
  }

  return {
    x: currentBox.x - (delta.x / viewport.width) * currentBox.width,
    y: currentBox.y - (delta.y / viewport.height) * currentBox.height,
    width: currentBox.width,
    height: currentBox.height,
  };
};

export const normalizeMermaidWheelDelta = (
  deltaY: number,
  deltaMode: number,
  viewportHeight: number,
): number => {
  const unit = deltaMode === 1
    ? WHEEL_LINE_DELTA_PX
    : deltaMode === 2
      ? (isPositiveFinite(viewportHeight) ? viewportHeight : 0)
      : 1;
  const delta = deltaY * unit;
  return Number.isFinite(delta) ? clamp(delta, -MAX_WHEEL_DELTA_PX, MAX_WHEEL_DELTA_PX) : 0;
};

const getMermaidPinchGesture = (pointers: Iterable<MermaidPoint>): MermaidPinchGesture | null => {
  let first: MermaidPoint | null = null;
  for (const pointer of pointers) {
    if (!first) {
      first = pointer;
      continue;
    }

    return {
      center: {
        x: (first.x + pointer.x) / 2,
        y: (first.y + pointer.y) / 2,
      },
      distance: Math.hypot(pointer.x - first.x, pointer.y - first.y),
    };
  }
  return null;
};

export const hasMermaidPointerDragMoved = (start: MermaidPoint, current: MermaidPoint): boolean => {
  const deltaX = current.x - start.x;
  const deltaY = current.y - start.y;
  return (deltaX * deltaX) + (deltaY * deltaY) > (DRAG_CLICK_SUPPRESSION_THRESHOLD_PX * DRAG_CLICK_SUPPRESSION_THRESHOLD_PX);
};

export const zoomMermaidViewBoxAtPoint = ({
  currentBox,
  contentBox,
  viewport,
  pointer,
  zoomFactor,
  minScale,
  maxScale,
}: {
  currentBox: MermaidViewBox;
  contentBox: MermaidViewBox;
  viewport: MermaidViewport;
  pointer: MermaidPoint;
  zoomFactor: number;
  minScale: number;
  maxScale: number;
}): MermaidViewBox => {
  if (
    !isPositiveFinite(viewport.width)
    || !isPositiveFinite(viewport.height)
    || !isPositiveFinite(zoomFactor)
    || !isPositiveFinite(currentBox.width)
    || !isPositiveFinite(currentBox.height)
    || !isPositiveFinite(contentBox.width)
    || !isPositiveFinite(contentBox.height)
    || !isPositiveFinite(minScale)
    || !isPositiveFinite(maxScale)
  ) {
    return currentBox;
  }

  const min = Math.min(minScale, maxScale);
  const max = Math.max(minScale, maxScale);
  const fittedBox = fitMermaidViewBox(contentBox, viewport);
  const currentScale = fittedBox.width / currentBox.width;
  const nextScale = clamp(currentScale * zoomFactor, min, max);
  const nextWidth = fittedBox.width / nextScale;
  const nextHeight = nextWidth / (currentBox.width / currentBox.height);
  const pointerRatioX = clamp(pointer.x / viewport.width, 0, 1);
  const pointerRatioY = clamp(pointer.y / viewport.height, 0, 1);
  const svgPointX = currentBox.x + pointerRatioX * currentBox.width;
  const svgPointY = currentBox.y + pointerRatioY * currentBox.height;

  return {
    x: svgPointX - pointerRatioX * nextWidth,
    y: svgPointY - pointerRatioY * nextHeight,
    width: nextWidth,
    height: nextHeight,
  };
};

export const pinchMermaidViewBox = ({
  currentBox,
  contentBox,
  viewport,
  previousGesture,
  gesture,
  minScale,
  maxScale,
}: {
  currentBox: MermaidViewBox;
  contentBox: MermaidViewBox;
  viewport: MermaidViewport;
  previousGesture: MermaidPinchGesture;
  gesture: MermaidPinchGesture;
  minScale: number;
  maxScale: number;
}): MermaidViewBox => {
  if (!isPositiveFinite(previousGesture.distance) || !isPositiveFinite(gesture.distance)) {
    return currentBox;
  }

  const pannedBox = panMermaidViewBox({
    currentBox,
    viewport,
    delta: {
      x: gesture.center.x - previousGesture.center.x,
      y: gesture.center.y - previousGesture.center.y,
    },
  });

  return zoomMermaidViewBoxAtPoint({
    currentBox: pannedBox,
    contentBox,
    viewport,
    pointer: gesture.center,
    zoomFactor: gesture.distance / previousGesture.distance,
    minScale,
    maxScale,
  });
};

const controllerByBlock = new WeakMap<HTMLElement, MermaidViewerController>();

export const getMermaidViewerController = (block: Element | null): MermaidViewerController | null => (
  block instanceof HTMLElement ? controllerByBlock.get(block) ?? null : null
);

const getSvgViewport = (block: HTMLElement): HTMLElement | null => (
  block.querySelector<HTMLElement>('[data-markdown="mermaid-viewport"]')
    ?? block.querySelector<HTMLElement>('[data-markdown="mermaid"]')
);

const getBlockViewerSignature = (block: HTMLElement): string => {
  const svg = block.querySelector<SVGSVGElement>('[data-markdown="mermaid"] svg');
  const svgHost = block.querySelector<HTMLElement>('[data-markdown="mermaid"]');
  return getMermaidViewerSignature({
    renderMode: block.getAttribute('data-mermaid-render'),
    svgMarkup: svgHost?.getAttribute('data-md-original-svg') ?? svg?.outerHTML ?? null,
    viewBox: svg?.getAttribute('viewBox'),
    width: svg?.getAttribute('width'),
    height: svg?.getAttribute('height'),
  });
};

const getViewportSize = (viewport: HTMLElement): MermaidViewport => {
  const rect = viewport.getBoundingClientRect();
  return { width: rect.width, height: rect.height };
};

export const getMermaidPointerInViewport = (
  event: Pick<PointerEvent | WheelEvent, 'clientX' | 'clientY'>,
  viewport: Pick<DOMRect, 'left' | 'top'>,
): MermaidPoint => ({
  x: event.clientX - viewport.left,
  y: event.clientY - viewport.top,
});

const getPointerInViewport = (event: Pick<PointerEvent | WheelEvent, 'clientX' | 'clientY'>, viewport: HTMLElement): MermaidPoint => (
  getMermaidPointerInViewport(event, viewport.getBoundingClientRect())
);

const isPanExcludedTarget = (target: EventTarget | null): boolean => (
  target instanceof Element && Boolean(target.closest('button, a, [role="button"]'))
);

const createMermaidViewerController = (block: HTMLElement): MermaidViewerController | null => {
  const viewport = getSvgViewport(block);
  const svg = block.querySelector<SVGSVGElement>('[data-markdown="mermaid"] svg');
  if (!viewport || !svg) {
    return null;
  }

  const contentBox = getMermaidSvgContentBox({
    viewBox: svg.getAttribute('viewBox'),
    width: svg.getAttribute('width'),
    height: svg.getAttribute('height'),
  });
  if (!contentBox) {
    return null;
  }

  let currentBox = contentBox;
  let activePointerId: number | null = null;
  let dragStartPointer: MermaidPoint | null = null;
  let lastPointer: MermaidPoint | null = null;
  const touchPointers = new Map<number, MermaidPoint>();
  const capturedPointerIds = new Set<number>();
  let lastPinchGesture: MermaidPinchGesture | null = null;
  let clearClickSuppressionTimer: number | null = null;

  const applyViewBox = (box: MermaidViewBox): void => {
    currentBox = box;
    svg.setAttribute('viewBox', formatMermaidViewBox(box));
    svg.removeAttribute('width');
    svg.removeAttribute('height');
  };

  const fit = (): void => {
    applyViewBox(fitMermaidViewBox(contentBox, getViewportSize(viewport)));
  };

  const zoomAt = (pointer: MermaidPoint, zoomFactor: number): void => {
    applyViewBox(zoomMermaidViewBoxAtPoint({
      currentBox,
      contentBox,
      viewport: getViewportSize(viewport),
      pointer,
      zoomFactor,
      minScale: MIN_SCALE,
      maxScale: MAX_SCALE,
    }));
  };

  const zoomIn = (): void => {
    const size = getViewportSize(viewport);
    zoomAt({ x: size.width / 2, y: size.height / 2 }, ZOOM_STEP);
  };

  const zoomOut = (): void => {
    const size = getViewportSize(viewport);
    zoomAt({ x: size.width / 2, y: size.height / 2 }, 1 / ZOOM_STEP);
  };

  const onWheel = (event: WheelEvent): void => {
    event.preventDefault();
    event.stopPropagation();
    const delta = normalizeMermaidWheelDelta(event.deltaY, event.deltaMode, getViewportSize(viewport).height);
    zoomAt(getPointerInViewport(event, viewport), Math.pow(WHEEL_ZOOM_BASE, -delta));
  };

  const capturePointer = (pointerId: number): void => {
    try {
      viewport.setPointerCapture(pointerId);
      capturedPointerIds.add(pointerId);
    } catch {
      // Pointer capture can be unavailable when the pointer has already ended.
    }
  };

  const releasePointer = (pointerId: number): void => {
    if (!capturedPointerIds.delete(pointerId)) {
      return;
    }
    try {
      if (viewport.hasPointerCapture(pointerId)) {
        viewport.releasePointerCapture(pointerId);
      }
    } catch {
      // Pointer capture can be unavailable when the viewport has been removed.
    }
  };

  const clearPointerState = (): void => {
    activePointerId = null;
    dragStartPointer = null;
    lastPointer = null;
    touchPointers.clear();
    lastPinchGesture = null;
  };

  const finishPan = (): void => {
    clearPointerState();
    block.removeAttribute('data-mermaid-panning');
    if (block.hasAttribute('data-mermaid-suppress-click')) {
      clearClickSuppressionTimer = window.setTimeout(() => {
        block.removeAttribute('data-mermaid-suppress-click');
        clearClickSuppressionTimer = null;
      }, DRAG_CLICK_SUPPRESSION_CLEAR_MS);
    }
  };

  const onPointerDown = (event: PointerEvent): void => {
    if ((event.pointerType !== 'touch' && event.button !== 0) || isPanExcludedTarget(event.target)) {
      return;
    }
    if (clearClickSuppressionTimer !== null) {
      window.clearTimeout(clearClickSuppressionTimer);
      clearClickSuppressionTimer = null;
    }
    block.removeAttribute('data-mermaid-suppress-click');
    const pointer = getPointerInViewport(event, viewport);
    capturePointer(event.pointerId);
    block.setAttribute('data-mermaid-panning', 'true');

    if (event.pointerType === 'touch') {
      touchPointers.set(event.pointerId, pointer);
      if (touchPointers.size >= 2) {
        activePointerId = null;
        dragStartPointer = null;
        lastPointer = null;
        lastPinchGesture = getMermaidPinchGesture(touchPointers.values());
        block.setAttribute('data-mermaid-suppress-click', 'true');
      } else {
        activePointerId = event.pointerId;
        dragStartPointer = pointer;
        lastPointer = pointer;
      }
    } else {
      activePointerId = event.pointerId;
      dragStartPointer = pointer;
      lastPointer = pointer;
    }
    event.preventDefault();
  };

  const onPointerMove = (event: PointerEvent): void => {
    if (event.pointerType === 'touch') {
      if (!touchPointers.has(event.pointerId)) {
        return;
      }
      const pointer = getPointerInViewport(event, viewport);
      touchPointers.set(event.pointerId, pointer);
      if (touchPointers.size >= 2) {
        const gesture = getMermaidPinchGesture(touchPointers.values());
        if (lastPinchGesture && gesture) {
          applyViewBox(pinchMermaidViewBox({
            currentBox,
            contentBox,
            viewport: getViewportSize(viewport),
            previousGesture: lastPinchGesture,
            gesture,
            minScale: MIN_SCALE,
            maxScale: MAX_SCALE,
          }));
        }
        lastPinchGesture = gesture;
        block.setAttribute('data-mermaid-suppress-click', 'true');
        event.preventDefault();
        return;
      }
    }

    if (activePointerId !== event.pointerId || !lastPointer) {
      return;
    }
    const nextPointer = getPointerInViewport(event, viewport);
    applyViewBox(panMermaidViewBox({
      currentBox,
      viewport: getViewportSize(viewport),
      delta: {
        x: nextPointer.x - lastPointer.x,
        y: nextPointer.y - lastPointer.y,
      },
    }));
    lastPointer = nextPointer;
    if (dragStartPointer && hasMermaidPointerDragMoved(dragStartPointer, nextPointer)) {
      block.setAttribute('data-mermaid-suppress-click', 'true');
    }
    event.preventDefault();
  };

  const stopPan = (event: PointerEvent): void => {
    if (event.pointerType === 'touch' || touchPointers.has(event.pointerId)) {
      if (!touchPointers.has(event.pointerId)) {
        return;
      }
      touchPointers.delete(event.pointerId);
      lastPinchGesture = getMermaidPinchGesture(touchPointers.values());
      if (touchPointers.size > 0) {
        for (const [pointerId, pointer] of touchPointers) {
          activePointerId = pointerId;
          dragStartPointer = pointer;
          lastPointer = pointer;
          break;
        }
        if (touchPointers.size >= 2) {
          activePointerId = null;
          dragStartPointer = null;
          lastPointer = null;
        }
        releasePointer(event.pointerId);
        return;
      }
      finishPan();
      releasePointer(event.pointerId);
      return;
    }

    if (activePointerId !== event.pointerId) {
      return;
    }
    finishPan();
    releasePointer(event.pointerId);
  };

  const onResize = (): void => {
    fit();
  };

  viewport.addEventListener('wheel', onWheel, { passive: false });
  viewport.addEventListener('pointerdown', onPointerDown);
  viewport.addEventListener('pointermove', onPointerMove);
  viewport.addEventListener('pointerup', stopPan);
  viewport.addEventListener('pointercancel', stopPan);
  viewport.addEventListener('lostpointercapture', stopPan);
  window.addEventListener('resize', onResize);
  const observer = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(onResize);
  observer?.observe(viewport);
  fit();

  return {
    zoomIn,
    zoomOut,
    fit,
    cleanup: () => {
      viewport.removeEventListener('wheel', onWheel);
      viewport.removeEventListener('pointerdown', onPointerDown);
      viewport.removeEventListener('pointermove', onPointerMove);
      viewport.removeEventListener('pointerup', stopPan);
      viewport.removeEventListener('pointercancel', stopPan);
      viewport.removeEventListener('lostpointercapture', stopPan);
      window.removeEventListener('resize', onResize);
      observer?.disconnect();
      if (clearClickSuppressionTimer !== null) {
        window.clearTimeout(clearClickSuppressionTimer);
      }
      for (const pointerId of Array.from(capturedPointerIds)) {
        releasePointer(pointerId);
      }
      clearPointerState();
      block.removeAttribute('data-mermaid-panning');
      block.removeAttribute('data-mermaid-suppress-click');
      controllerByBlock.delete(block);
    },
  };
};

export const createMermaidViewerRegistry = (container: HTMLElement): { refresh: () => void; cleanup: () => void } => {
  const controllers = new Map<HTMLElement, MermaidViewerController>();
  const signatures = new Map<HTMLElement, string>();

  const refresh = (): void => {
    for (const [block, controller] of Array.from(controllers.entries())) {
      const signature = getBlockViewerSignature(block);
      if (!container.contains(block) || signature !== signatures.get(block)) {
        controller.cleanup();
        controllers.delete(block);
        signatures.delete(block);
      }
    }

    for (const block of Array.from(container.querySelectorAll<HTMLElement>(MERMAID_BLOCK_SELECTOR))) {
      if (controllers.has(block) || block.querySelector('[data-markdown="mermaid"] svg') === null) {
        continue;
      }
      const controller = createMermaidViewerController(block);
      if (!controller) {
        continue;
      }
      controllers.set(block, controller);
      signatures.set(block, getBlockViewerSignature(block));
      controllerByBlock.set(block, controller);
    }
  };

  const cleanup = (): void => {
    for (const controller of controllers.values()) {
      controller.cleanup();
    }
    controllers.clear();
    signatures.clear();
  };

  refresh();
  return { refresh, cleanup };
};
