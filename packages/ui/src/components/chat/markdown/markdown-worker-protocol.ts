// Message protocol for the markdown Shiki Web Worker.
//
// The worker tokenizes a complete code block off the main thread and returns
// ready-to-splice Shiki HTML. The theme is dependency-free and imported inside
// the worker directly, so it is not sent over postMessage.

export type MarkdownWorkerRequest =
  | { type: 'init' }
  | { type: 'highlight'; id: number; code: string; lang: string };

export type MarkdownWorkerResponse =
  | { type: 'highlight'; id: number; html: string }
  | { type: 'error'; id: number; message: string };
