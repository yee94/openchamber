import React from 'react';
import { highlightLinesInWorker } from '@/components/chat/markdown/markdown-worker';

// Tokenize a whole block ONCE in the Shiki worker and expose per-line inner
// HTML. For per-line layouts (diffs, gutters, virtualization) that would
// otherwise spawn one highlighter per row. Returns `null` until the first
// result lands (or permanently on failure) — callers render plain text then.
//
// Whole-block tokenization also restores cross-line syntax context (multi-line
// strings / comments) that independent per-line highlighting loses.
export const useWorkerHighlightedLines = (code: string, language: string): string[] | null => {
  const [lines, setLines] = React.useState<string[] | null>(null);

  React.useEffect(() => {
    let active = true;
    const abortController = new AbortController();
    setLines(null);
    void highlightLinesInWorker(code, (language || 'text').toLowerCase(), {
      signal: abortController.signal,
      priority: 'visible',
    }).then((result) => {
      if (active) setLines(result);
    });
    return () => {
      active = false;
      abortController.abort();
    };
  }, [code, language]);

  return lines;
};
