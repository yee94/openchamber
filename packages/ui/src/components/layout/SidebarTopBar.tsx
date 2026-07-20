import React from 'react';
import { Button } from '@/components/ui/button';
import { Icon } from '@/components/icon/Icon';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { useUIStore } from '@/stores/useUIStore';
import { useI18n } from '@/lib/i18n';
import { formatShortcutForDisplay, getEffectiveShortcutCombo } from '@/lib/shortcuts';

/**
 * Strip at the top of the desktop left sidebar that reserves room for the
 * persistent {@link TitlebarLeftControls} overlay and owns the global-search
 * action at the opposite edge. Its height tracks the header via
 * `--oc-header-height`.
 *
 * Split into three regions so the strip stays a window drag area while the
 * overlay buttons remain clickable: a `no-drag` carve matching the overlay
 * footprint (the overlay sits on top of it; an OS drag region here would steal
 * the buttons' clicks, since a separate-subtree `no-drag` can't carve a drag
 * region in Electron/macOS), a `drag` remainder for window dragging, and a
 * dedicated `no-drag` search control.
 */
export const SidebarTopBar: React.FC = () => {
  const { t } = useI18n();
  const setCommandPaletteOpen = useUIStore((state) => state.setCommandPaletteOpen);
  const shortcutOverrides = useUIStore((state) => state.shortcutOverrides);
  const searchShortcut = formatShortcutForDisplay(
    getEffectiveShortcutCombo('open_command_palette', shortcutOverrides),
  );

  return (
    <div
      className="flex shrink-0"
      style={{ height: 'var(--oc-header-height, 3rem)' }}
    >
      {/* Drag region for the window-controls inset (traffic lights). */}
      <div
        aria-hidden
        className="app-region-drag shrink-0"
        style={{ width: 'var(--oc-titlebar-left-inset, 0.75rem)' }}
      />
      {/* No-drag carve under the overlay buttons so they stay clickable. */}
      <div
        aria-hidden
        className="app-region-no-drag shrink-0"
        style={{ width: 'calc(var(--oc-titlebar-controls-width, 5.5rem) + 0.5rem)' }}
      />
      {/* Draggable remainder of the strip. */}
      <div aria-hidden className="app-region-drag flex-1" />
      <div className="app-region-no-drag flex shrink-0 items-center pr-2">
        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setCommandPaletteOpen(true)}
              aria-label={t('commandPalette.title')}
              className="text-muted-foreground hover:text-foreground"
            >
              <Icon name="search" className="size-4" />
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <p className="flex items-center gap-2">
              <span>{t('commandPalette.title')}</span>
              <span className="text-muted-foreground">{searchShortcut}</span>
            </p>
          </TooltipContent>
        </Tooltip>
      </div>
    </div>
  );
};
