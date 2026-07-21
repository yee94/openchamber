import React from 'react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { Icon } from '@/components/icon/Icon';
import { useI18n } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Props = {
  collapseAllProjects: () => void;
  expandAllProjects: () => void;
  /** Button sizing — match nearby sidebar chrome. */
  buttonClassName?: string;
  iconClassName?: string;
};

/**
 * Project collapse/expand menu (equalizer). Lives on the Recent section header
 * row so the old sidebar action toolbar can stay empty.
 */
export function SidebarDisplayModeMenu({
  collapseAllProjects,
  expandAllProjects,
  buttonClassName,
  iconClassName,
}: Props): React.ReactNode {
  const { t } = useI18n();

  return (
    <DropdownMenu>
      <Tooltip>
        <TooltipTrigger asChild>
          <DropdownMenuTrigger asChild>
            <button
              type="button"
              className={cn(
                'inline-flex h-6 w-6 items-center justify-center rounded-md text-muted-foreground hover:bg-interactive-hover hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/50',
                buttonClassName,
              )}
              aria-label={t('sessions.sidebar.header.actions.sessionDisplayMode')}
              onClick={(event) => {
                event.stopPropagation();
              }}
            >
              <Icon name="equalizer-2" className={cn('h-3.5 w-3.5', iconClassName)} />
            </button>
          </DropdownMenuTrigger>
        </TooltipTrigger>
        <TooltipContent side="bottom" sideOffset={4}>
          <p>{t('sessions.sidebar.header.displayMode.label')}</p>
        </TooltipContent>
      </Tooltip>
      <DropdownMenuContent align="end" className="min-w-[160px]">
        <DropdownMenuItem onClick={collapseAllProjects} className="flex items-center gap-2">
          <Icon name="contract-up-down" className="h-4 w-4" />
          <span>{t('sessions.sidebar.header.displayMode.collapseAll')}</span>
        </DropdownMenuItem>
        <DropdownMenuItem onClick={expandAllProjects} className="flex items-center gap-2">
          <Icon name="expand-up-down" className="h-4 w-4" />
          <span>{t('sessions.sidebar.header.displayMode.expandAll')}</span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
