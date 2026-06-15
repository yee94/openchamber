// Message protocol for the markdown Shiki Web Worker.
//
// The worker tokenizes a complete code block off the main thread and returns
// ready-to-splice Shiki HTML. The theme is dependency-free and imported inside
// the worker directly, so it is not sent over postMessage.

export type MarkdownWorkerRequest =
  | { type: 'init' }
  // Highlight a whole block to ready-to-splice Shiki `<pre>` HTML.
  | { type: 'highlight'; id: number; code: string; lang: string }
  // Highlight a whole block but return per-line inner HTML (one entry per line),
  // so per-line layouts (diffs, gutters, virtualization) tokenize in ONE call
  // instead of one worker round-trip per line.
  | { type: 'highlightLines'; id: number; code: string; lang: string };

export type MarkdownWorkerResponse =
  | { type: 'highlight'; id: number; html: string }
  | { type: 'highlightLines'; id: number; lines: string[] }
  | { type: 'error'; id: number; message: string };
