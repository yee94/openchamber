import React from 'react';
import { Button } from '@/components/ui/button';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { Icon } from '@/components/icon/Icon';
import { useI18n } from '@/lib/i18n';

type Props = {
  onOpenSettings: () => void;
  onOpenShortcuts: () => void;
  onOpenUpdate?: () => void;
  showRuntimeButtons?: boolean;
  showUpdateButton?: boolean;
};

const iconButtonClassName = 'size-8 text-muted-foreground hover:bg-[var(--interactive-hover)]/50 hover:text-foreground';

export function SidebarFooter({
  onOpenSettings,
  onOpenShortcuts,
  onOpenUpdate,
  showRuntimeButtons = true,
  showUpdateButton = false,
}: Props): React.ReactNode {
  const { t } = useI18n();

  return (
    <div className="flex shrink-0 items-center gap-1 px-2.5 py-2">
      {showRuntimeButtons ? (
        <>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className={iconButtonClassName}
                onClick={onOpenSettings}
                aria-label={t('sessions.sidebar.footer.actions.settings')}
              >
                <Icon name="settings-3" className="size-4.5" />
              </Button>
            </TooltipTrigger>
            <TooltipContent side="top" sideOffset={4}>{t('sessions.sidebar.footer.actions.settings')}</TooltipContent>
          </Tooltip>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className={iconButtonClassName}
                onClick={onOpenShortcuts}
                aria-label={t('sessions.sidebar.footer.actions.shortcuts')}
              >
                <Icon name="question" className="size-4.5" />
              </Button>
            </TooltipTrigger>
            <TooltipContent side="top" sideOffset={4}>{t('sessions.sidebar.footer.actions.shortcuts')}</TooltipContent>
          </Tooltip>
        </>
      ) : null}
      {showUpdateButton && onOpenUpdate ? (
        <Button
          type="button"
          variant="default"
          size="xs"
          className="ml-auto"
          onClick={onOpenUpdate}
        >
          {t('sessions.sidebar.footer.actions.update')}
        </Button>
      ) : null}
    </div>
  );
}
