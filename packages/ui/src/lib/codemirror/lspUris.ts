import { normalizeFilePath } from '@/lib/path-utils';

const WINDOWS_ABS = /^[A-Za-z]:\//;

export const pathToFileUri = (filePath: string): string => {
  const normalized = normalizeFilePath(filePath);
  if (!normalized) {
    return '';
  }
  if (WINDOWS_ABS.test(normalized)) {
    return `file:///${normalized}`;
  }
  return `file://${normalized}`;
};

export const fileUriToPath = (uri: string): string | null => {
  if (typeof uri !== 'string' || !uri.startsWith('file:')) {
    return null;
  }
  try {
    const parsed = new URL(uri);
    let pathname = decodeURIComponent(parsed.pathname);
    if (/^\/[A-Za-z]:\//.test(pathname)) {
      pathname = pathname.slice(1);
    }
    return normalizeFilePath(pathname);
  } catch {
    return null;
  }
};

export const languageIdForPath = (filePath: string): string | null => {
  const name = filePath.toLowerCase();
  if (name.endsWith('.tsx')) {
    return 'typescriptreact';
  }
  if (name.endsWith('.ts') || name.endsWith('.mts') || name.endsWith('.cts')) {
    return 'typescript';
  }
  if (name.endsWith('.jsx')) {
    return 'javascriptreact';
  }
  if (name.endsWith('.js') || name.endsWith('.mjs') || name.endsWith('.cjs')) {
    return 'javascript';
  }
  return null;
};
