/// <reference lib="webworker" />

import { bundledLanguages, createHighlighter, type BundledLanguage } from 'shiki';
import { MARKDOWN_SHIKI_THEME, MARKDOWN_SHIKI_THEME_DEFINITION } from './markdownShikiThemeDefinition';
import type { MarkdownWorkerRequest, MarkdownWorkerResponse } from './markdown-worker-protocol';

// Single shared highlighter for the worker. Languages load lazily on demand.
let highlighter: ReturnType<typeof createHighlighter> | undefined;

// Serialize work so language loading / tokenization never overlaps.
let queue = Promise.resolve();

const ensureHighlighter = (): ReturnType<typeof createHighlighter> => {
  highlighter ??= createHighlighter({
    // Cast: the theme is a CSS-variable TextMate theme; Shiki accepts the shape.
    themes: [MARKDOWN_SHIKI_THEME_DEFINITION as unknown as Parameters<typeof createHighlighter>[0]['themes'][number]],
    langs: [],
  });
  return highlighter;
};

self.onmessage = (event: MessageEvent<MarkdownWorkerRequest>) => {
  const request = event.data;
  if (request.type === 'init') {
    ensureHighlighter();
    return;
  }
  queue = queue.then(() => highlight(request)).catch(() => {});
};

async function highlight(request: Extract<MarkdownWorkerRequest, { type: 'highlight' }>): Promise<void> {
  try {
    const instance = await ensureHighlighter();
    let lang = request.lang in bundledLanguages ? request.lang : 'text';
    if (lang !== 'text' && !instance.getLoadedLanguages().includes(lang)) {
      try {
        await instance.loadLanguage(bundledLanguages[lang as BundledLanguage]);
      } catch {
        lang = 'text';
      }
    }
    const html = instance.codeToHtml(request.code, {
      lang,
      theme: MARKDOWN_SHIKI_THEME,
      tabindex: false,
    });
    post({ type: 'highlight', id: request.id, html });
  } catch (error) {
    post({ type: 'error', id: request.id, message: error instanceof Error ? error.message : String(error) });
  }
}

function post(response: MarkdownWorkerResponse): void {
  self.postMessage(response);
}
