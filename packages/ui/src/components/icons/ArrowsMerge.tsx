import type { SVGProps } from 'react';

import { ICON_STROKE_WIDTH } from '@/components/icon/Icon';

/**
 * Multi-run affordance — Lucide `merge` geometry, rotated to match the previous
 * Phosphor arrows-merge orientation (two streams converging downward).
 */
export function ArrowsMerge(props: SVGProps<SVGSVGElement>) {
  const { className, strokeWidth = ICON_STROKE_WIDTH, ...rest } = props;
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className={['oc-icon', className].filter(Boolean).join(' ')}
      {...rest}
    >
      <g transform="rotate(180 12 12)">
        <path d="m8 6 4-4 4 4" />
        <path d="M12 2v10.3a4 4 0 0 1-1.172 2.872L4 22" />
        <path d="m20 22-5-5" />
      </g>
    </svg>
  );
}
