import type { FileSearchResult, FilesAPI } from '@/lib/api/types';
import { normalizeFilePath } from '@/lib/path-utils';

import {
  type CodeNavRequest,
  type CodeNavTarget,
  findSameFileDefinitionLine,
  importPathCandidates,
  resolveRelativeImportPath,
  scoreDefinitionPreview,
} from './codeNavigation';

export type CodeNavigationSearch = (query: {
  directory: string;
  query: string;
  maxResults?: number;
  respectGitignore?: boolean;
}) => Promise<FileSearchResult[]>;

type CodeNavigationFiles = {
  statFile?: FilesAPI['statFile'];
  search?: FilesAPI['search'];
};

const fileExists = async (files: CodeNavigationFiles, path: string): Promise<boolean> => {
  if (!files.statFile) {
    return false;
  }
  try {
    const stat = await files.statFile(path);
    return Boolean(stat?.isFile);
  } catch {
    return false;
  }
};

const resolveExistingImport = async (files: CodeNavigationFiles, spec: string, currentFile: string): Promise<string | null> => {
  const resolved = resolveRelativeImportPath(currentFile, spec);
  if (!resolved) {
    return null;
  }
  for (const candidate of importPathCandidates(resolved)) {
    if (await fileExists(files, candidate)) {
      return candidate;
    }
  }
  return null;
};

const fileNameStem = (path: string): string => {
  const name = path.replace(/\\/g, '/').split('/').pop() ?? path;
  return name.replace(/\.[^.]+$/, '');
};

const pickSearchTarget = (
  request: CodeNavRequest,
  hits: FileSearchResult[],
  currentFile: string,
): CodeNavTarget | null => {
  const current = normalizeFilePath(currentFile);
  const ranked = hits
    .map((hit) => {
      const stem = fileNameStem(hit.path);
      let score = scoreDefinitionPreview(request.text, hit.preview);
      if (stem === request.text) {
        score += 3;
      } else if (stem.includes(request.text)) {
        score += 1;
      }
      if (normalizeFilePath(hit.path) === current) {
        score -= 1;
      }
      return { hit, score };
    })
    .filter((entry) => entry.score > 0)
    .sort((left, right) => right.score - left.score);

  const best = ranked[0]?.hit;
  if (!best) {
    return null;
  }
  const previewLine = best.preview?.findIndex((line) => scoreDefinitionPreview(request.text, [line]) > 0) ?? -1;
  return {
    path: best.path,
    line: previewLine >= 0 ? previewLine + 1 : 1,
  };
};

export const resolveCodeNavigation = async (
  request: CodeNavRequest,
  options: {
    files: CodeNavigationFiles;
    searchFiles?: CodeNavigationSearch;
    directory: string;
    currentContent: string;
  },
): Promise<CodeNavTarget | null> => {
  if (request.kind === 'import-path') {
    const existing = await resolveExistingImport(options.files, request.text, request.filePath);
    if (existing) {
      return { path: existing, line: 1 };
    }
    return null;
  }

  const sameFileLine = findSameFileDefinitionLine(options.currentContent, request.text, request.line);
  if (sameFileLine) {
    return { path: request.filePath, line: sameFileLine };
  }

  if (!options.searchFiles || !options.directory) {
    return null;
  }

  try {
    const hits = await options.searchFiles({
      directory: options.directory,
      query: request.text,
      maxResults: 20,
      respectGitignore: true,
    });
    return pickSearchTarget(request, hits, request.filePath);
  } catch {
    return null;
  }
};
