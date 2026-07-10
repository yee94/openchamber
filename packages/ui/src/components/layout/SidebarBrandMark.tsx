import React from 'react';
import { loadBrandDisplayFont } from '@/lib/fontLoader';

/**
 * Left-sidebar wordmark ("YEE CODE"), rendered above the Recent section.
 *
 * Dual-tone like Codex branding: first name in the surface foreground,
 * surname in the primary accent. Set in Syne (geometric display face) with
 * open tracking so it reads as a mark rather than body UI text.
 *
 * Brand copy is intentional and fixed — not localized.
 */
export const SidebarBrandMark: React.FC = () => {
  React.useEffect(() => {
    void loadBrandDisplayFont();
  }, []);

  return (
    <div className="px-2 pb-2 pt-1">
      <span
        aria-label="YEE CODE"
        className="inline-flex min-w-0 items-baseline gap-[0.28em] truncate"
        style={{
          fontFamily: '"Syne", var(--font-sans, system-ui, sans-serif)',
          fontSize: '1.0625rem',
          fontWeight: 700,
          letterSpacing: '0.08em',
          lineHeight: 1,
        }}
      >
        {/* 前半段：主色前景，对应 Codex 里偏亮的产品名 */}
        <span className="text-foreground">YEE</span>
        {/* 后半段：主题 primary 点缀，对应 Codex 里偏紫的副名 */}
        <span className="text-primary">CODE</span>
      </span>
    </div>
  );
};
