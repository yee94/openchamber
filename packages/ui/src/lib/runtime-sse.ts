import { runtimeFetch, type RuntimeFetchOptions } from './runtime-fetch';

const MAX_BUFFER_BYTES = 1024 * 1024;
const textEncoder = new TextEncoder();

type RuntimeSseOptions = {
  signal?: AbortSignal;
  onOpen?: () => void;
  onActivity?: () => void;
  onMessage?: (data: string) => void;
  fetch?: (path: string, options: RuntimeFetchOptions) => Promise<Response>;
};

const isAbortError = (error: unknown): error is Error => error instanceof Error && error.name === 'AbortError';
const toAbortError = (error: unknown): Error => isAbortError(error) ? error : new DOMException('The operation was aborted.', 'AbortError');

const cancelBody = async (body: ReadableStream<Uint8Array> | null): Promise<void> => {
  try {
    await body?.cancel();
  } catch {
    // Transport cleanup retains the primary SSE error.
  }
};

const cancelReader = async (reader: ReadableStreamDefaultReader<Uint8Array>): Promise<void> => {
  try {
    await reader.cancel();
  } catch {
    // Transport cleanup retains the primary SSE error.
  }
};

/** Consumes one runtime-scoped SSE response, including tunneled Relay responses. */
export const consumeRuntimeSse = async (path: string, options: RuntimeSseOptions = {}): Promise<void> => {
  const fetcher = options.fetch ?? runtimeFetch;
  let response: Response;
  try {
    response = await fetcher(path, {
      method: 'GET',
      headers: { Accept: 'text/event-stream' },
      signal: options.signal,
    });
  } catch (error) {
    if (options.signal?.aborted || isAbortError(error)) throw toAbortError(error);
    throw new Error('SSE request failed');
  }

  if (!response.ok) {
    await cancelBody(response.body);
    throw new Error('SSE response failed');
  }
  if (!/^text\/event-stream(?:\s*;|\s*$)/i.test(response.headers.get('content-type') ?? '')) {
    await cancelBody(response.body);
    throw new Error('SSE response has invalid content type');
  }
  if (!response.body) throw new Error('SSE response has no body');

  const reader = response.body.getReader();
  try {
    options.onOpen?.();
  } catch (error) {
    await cancelReader(reader);
    reader.releaseLock();
    if (options.signal?.aborted || isAbortError(error)) throw toAbortError(error);
    throw new Error('SSE response read failed');
  }
  const decoder = new TextDecoder();
  let line = '';
  let lineSize = 0;
  let pendingCarriageReturn = false;
  let dataLines: string[] = [];
  let eventSize = 0;
  let completed = false;

  const resetEvent = (): void => {
    dataLines = [];
    eventSize = 0;
  };
  const commitEvent = (): void => {
    if (dataLines.length === 0) return;
    options.onActivity?.();
    options.onMessage?.(dataLines.join('\n'));
    resetEvent();
  };
  const processLine = (): void => {
    const currentLine = line;
    const currentLineSize = lineSize;
    line = '';
    lineSize = 0;
    if (currentLine.length === 0) {
      commitEvent();
      return;
    }
    if (currentLine.startsWith(':')) {
      options.onActivity?.();
      return;
    }
    const separator = currentLine.indexOf(':');
    const field = separator === -1 ? currentLine : currentLine.slice(0, separator);
    let value = separator === -1 ? '' : currentLine.slice(separator + 1);
    if (value.startsWith(' ')) value = value.slice(1);
    if (field === 'data') {
      const valuePrefixSize = separator === -1
        ? currentLineSize
        : separator + 1 + (currentLine.charAt(separator + 1) === ' ' ? 1 : 0);
      const valueSize = currentLineSize - valuePrefixSize;
      const nextEventSize = eventSize + valueSize + (dataLines.length > 0 ? 1 : 0);
      if (nextEventSize > MAX_BUFFER_BYTES) throw new Error('SSE response exceeds buffer limit');
      eventSize = nextEventSize;
      dataLines.push(value);
    }
  };
  const appendLineFragment = (fragment: string): void => {
    if (fragment.length === 0) return;
    line += fragment;
    lineSize += textEncoder.encode(fragment).byteLength;
    const dataPrefixSize = line === 'data'
      ? 4
      : line.startsWith('data:')
        ? 5 + (line.charAt(5) === ' ' ? 1 : 0)
        : 0;
    if (eventSize + lineSize - dataPrefixSize > MAX_BUFFER_BYTES) throw new Error('SSE response exceeds buffer limit');
  };
  const processText = (text: string): void => {
    let start = 0;
    if (pendingCarriageReturn) {
      pendingCarriageReturn = false;
      if (text.charAt(0) === '\n') start = 1;
    }
    for (let index = start; index < text.length; index += 1) {
      const character = text.charAt(index);
      if (character !== '\r' && character !== '\n') continue;
      appendLineFragment(text.slice(start, index));
      processLine();
      if (character === '\r' && index + 1 < text.length && text.charAt(index + 1) === '\n') {
        index += 1;
      } else if (character === '\r' && index + 1 === text.length) {
        pendingCarriageReturn = true;
      }
      start = index + 1;
    }
    appendLineFragment(text.slice(start));
  };

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      processText(decoder.decode(value, { stream: true }));
    }
    processText(decoder.decode());
    completed = true;
  } catch (error) {
    if (options.signal?.aborted || isAbortError(error)) throw toAbortError(error);
    if (error instanceof Error && error.message === 'SSE response exceeds buffer limit') throw error;
    throw new Error('SSE response read failed');
  } finally {
    if (!completed) await cancelReader(reader);
    reader.releaseLock();
  }
};
