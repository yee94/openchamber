import MarkdownShikiWorkerUrl from './markdown-shiki.worker.ts?worker&url';
import type {
  MarkdownTokenRun,
  MarkdownWorkerJobRequest,
  MarkdownWorkerPriority,
  MarkdownWorkerRequest,
  MarkdownWorkerResponse,
} from './markdown-worker-protocol';

// Main-thread client for the markdown Shiki worker. Moves syntax tokenization
// off the UI thread: a closed code block is shipped to the worker, which returns
// ready-to-splice Shiki HTML. On any failure (no worker support, worker crash,
// tokenization error) the promise resolves to `null` and the caller keeps the
// escaped plain-text code — highlighting never falls back onto the main thread.

type MarkdownWorkerRequestOptions = {
  signal?: AbortSignal;
  priority?: MarkdownWorkerPriority;
};

type PendingRequest = {
  resolve: (response: MarkdownWorkerResponse | null) => void;
  signal?: AbortSignal;
  onAbort?: () => void;
};

let worker: Worker | undefined;
let nextId = 0;
const pending = new Map<number, PendingRequest>();
// Theme names whose full definition we've already shipped to the live worker, so
// repeat tokenization sends only the name (not the whole theme object) again.
const sentThemes = new Set<string>();

const settlePending = (id: number, response: MarkdownWorkerResponse | null): void => {
  const request = pending.get(id);
  if (!request) return;
  pending.delete(id);
  if (request.signal && request.onAbort) {
    request.signal.removeEventListener('abort', request.onAbort);
  }
  request.resolve(response);
};

const failAll = (): void => {
  for (const id of Array.from(pending.keys())) {
    settlePending(id, null);
  }
  sentThemes.clear();
  worker?.terminate();
  worker = undefined;
};

const getWorker = (): Worker | undefined => {
  if (worker) return worker;
  if (typeof window === 'undefined' || typeof Worker === 'undefined') return undefined;
  try {
    worker = new Worker(MarkdownShikiWorkerUrl, { type: 'module' });
  } catch (err) {
    console.error('Failed to create Shiki worker:', err);
    return undefined;
  }
  worker.onmessage = (event: MessageEvent<MarkdownWorkerResponse>) => {
    settlePending(event.data.id, event.data);
  };
  worker.onerror = failAll;
  worker.onmessageerror = failAll;
  worker.postMessage({ type: 'init' } satisfies MarkdownWorkerRequest);
  return worker;
};

const request = (
  payload: (id: number, priority: MarkdownWorkerPriority) => MarkdownWorkerJobRequest,
  options?: MarkdownWorkerRequestOptions,
): Promise<MarkdownWorkerResponse | null> => {
  if (options?.signal?.aborted) return Promise.resolve(null);
  const instance = getWorker();
  if (!instance) return Promise.resolve(null);
  const id = ++nextId;
  const priority = options?.priority ?? 'visible';
  return new Promise<MarkdownWorkerResponse | null>((resolve) => {
    const signal = options?.signal;
    const onAbort = () => {
      if (!pending.has(id)) return;
      settlePending(id, null);
      try {
        instance.postMessage({ type: 'cancel', id } satisfies MarkdownWorkerRequest);
      } catch {
        // A worker failure races through failAll; the request is already settled.
      }
    };
    pending.set(id, { resolve, signal, onAbort });
    signal?.addEventListener('abort', onAbort, { once: true });
    if (signal?.aborted) {
      onAbort();
      return;
    }
    try {
      instance.postMessage(payload(id, priority));
    } catch {
      settlePending(id, null);
    }
  });
};

/**
 * Highlight a complete code block in the worker. Resolves to Shiki `<pre>` HTML,
 * or `null` if highlighting is unavailable or failed (caller keeps plain code).
 */
export const highlightCodeInWorker = async (
  code: string,
  lang: string,
  options?: MarkdownWorkerRequestOptions,
): Promise<string | null> => {
  const response = await request((id, priority) => ({ type: 'highlight', id, code, lang, priority }), options);
  return response?.type === 'highlight' ? response.html : null;
};

/**
 * Highlight a whole block and return per-line inner HTML (one entry per source
 * line). For per-line layouts (diffs, gutters, virtualization) — one worker
 * round-trip instead of one per line. Resolves to `null` on failure.
 */
export const highlightLinesInWorker = async (
  code: string,
  lang: string,
  options?: MarkdownWorkerRequestOptions,
): Promise<string[] | null> => {
  const response = await request((id, priority) => ({ type: 'highlightLines', id, code, lang, priority }), options);
  return response?.type === 'highlightLines' ? response.lines : null;
};

/**
 * Tokenize `code` with the given resolved TextMate theme and return per-line
 * styled runs with offsets — for building CodeMirror decorations that match the
 * Shiki file view exactly. The full theme object is shipped only the first time
 * a theme name is seen by the live worker. Resolves to `null` on failure.
 */
export const highlightTokensInWorker = async (
  code: string,
  lang: string,
  themeName: string,
  theme: unknown,
  options?: MarkdownWorkerRequestOptions,
): Promise<MarkdownTokenRun[][] | null> => {
  const needsTheme = !sentThemes.has(themeName);
  const response = await request((id, priority) => ({
    type: 'highlightTokens',
    id,
    code,
    lang,
    themeName,
    priority,
    ...(needsTheme ? { theme } : {}),
  }), options);
  if (response?.type === 'highlightTokens') {
    sentThemes.add(themeName);
    return response.lines;
  }
  return null;
};
