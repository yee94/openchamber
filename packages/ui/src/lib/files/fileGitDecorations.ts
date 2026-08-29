import { getRelativeFilePath, normalizeFilePath } from '@/lib/path-utils';

export type GitStatusFileLike = {
  path: string;
  index: string;
  working_dir: string;
};

export type FileGitKind = 'modified' | 'added' | 'untracked' | 'deleted' | 'renamed' | 'copied';

export type FileGitDecoration = {
  kind: FileGitKind;
  code: 'M' | 'A' | '?' | 'D' | 'R' | 'C';
};

export type FolderGitBadge = {
  modified: number;
  added: number;
  deleted: number;
};

export type FileTreeEntry = {
  name: string;
  path: string;
  type: 'file' | 'directory';
  extension?: string;
  relativePath?: string;
  ghost?: boolean;
};

export type FileGitDecorationIndex = {
  byRelativePath: Map<string, FileGitDecoration>;
  byAbsolutePath: Map<string, FileGitDecoration>;
  badgeByDir: Map<string, FolderGitBadge>;
};

const KIND_BY_CODE: Record<FileGitDecoration['code'], FileGitKind> = {
  M: 'modified',
  A: 'added',
  '?': 'untracked',
  D: 'deleted',
  R: 'renamed',
  C: 'copied',
};

export type FileGitStatusLabelKey =
  | 'files.tree.status.modified'
  | 'files.tree.status.added'
  | 'files.tree.status.untracked'
  | 'files.tree.status.deleted'
  | 'files.tree.status.renamed'
  | 'files.tree.status.copied';

const STATUS_LABEL_KEY: Record<FileGitKind, FileGitStatusLabelKey> = {
  modified: 'files.tree.status.modified',
  added: 'files.tree.status.added',
  untracked: 'files.tree.status.untracked',
  deleted: 'files.tree.status.deleted',
  renamed: 'files.tree.status.renamed',
  copied: 'files.tree.status.copied',
};

const EMPTY_INDEX: FileGitDecorationIndex = {
  byRelativePath: new Map(),
  byAbsolutePath: new Map(),
  badgeByDir: new Map(),
};

const firstStatusCode = (value: string | undefined): string => {
  const trimmed = value?.trim() ?? '';
  return trimmed ? trimmed.charAt(0) : '';
};

export const fileGitStatusLabelKey = (kind: FileGitKind): FileGitStatusLabelKey => STATUS_LABEL_KEY[kind];

export const fileGitNameClassName = (decoration: FileGitDecoration | null | undefined, ghost = false): string => {
  const classes: string[] = [];
  if (ghost || decoration?.kind === 'deleted') {
    classes.push('line-through');
  }
  switch (decoration?.kind) {
    case 'modified':
    case 'renamed':
    case 'copied':
      classes.push('text-[var(--status-warning)]');
      break;
    case 'added':
    case 'untracked':
      classes.push('text-[var(--status-success)]');
      break;
    case 'deleted':
      classes.push('text-[var(--status-error)]');
      break;
    default:
      break;
  }
  return classes.join(' ');
};

export const classifyGitStatusFile = (file: GitStatusFileLike): FileGitDecoration | null => {
  const indexCode = firstStatusCode(file.index);
  const workingCode = firstStatusCode(file.working_dir);
  const codes = [indexCode, workingCode].filter((code) => code && code !== ' ');
  if (codes.length === 0) {
    return null;
  }

  const pick = (code: string): FileGitDecoration['code'] | null => {
    if (code === 'D') return 'D';
    if (code === 'R') return 'R';
    if (code === 'C') return 'C';
    if (code === 'A') return 'A';
    if (code === '?') return '?';
    if (code === 'M') return 'M';
    return null;
  };

  const ranked: FileGitDecoration['code'][] = [];
  for (const code of codes) {
    const mapped = pick(code);
    if (mapped && !ranked.includes(mapped)) {
      ranked.push(mapped);
    }
  }

  const selected = ranked.find((code) => code === 'D')
    ?? ranked.find((code) => code === 'R')
    ?? ranked.find((code) => code === 'A' || code === '?')
    ?? ranked.find((code) => code === 'C')
    ?? ranked[0];
  if (!selected) {
    return null;
  }

  return { kind: KIND_BY_CODE[selected], code: selected };
};

const joinPath = (root: string, relative: string): string => {
  const normalizedRoot = normalizeFilePath(root);
  const normalizedRelative = relative.replace(/\\/g, '/').replace(/^\/+/, '');
  if (!normalizedRoot) {
    return normalizeFilePath(normalizedRelative);
  }
  if (!normalizedRelative) {
    return normalizedRoot;
  }
  return normalizeFilePath(`${normalizedRoot}/${normalizedRelative}`);
};

const fileExtension = (name: string): string | undefined => {
  const lastDot = name.lastIndexOf('.');
  if (lastDot <= 0 || lastDot === name.length - 1) {
    return undefined;
  }
  return name.slice(lastDot + 1).toLowerCase();
};

