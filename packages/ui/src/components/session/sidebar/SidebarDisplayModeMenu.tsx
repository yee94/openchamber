import React from 'react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { Icon } from '@/components/icon/Icon';
import { useSessionDisplayStore } from '@/stores/useSessionDisplayStore';
import { isVSCodeRuntime } from '@/lib/desktop';
import { useI18n } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Props = {
  showRecentControls: boolean;
  collapseAllProjects: () => void;
  expandAllProjects: () => void;
  /** Button sizing — match nearby sidebar chrome. */
  buttonClassName?: string;
  iconClassName?: string;
};

/**
 * Session list display-mode menu (equalizer). Lives on the Recent section
 * header row so the old sidebar action toolbar can stay empty.
 */
export function SidebarDisplayModeMenu({
  showRecentControls,
  collapseAllProjects,
  expandAllProjects,
  buttonClassName,
  iconClassName,
}: Props): React.ReactNode {
  const { t } = useI18n();
  const displayMode = useSessionDisplayStore((state) => state.displayMode);
  const showRecentSection = useSessionDisplayStore((state) => state.showRecentSection);
  const showArchivedSessions = useSessionDisplayStore((state) => state.showArchivedSessions);
  const setDisplayMode = useSessionDisplayStore((state) => state.setDisplayMode);
  const toggleRecentSection = useSessionDisplayStore((state) => state.toggleRecentSection);
  const toggleArchivedSessions = useSessionDisplayStore((state) => state.toggleArchivedSessions);
  // VS Code forces the expanded layout, so the mode toggle is meaningless there.
  const showDisplayModeToggle = !isVSCodeRuntime();

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
                // Keep the Recent section from toggling when opening the menu.
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
        {showDisplayModeToggle ? (
          <>
            <DropdownMenuItem
              onClick={() => setDisplayMode('default')}
              className="flex items-center justify-between"
            >
              <span>{t('sessions.sidebar.header.displayMode.default')}</span>
              {displayMode === 'default' ? <Icon name="check" className="h-4 w-4 text-primary" /> : null}
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={() => setDisplayMode('minimal')}
              className="flex items-center justify-between"
            >
              <span>{t('sessions.sidebar.header.displayMode.minimal')}</span>
              {displayMode === 'minimal' ? <Icon name="check" className="h-4 w-4 text-primary" /> : null}
            </DropdownMenuItem>
          </>
        ) : null}
        {showRecentControls ? (
          <>
            {showDisplayModeToggle ? <DropdownMenuSeparator /> : null}
            <DropdownMenuItem
              onClick={toggleRecentSection}
              className="flex items-center justify-between"
            >
              <span>{t('sessions.sidebar.header.displayMode.showRecent')}</span>
              {showRecentSection ? <Icon name="check" className="h-4 w-4 text-primary" /> : null}
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={toggleArchivedSessions}
              className="flex items-center justify-between"
            >
              <span>{t('sessions.sidebar.header.displayMode.showArchived')}</span>
              {showArchivedSessions ? <Icon name="check" className="h-4 w-4 text-primary" /> : null}
            </DropdownMenuItem>
          </>
        ) : null}
        <DropdownMenuSeparator />
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
