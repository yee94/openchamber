import type { EditorView } from '@codemirror/view';

import { normalizeFilePath } from '@/lib/path-utils';

const views = new Map<string, EditorView>();
const waiters = new Map<string, Array<(view: EditorView) => void>>();

type OpenFileFn = (path: string) => void;
let openFileHandler: OpenFileFn | null = null;

export const setLspOpenFileHandler = (handler: OpenFileFn | null) => {
  openFileHandler = handler;
};

export const notifyLspEditorReady = (filePath: string, view: EditorView | null) => {
  const key = normalizeFilePath(filePath);
  if (!key) {
    return;
  }
  if (!view) {
    if (views.get(key)) {
      views.delete(key);
    }
    return;
  }
  views.set(key, view);
  const pending = waiters.get(key);
  if (!pending) {
    return;
  }
  waiters.delete(key);
  for (const resolve of pending) {
    resolve(view);
  }
};

export const waitForLspEditor = (filePath: string, timeoutMs = 4000): Promise<EditorView | null> => {
  const key = normalizeFilePath(filePath);
  const existing = views.get(key);
  if (existing) {
    return Promise.resolve(existing);
  }
  openFileHandler?.(key);

  return new Promise((resolve) => {
    const timer = window.setTimeout(() => {
      const queued = waiters.get(key);
      if (queued) {
        waiters.set(key, queued.filter((candidate) => candidate !== onReady));
        if ((waiters.get(key)?.length ?? 0) === 0) {
          waiters.delete(key);
        }
      }
      resolve(views.get(key) ?? null);
    }, timeoutMs);

    const onReady = (view: EditorView) => {
      window.clearTimeout(timer);
      resolve(view);
    };

    const queued = waiters.get(key) ?? [];
    queued.push(onReady);
    waiters.set(key, queued);
  });
};
