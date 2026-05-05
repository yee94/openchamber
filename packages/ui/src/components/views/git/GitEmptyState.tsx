import React from 'react';
import { RiGitCommitLine, RiRefreshLine, RiLoader4Line } from '@remixicon/react';
import { Button } from '@/components/ui/button';
import { useI18n } from '@/lib/i18n';

interface GitEmptyStateProps {
  ahead: number;
  behind: number;
  onSync: () => void;
  isSyncing: boolean;
}

export const GitEmptyState: React.FC<GitEmptyStateProps> = ({
  ahead,
  behind,
  onSync,
  isSyncing,
}) => {
  const { t } = useI18n();
  const hasSyncChanges = ahead > 0 || behind > 0;
  return (
    <div className="flex flex-col items-center justify-center py-10 px-4 text-center">
      <RiGitCommitLine className="size-10 text-muted-foreground/70 mb-4" />
      <p className="typography-ui-label font-semibold text-foreground mb-1">
        {t('gitView.empty.cleanTitle')}
      </p>
      <p className="typography-meta text-muted-foreground mb-4">
        {t('gitView.empty.cleanDescription')}
      </p>

      {hasSyncChanges && (
        <Button
          variant="default"
          onClick={onSync}
          disabled={isSyncing}
        >
          {isSyncing ? (
            <RiLoader4Line className="size-4 animate-spin" />
          ) : (
            <RiRefreshLine className="size-4" />
          )}
          {t('gitView.sync.syncCounts', { ahead, behind })}
        </Button>
      )}
    </div>
  );
};
