import React from 'react';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { Icon } from "@/components/icon/Icon";
import type { GitRemote } from '@/lib/gitApi';
import { useI18n } from '@/lib/i18n';

type SyncAction = 'fetch' | 'pull' | 'push' | 'sync' | null;

interface SyncActionsProps {
  syncAction: SyncAction;
  remotes: GitRemote[];
  onSync: (remote: GitRemote) => void;
  disabled: boolean;
  aheadCount?: number;
  behindCount?: number;
  trackingRemoteName?: string;
  hasUncommittedChanges?: boolean;
}

export const SyncActions: React.FC<SyncActionsProps> = ({
  syncAction,
  remotes = [],
  onSync,
  disabled,
  aheadCount = 0,
  behindCount = 0,
  trackingRemoteName,
  hasUncommittedChanges = false,
}) => {
  const { t } = useI18n();
  const trackingRemote = remotes.find((remote) => remote.name === trackingRemoteName) ?? remotes[0];
  const blocksRebaseSync = behindCount > 0 && hasUncommittedChanges;
  const isPrimaryDisabled = disabled || syncAction !== null || !trackingRemote || blocksRebaseSync;
  const hasKnownSyncWork = aheadCount > 0 || behindCount > 0;
  const syncWorkCount = aheadCount + behindCount;
  const tooltipLabel = blocksRebaseSync
    ? t('gitView.sync.commitOrStashTooltip')
    : trackingRemote
    ? hasKnownSyncWork
      ? t('gitView.sync.syncChangesTooltip', { ahead: aheadCount, behind: behindCount })
      : t('gitView.sync.syncChanges')
    : t('gitView.sync.noRemoteTooltip');

  const handleSync = () => {
    if (!trackingRemote) {
      return;
    }
    onSync(trackingRemote);
  };

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          type="button"
          onClick={handleSync}
          disabled={isPrimaryDisabled}
          className="flex h-6 min-w-6 items-center justify-center gap-0.5 rounded px-1 text-muted-foreground hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--interactive-focus-ring)] disabled:cursor-not-allowed disabled:opacity-50"
          aria-label={t('gitView.sync.syncChanges')}
        >
          {syncAction === 'sync' ? (
            <Icon name="loader-4" className="size-3.5 animate-spin" />
          ) : (
            <Icon name="refresh" className="size-3.5" />
          )}
          {hasKnownSyncWork ? (
            <span aria-hidden="true" className="typography-micro font-medium leading-none tabular-nums">
              {syncWorkCount}
            </span>
          ) : null}
        </button>
      </TooltipTrigger>
      <TooltipContent sideOffset={8}>{tooltipLabel}</TooltipContent>
    </Tooltip>
  );
};
