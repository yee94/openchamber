import * as React from "react";

type AnyProps = Record<string, unknown>;

function useMergedRefs<T>(first: React.Ref<T> | undefined, second: React.Ref<T> | undefined): React.RefCallback<T> {
  return React.useMemo(() => (value) => {
    for (const ref of [first, second]) {
      if (!ref) continue;
      if (typeof ref === "function") ref(value);
      else (ref as React.MutableRefObject<T | null>).current = value;
    }
  }, [first, second]);
}

function mergeProps(childProps: AnyProps, slotProps: AnyProps): AnyProps {
  const merged: AnyProps = { ...slotProps };
  for (const key in childProps) {
    const slotValue = slotProps[key];
    const childValue = childProps[key];
    if (/^on[A-Z]/.test(key) && typeof slotValue === "function" && typeof childValue === "function") {
      merged[key] = (...args: unknown[]) => {
        (childValue as (...a: unknown[]) => unknown)(...args);
        (slotValue as (...a: unknown[]) => unknown)(...args);
      };
    } else if (key === "className" && typeof slotValue === "string" && typeof childValue === "string") {
      merged[key] = `${childValue} ${slotValue}`;
    } else if (key === "style" && typeof slotValue === "object" && typeof childValue === "object") {
      merged[key] = { ...(childValue as object), ...(slotValue as object) };
    } else {
      merged[key] = childValue;
    }
  }
  return merged;
}

export interface SlotProps extends React.HTMLAttributes<HTMLElement> {
  children?: React.ReactNode;
}

export const Slot = React.forwardRef<HTMLElement, SlotProps>(function Slot(
  { children, ...slotProps },
  ref,
) {
  const child = React.isValidElement(children)
    ? children as React.ReactElement<AnyProps & { ref?: React.Ref<unknown> }>
    : null;
  const childRef = child ? (child as unknown as { ref?: React.Ref<unknown> }).ref : undefined;
  const mergedRefs = useMergedRefs(ref as React.Ref<unknown>, childRef);
  if (!child) return null;
  return React.cloneElement(child, {
    ...mergeProps(child.props as AnyProps, slotProps as AnyProps),
    ref: mergedRefs,
  } as AnyProps);
});
