import React from 'react';

import type { FileDiffMetadata } from '@pierre/diffs';
import { Button } from '@/components/ui/button';
import { Icon } from '@/components/icon/Icon';
import { useRuntimeAPIs } from '@/hooks/useRuntimeAPIs';
import { useI18n } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { extractHunkPatch } from '@/lib/diff/patchFileDiff';

type HunkAction = 'stage' | 'unstage' | 'discard';

interface DiffHunkActionsProps {
  patch: string;
  fileDiff: FileDiffMetadata | undefined;
  directory: string;
  filePath: string;
  staged: boolean;
  onApplied: (action: HunkAction) => void;
}

export const DiffHunkActions = React.memo<DiffHunkActionsProps>(({
  patch,
  fileDiff,
  directory,
  filePath,
  staged,
  onApplied,
}) => {
  const { t } = useI18n();
  const { git } = useRuntimeAPIs();
  const [busyKey, setBusyKey] = React.useState<string | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  const hunks = fileDiff?.hunks;
  if (!hunks || hunks.length === 0 || !patch) {
    return null;
  }

  const run = async (hunkIndex: number, action: HunkAction) => {
    const hunkPatch = extractHunkPatch(patch, hunkIndex);
    if (!hunkPatch) {
      setError(t('diffView.hunk.unavailable'));
      return;
    }

    const key = `${hunkIndex}:${action}`;
    setBusyKey(key);
    setError(null);
    try {
      if (action === 'stage') {
        if (!git.stageGitHunk) throw new Error(t('diffView.hunk.unsupported'));
        await git.stageGitHunk(directory, filePath, hunkPatch);
      } else if (action === 'unstage') {
        if (!git.unstageGitHunk) throw new Error(t('diffView.hunk.unsupported'));
        await git.unstageGitHunk(directory, filePath, hunkPatch);
      } else {
        if (!git.revertGitHunk) throw new Error(t('diffView.hunk.unsupported'));
        await git.revertGitHunk(directory, filePath, hunkPatch);
      }
      onApplied(action);
    } catch (actionError) {
      setError(actionError instanceof Error ? actionError.message : String(actionError));
    } finally {
      setBusyKey((current) => (current === key ? null : current));
    }
  };

  return (
    <div className="flex flex-col gap-1 border-b border-[var(--interactive-border)]/40 bg-[var(--surface-elevated)]/40 px-3 py-1.5">
      <div className="flex items-center gap-1.5 overflow-x-auto">
        <span className="typography-micro shrink-0 text-muted-foreground uppercase">
          {t('diffView.hunk.label')}
        </span>
        {hunks.map((hunk, index) => {
          const additions = hunk.additionLines;
          const deletions = hunk.deletionLines;
          return (
            <div
              key={index}
              className="flex shrink-0 items-center gap-1 rounded-md border border-[var(--interactive-border)]/50 bg-background/60 px-1.5 py-0.5"
            >
              <span className="typography-micro font-semibold text-muted-foreground">
                {String(index + 1).padStart(2, '0')}
              </span>
              {additions > 0 ? (
                <span className="typography-micro" style={{ color: 'var(--status-success)' }}>
                  +{additions}
                </span>
              ) : null}
              {deletions > 0 ? (
                <span className="typography-micro" style={{ color: 'var(--status-error)' }}>
                  −{deletions}
                </span>
              ) : null}
              {staged ? (
                <Button
                  variant="ghost"
                  size="xs"
                  className="h-5 gap-1 px-1.5"
                  disabled={busyKey !== null}
                  onClick={() => void run(index, 'unstage')}
                  title={t('diffView.hunk.unstageTitle', { index: index + 1 })}
                >
                  {busyKey === `${index}:unstage` ? (
                    <Icon name="loader-4" className="size-3 animate-spin" />
                  ) : (
                    <Icon name="arrow-go-back" className="size-3" />
                  )}
                  {t('diffView.hunk.unstage')}
                </Button>
              ) : (
                <>
                  <Button
                    variant="ghost"
                    size="xs"
                    className="h-5 gap-1 px-1.5"
                    disabled={busyKey !== null}
                    onClick={() => void run(index, 'stage')}
                    title={t('diffView.hunk.stageTitle', { index: index + 1 })}
                  >
                    {busyKey === `${index}:stage` ? (
                      <Icon name="loader-4" className="size-3 animate-spin" />
                    ) : (
                      <Icon name="add" className="size-3" />
                    )}
                    {t('diffView.hunk.stage')}
                  </Button>
                  <Button
                    variant="ghost"
                    size="xs"
                    className="h-5 gap-1 px-1.5 text-muted-foreground hover:text-[var(--status-error)]"
                    disabled={busyKey !== null}
                    onClick={() => void run(index, 'discard')}
                    title={t('diffView.hunk.discardTitle', { index: index + 1 })}
                  >
                    {busyKey === `${index}:discard` ? (
                      <Icon name="loader-4" className="size-3 animate-spin" />
                    ) : (
                      <Icon name="close" className="size-3" />
                    )}
                    {t('diffView.hunk.discard')}
                  </Button>
                </>
              )}
            </div>
          );
        })}
      </div>
      {error ? (
        <div className="flex items-center gap-1.5 typography-meta" style={{ color: 'var(--status-error)' }}>
          <Icon name="error-warning" className="size-3.5 shrink-0" />
          <span className={cn('min-w-0')}>{error}</span>
        </div>
      ) : null}
    </div>
  );
});
