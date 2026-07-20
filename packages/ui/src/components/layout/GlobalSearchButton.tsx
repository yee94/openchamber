import React from 'react';
import { Icon } from '@/components/icon/Icon';
import { Button } from '@/components/ui/button';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { useI18n } from '@/lib/i18n';
import { formatShortcutForDisplay, getEffectiveShortcutCombo } from '@/lib/shortcuts';
import { cn } from '@/lib/utils';
import { useUIStore } from '@/stores/useUIStore';

interface GlobalSearchButtonProps {
  className?: string;
}

export const GlobalSearchButton: React.FC<GlobalSearchButtonProps> = ({ className }) => {
  const { t } = useI18n();
  const setCommandPaletteOpen = useUIStore((state) => state.setCommandPaletteOpen);
  const shortcutOverrides = useUIStore((state) => state.shortcutOverrides);
  const searchShortcut = formatShortcutForDisplay(
    getEffectiveShortcutCombo('open_command_palette', shortcutOverrides),
  );

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          onClick={() => setCommandPaletteOpen(true)}
          aria-label={t('commandPalette.title')}
          className={cn(
            'app-region-no-drag size-7 rounded-md text-muted-foreground/75 focus-visible:ring-2 focus-visible:ring-primary',
            className,
          )}
        >
          <Icon
            name="search"
            className="size-4 text-foreground/55 transition-colors group-hover:text-foreground group-focus-visible:text-foreground"
          />
        </Button>
      </TooltipTrigger>
      <TooltipContent>
        <p className="flex items-center gap-2">
          <span>{t('commandPalette.title')}</span>
          <span className="text-muted-foreground">{searchShortcut}</span>
        </p>
      </TooltipContent>
    </Tooltip>
  );
};
