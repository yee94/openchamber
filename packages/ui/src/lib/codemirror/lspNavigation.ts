import { LSPPlugin } from '@codemirror/lsp-client';
import type { EditorView } from '@codemirror/view';

import type { CodeNavTarget } from './codeNavigation';
import { fileUriToPath } from './lspUris';

type LspRange = { start: { line: number; character: number } };
type LspLocation = { uri: string; range: LspRange };
type LspLocationLink = { targetUri: string; targetSelectionRange?: LspRange; targetRange?: LspRange };

const firstLocation = (
  result: LspLocation | LspLocationLink | Array<LspLocation | LspLocationLink> | null | undefined,
) => {
  if (!result) {
    return null;
  }
  return Array.isArray(result) ? result[0] ?? null : result;
};

const toTarget = (location: LspLocation | LspLocationLink): CodeNavTarget | null => {
  const uri = 'uri' in location ? location.uri : location.targetUri;
  const range = 'targetUri' in location
    ? location.targetSelectionRange ?? location.targetRange ?? null
    : location.range;
  const path = fileUriToPath(uri);
  if (!path || !range) {
    return null;
  }
  return {
    path,
    line: range.start.line + 1,
    column: range.start.character + 1,
  };
};

export const requestLspDefinition = async (
  view: EditorView,
  documentOffset: number,
): Promise<CodeNavTarget | null> => {
  const plugin = LSPPlugin.get(view);
  if (!plugin?.client.connected) {
    return null;
  }

  plugin.client.sync();
  const result = await plugin.client.request<
    { textDocument: { uri: string }; position: { line: number; character: number } },
    LspLocation | LspLocationLink | Array<LspLocation | LspLocationLink> | null
  >('textDocument/definition', {
    textDocument: { uri: plugin.uri },
    position: plugin.toPosition(documentOffset),
  });

  const location = firstLocation(result);
  return location ? toTarget(location) : null;
};
