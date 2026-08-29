import React from 'react';

import type { FileGitDecoration, FolderGitBadge } from '@/lib/files/fileGitDecorations';
import { cn } from '@/lib/utils';

const CODE_CLASS: Record<FileGitDecoration['code'], string> = {
  M: 'text-[var(--status-warning)]',
  A: 'text-[var(--status-success)]',
  '?': 'text-[var(--status-info)]',
  D: 'text-[var(--status-error)]',
  R: 'text-[var(--status-info)]',
  C: 'text-[var(--status-info)]',
};

export const FileGitStatusMark: React.FC<{
  decoration: FileGitDecoration;
  label: string;
}> = ({ decoration, label }) => (
  <span
    className={cn(
      'w-3.5 shrink-0 text-center typography-code font-semibold uppercase',
      CODE_CLASS[decoration.code],
    )}
    title={label}
    aria-label={label}
  >
    {decoration.code}
  </span>
);

export const FileGitFolderBadge: React.FC<{
  badge: FolderGitBadge;
}> = ({ badge }) => (
  <span className="ml-auto mr-1 flex items-center gap-1 text-xs typography-code">
    {badge.modified > 0 && (
      <span className="text-[var(--status-warning)]">M{badge.modified}</span>
    )}
    {badge.added > 0 && (
      <span className="text-[var(--status-success)]">+{badge.added}</span>
    )}
    {badge.deleted > 0 && (
      <span className="text-[var(--status-error)]">D{badge.deleted}</span>
    )}
  </span>
);
