import {
  LSPClient,
  languageServerExtensions,
  type Transport,
} from '@codemirror/lsp-client';
import type { Extension } from '@codemirror/state';
import type { EditorView } from '@codemirror/view';
import DOMPurify from 'dompurify';

import { normalizeFilePath } from '@/lib/path-utils';

import { waitForLspEditor } from './lspEditorRegistry';
import { createLspWebSocketTransport } from './lspTransport';
import { languageIdForPath, pathToFileUri } from './lspUris';
import { OpenChamberWorkspace } from './lspWorkspace';

export type LspSession = {
  directory: string;
  client: LSPClient;
  ready: Promise<void>;
  plugin(filePath: string): Extension | null;
  retain(): void;
  release(): void;
};

const sessions = new Map<string, LspSession>();

const sanitizeHtml = (html: string): string => {
  if (typeof window === 'undefined' || !DOMPurify.isSupported) {
    return '';
  }
  return DOMPurify.sanitize(html) as unknown as string;
};

const createSession = (directory: string): LspSession => {
  const transport = createLspWebSocketTransport(directory);
  let refs = 0;
  let closed = false;

  const client = new LSPClient({
    rootUri: pathToFileUri(directory),
    timeout: 15_000,
    sanitizeHTML: sanitizeHtml,
    workspace: (nextClient) => new OpenChamberWorkspace(nextClient, (path) => waitForLspEditor(path)),
    extensions: languageServerExtensions(),
  });

  const ready = transport.ready.then(() => {
    client.connect(transport as Transport);
    return client.initializing.then(() => undefined);
  });

  const session: LspSession = {
    directory,
    client,
    ready,
    plugin(filePath) {
      if (!client.connected) {
        return null;
      }
      const languageId = languageIdForPath(filePath);
      if (!languageId) {
        return null;
      }
      const uri = pathToFileUri(filePath);
      if (!uri) {
        return null;
      }
      return client.plugin(uri, languageId);
    },
    retain() {
      refs += 1;
    },
    release() {
      refs = Math.max(0, refs - 1);
      if (refs > 0 || closed) {
        return;
      }
      closed = true;
      sessions.delete(directory);
      try {
        client.disconnect();
      } catch {
        // ignore
      }
      transport.close();
    },
  };

  sessions.set(directory, session);
  return session;
};

export const acquireLspSession = (directory: string): LspSession => {
  const key = normalizeFilePath(directory);
  const existing = sessions.get(key);
  const session = existing ?? createSession(key);
  session.retain();
  return session;
};

export const peekLspSession = (directory: string | null | undefined): LspSession | null => {
  if (!directory) {
    return null;
  }
  return sessions.get(normalizeFilePath(directory)) ?? null;
};
