import React from 'react';
import { Button } from '@/components/ui/button';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { Icon } from "@/components/icon/Icon";
import { useI18n } from '@/lib/i18n';

interface WorktreeBranchDisplayProps {
  currentBranch: string | null | undefined;
  onRename?: (oldName: string, newName: string) => Promise<void>;
  showEditButton?: boolean;
  /** Icon-only trigger; branch name shown in tooltip. */
  iconOnly?: boolean;
}

const sanitizeBranchNameInput = (value: string): string => {
  return value
    .trim()
    .replace(/\s+/g, '-')
    .replace(/[^A-Za-z0-9._/-]/g, '-')
    .replace(/-+/g, '-')
    .replace(/\/{2,}/g, '/')
    .replace(/\/-+/g, '/')
    .replace(/-+\//g, '/')
    .replace(/^[-/]+/, '')
    .replace(/[-/]+$/, '');
};

export const WorktreeBranchDisplay: React.FC<WorktreeBranchDisplayProps> = ({
  currentBranch,
  onRename,
  showEditButton = true,
  iconOnly = false,
}) => {
  const { t } = useI18n();
  const [isEditing, setIsEditing] = React.useState(false);
  const [editBranchName, setEditBranchName] = React.useState(currentBranch || '');
  const [isRenaming, setIsRenaming] = React.useState(false);
  const inputRef = React.useRef<HTMLInputElement>(null);

  const handleStartEdit = () => {
    if (!currentBranch || !onRename) return;
    setEditBranchName(currentBranch);
    setIsEditing(true);
    // Focus input after state update
    setTimeout(() => inputRef.current?.focus(), 0);
  };

  const handleSaveEdit = async () => {
    if (!currentBranch || !onRename || !editBranchName.trim()) return;
    
    const sanitizedName = sanitizeBranchNameInput(editBranchName);
    if (sanitizedName === currentBranch) {
      setIsEditing(false);
      return;
    }

    setIsRenaming(true);
    try {
      await onRename(currentBranch, sanitizedName);
      setIsEditing(false);
      setEditBranchName('');
    } finally {
      setIsRenaming(false);
    }
  };

  const handleCancelEdit = () => {
    setIsEditing(false);
    setEditBranchName('');
  };

  // Handle Enter key to save, Escape to cancel
  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleSaveEdit();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      handleCancelEdit();
    }
  };

  if (isEditing) {
    return (
      <div className="flex h-6 items-center gap-1.5 rounded-md bg-primary/12 px-1.5">
        <form
          className="flex w-full items-center gap-1.5"
          onSubmit={(e) => {
            e.preventDefault();
            handleSaveEdit();
          }}
        >
          <Icon name="git-branch" className="size-3.5 text-primary" />
          <input
            ref={inputRef}
            value={editBranchName}
            onChange={(e) => setEditBranchName(e.target.value)}
            className="flex-1 min-w-0 bg-transparent typography-ui-label outline-none placeholder:text-muted-foreground"
            placeholder={t('gitView.branch.namePlaceholder')}
            onKeyDown={handleKeyDown}
            autoFocus
          />
          <button
            type="submit"
            disabled={isRenaming}
            aria-label={isRenaming ? t('gitView.branch.renameSaving') : t('gitView.branch.renameSave')}
            title={isRenaming ? t('gitView.branch.renameSaving') : t('gitView.branch.renameSave')}
            className="shrink-0 text-muted-foreground hover:text-foreground disabled:opacity-50"
          >
            {isRenaming ? (
              <Icon name="loader-4" className="size-3.5 animate-spin" />
            ) : (
              <Icon name="check" className="size-3.5" />
            )}
          </button>
          <button
            type="button"
            onClick={handleCancelEdit}
            disabled={isRenaming}
            aria-label={t('gitView.branch.renameCancel')}
            title={t('gitView.branch.renameCancel')}
            className="shrink-0 text-muted-foreground hover:text-foreground disabled:opacity-50"
          >
            <Icon name="close" className="size-3.5" />
          </button>
        </form>
      </div>
    );
  }

  const branchLabel = currentBranch || t('gitView.branch.detachedHead');

  if (iconOnly) {
    return (
      <Tooltip>
        <TooltipTrigger asChild>
          <button
            type="button"
            className="flex size-6 items-center justify-center rounded text-muted-foreground hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--interactive-focus-ring)] disabled:cursor-not-allowed disabled:opacity-50"
            onClick={handleStartEdit}
            disabled={!currentBranch || !onRename}
            aria-label={branchLabel}
          >
            <Icon name="git-branch" className="size-3.5" />
          </button>
        </TooltipTrigger>
        <TooltipContent sideOffset={8}>{branchLabel}</TooltipContent>
      </Tooltip>
    );
  }

  return (
    <div className="flex h-6 w-full min-w-0 items-center gap-1 px-0">
      <Icon name="git-branch" className="size-3.5 text-primary shrink-0" />
      <div className="inline-flex min-w-0 max-w-full items-center gap-1">
        <span className="truncate typography-ui-label font-semibold text-foreground">
          {branchLabel}
        </span>
        {showEditButton && onRename && currentBranch && (
          <Button
            variant="ghost"
            size="xs"
            className="size-6 p-0 shrink-0"
            onClick={handleStartEdit}
            title={t('gitView.branch.renameTitle')}
          >
            <Icon name="edit" className="size-3.5" />
          </Button>
        )}
      </div>
    </div>
  );
};