export const buildFileGitDecorationIndex = (
  files: readonly GitStatusFileLike[] | undefined,
  root: string,
): FileGitDecorationIndex => {
  if (!files?.length || !root) {
    return EMPTY_INDEX;
  }

  const byRelativePath = new Map<string, FileGitDecoration>();
  const byAbsolutePath = new Map<string, FileGitDecoration>();
  const badgeByDir = new Map<string, FolderGitBadge>();
  const normalizedRoot = normalizeFilePath(root);

  for (const file of files) {
    const decoration = classifyGitStatusFile(file);
    if (!decoration) {
      continue;
    }
    const relative = file.path.replace(/\\/g, '/').replace(/^\/+/, '');
    if (!relative) {
      continue;
    }
    byRelativePath.set(relative, decoration);
    byAbsolutePath.set(joinPath(normalizedRoot, relative), decoration);

    const segments = relative.split('/').filter(Boolean);
    if (segments.length <= 1) {
      continue;
    }

    let currentDir = normalizedRoot;
    for (let index = 0; index < segments.length - 1; index += 1) {
      currentDir = joinPath(currentDir, segments[index] ?? '');
      let badge = badgeByDir.get(currentDir);
      if (!badge) {
        badge = { modified: 0, added: 0, deleted: 0 };
        badgeByDir.set(currentDir, badge);
      }
      if (decoration.kind === 'deleted') {
        badge.deleted += 1;
      } else if (decoration.kind === 'added' || decoration.kind === 'untracked') {
        badge.added += 1;
      } else {
        badge.modified += 1;
      }
    }
  }

  return { byRelativePath, byAbsolutePath, badgeByDir };
};

export const lookupFileGitDecoration = (
  index: FileGitDecorationIndex,
  path: string,
  root: string,
): FileGitDecoration | null => {
  if (index.byAbsolutePath.size === 0) {
    return null;
  }
  const absolute = normalizeFilePath(path);
  const fromAbsolute = index.byAbsolutePath.get(absolute);
  if (fromAbsolute) {
    return fromAbsolute;
  }
  const relative = getRelativeFilePath(absolute, root);
  if (!relative || relative === '.' || relative === absolute) {
    return index.byRelativePath.get(path.replace(/\\/g, '/')) ?? null;
  }
  return index.byRelativePath.get(relative) ?? null;
};

export const lookupFolderGitBadge = (
  index: FileGitDecorationIndex,
  directoryPath: string,
): FolderGitBadge | null => {
  const badge = index.badgeByDir.get(normalizeFilePath(directoryPath));
  if (!badge) {
    return null;
  }
  if (badge.modified + badge.added + badge.deleted <= 0) {
    return null;
  }
  return badge;
};

const isDeletedDecoration = (decoration: FileGitDecoration | null): boolean => decoration?.kind === 'deleted';

export const ghostChildrenForDirectory = (
  directoryPath: string,
  root: string,
  files: readonly GitStatusFileLike[] | undefined,
): FileTreeEntry[] => {
  if (!files?.length || !root) {
    return [];
  }

  const normalizedDir = normalizeFilePath(directoryPath);
  const normalizedRoot = normalizeFilePath(root);
  const seen = new Set<string>();
  const nodes: FileTreeEntry[] = [];

  for (const file of files) {
    if (!isDeletedDecoration(classifyGitStatusFile(file))) {
      continue;
    }
    const absolute = joinPath(normalizedRoot, file.path);
    if (absolute === normalizedDir || !absolute.startsWith(`${normalizedDir}/`)) {
      continue;
    }
    const remainder = absolute.slice(normalizedDir.length + 1);
    const firstSegment = remainder.split('/')[0];
    if (!firstSegment || seen.has(firstSegment)) {
      continue;
    }
    seen.add(firstSegment);
    const childPath = joinPath(normalizedDir, firstSegment);
    const isFile = !remainder.includes('/');
    nodes.push({
      name: firstSegment,
      path: childPath,
      type: isFile ? 'file' : 'directory',
      extension: isFile ? fileExtension(firstSegment) : undefined,
      ghost: true,
    });
  }

  return nodes.sort((left, right) => {
    if (left.type !== right.type) {
      return left.type === 'directory' ? -1 : 1;
    }
    return left.name.localeCompare(right.name);
  });
};

export const mergeDirectoryGhostNodes = (
  children: readonly FileTreeEntry[],
  directoryPath: string,
  root: string,
  files: readonly GitStatusFileLike[] | undefined,
): FileTreeEntry[] => {
  const ghosts = ghostChildrenForDirectory(directoryPath, root, files);
  if (ghosts.length === 0) {
    return children as FileTreeEntry[];
  }

  const existing = new Set(children.map((node) => normalizeFilePath(node.path)));
  const extras = ghosts.filter((node) => !existing.has(normalizeFilePath(node.path)));
  if (extras.length === 0) {
    return children as FileTreeEntry[];
  }

  return [...children, ...extras].sort((left, right) => {
    if (left.type !== right.type) {
      return left.type === 'directory' ? -1 : 1;
    }
    return left.name.localeCompare(right.name);
  });
};

export const decorateFileTreeChildren = (
  childrenByDir: Record<string, FileTreeEntry[]>,
  root: string,
  files: readonly GitStatusFileLike[] | undefined,
): Record<string, FileTreeEntry[]> => {
  if (!files?.length || !root) {
    return childrenByDir;
  }

  let changed = false;
  const next: Record<string, FileTreeEntry[]> = {};
  for (const [directory, children] of Object.entries(childrenByDir)) {
    const merged = mergeDirectoryGhostNodes(children, directory, root, files);
    next[directory] = merged;
    if (merged !== children) {
      changed = true;
    }
  }

  return changed ? next : childrenByDir;
};

export const isGhostDirectory = (node: Pick<FileTreeEntry, 'type' | 'ghost'>): boolean => (
  node.type === 'directory' && node.ghost === true
);
