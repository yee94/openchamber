import { EditorSelection } from '@codemirror/state';
import { Decoration, type DecorationSet, EditorView, ViewPlugin } from '@codemirror/view';
import { RangeSetBuilder, StateEffect, StateField } from '@codemirror/state';
import type { Extension } from '@codemirror/state';

import { normalizeFilePath, toAbsoluteFilePath } from '@/lib/path-utils';

export type CodeNavTokenKind = 'import-path' | 'identifier';

export type CodeNavToken = {
  kind: CodeNavTokenKind;
  text: string;
  from: number;
  to: number;
};

export type CodeNavRequest = CodeNavToken & {
  filePath: string;
  line: number;
};

export type CodeNavTarget = {
  path: string;
  line: number;
  column?: number;
};

const IDENTIFIER_PATTERN = /[A-Za-z_$][\w$]*/;
const IMPORT_LINE_PATTERN = /\b(?:import|export|require)\b|from\s+['"]/;
const DEFINITION_PREFIX = String.raw`^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?(?:function|class|const|let|var|type|interface|enum)\s+`;
const IMPORT_EXTENSIONS = [
  '',
  '.ts',
  '.tsx',
  '.js',
  '.jsx',
  '.mjs',
  '.cjs',
  '.json',
  '/index.ts',
  '/index.tsx',
  '/index.js',
  '/index.jsx',
];

const hasModifier = (event: MouseEvent): boolean => event.metaKey || event.ctrlKey;

const lineBounds = (text: string, offset: number): { start: number; end: number; line: string } => {
  const start = text.lastIndexOf('\n', offset - 1) + 1;
  const rawEnd = text.indexOf('\n', offset);
  const end = rawEnd === -1 ? text.length : rawEnd;
  return { start, end, line: text.slice(start, end) };
};

const matchStringAt = (line: string, column: number): { from: number; to: number; value: string } | null => {
  for (let index = 0; index < line.length; index += 1) {
    const quote = line[index];
    if (quote !== '"' && quote !== "'" && quote !== '`') {
      continue;
    }
    let cursor = index + 1;
    while (cursor < line.length) {
      if (line[cursor] === '\\') {
        cursor += 2;
        continue;
      }
      if (line[cursor] === quote) {
        break;
      }
      cursor += 1;
    }
    if (cursor >= line.length) {
      return null;
    }
    if (column >= index && column <= cursor) {
      return { from: index, to: cursor + 1, value: line.slice(index + 1, cursor) };
    }
    index = cursor;
  }
  return null;
};

const matchIdentifierAt = (line: string, column: number): { from: number; to: number; value: string } | null => {
  if (column < 0 || column > line.length) {
    return null;
  }
  let start = column;
  while (start > 0 && /[\w$]/.test(line[start - 1] ?? '')) {
    start -= 1;
  }
  let end = column;
  while (end < line.length && /[\w$]/.test(line[end] ?? '')) {
    end += 1;
  }
  const value = line.slice(start, end);
  if (!IDENTIFIER_PATTERN.test(value) || /^\d/.test(value)) {
    return null;
  }
  return { from: start, to: end, value };
};

export const tokenAtOffset = (text: string, offset: number): CodeNavToken | null => {
  if (offset < 0 || offset > text.length) {
    return null;
  }
  const { start, line } = lineBounds(text, offset);
  const column = offset - start;
  const stringMatch = matchStringAt(line, column);
  if (stringMatch && IMPORT_LINE_PATTERN.test(line) && stringMatch.value.trim().length > 0) {
    return {
      kind: 'import-path',
      text: stringMatch.value,
      from: start + stringMatch.from,
      to: start + stringMatch.to,
    };
  }
  const identifier = matchIdentifierAt(line, column);
  if (!identifier) {
    return null;
  }
  return {
    kind: 'identifier',
    text: identifier.value,
    from: start + identifier.from,
    to: start + identifier.to,
  };
};

const parentDirectory = (filePath: string): string => {
  const normalized = normalizeFilePath(filePath);
  const lastSlash = normalized.lastIndexOf('/');
  if (lastSlash <= 0) {
    return normalized.startsWith('/') ? '/' : '';
  }
  const parent = normalized.slice(0, lastSlash);
  return /^[A-Za-z]:$/.test(parent) ? `${parent}/` : parent;
};

export const resolveRelativeImportPath = (currentFile: string, spec: string): string | null => {
  const trimmed = spec.trim();
  if (!trimmed.startsWith('.')) {
    return null;
  }
  return toAbsoluteFilePath(parentDirectory(currentFile), trimmed) || null;
};

export const importPathCandidates = (resolved: string): string[] => {
  const normalized = normalizeFilePath(resolved);
  if (!normalized) {
    return [];
  }
  return IMPORT_EXTENSIONS.map((suffix) => normalizeFilePath(`${normalized}${suffix}`));
};

const escapeRegExp = (value: string): string => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

export const findSameFileDefinitionLine = (
  text: string,
  identifier: string,
  currentLine: number,
): number | null => {
  if (!identifier) {
    return null;
  }
  const pattern = new RegExp(`${DEFINITION_PREFIX}${escapeRegExp(identifier)}\\b`);
  const lines = text.split('\n');
  for (let index = 0; index < lines.length; index += 1) {
    const lineNumber = index + 1;
    if (lineNumber === currentLine) {
      continue;
    }
    if (pattern.test(lines[index] ?? '')) {
      return lineNumber;
    }
  }
  return null;
};

export const scoreDefinitionPreview = (identifier: string, preview: string[] | undefined): number => {
  if (!preview?.length) {
    return 0;
  }
  const pattern = new RegExp(`${DEFINITION_PREFIX}${escapeRegExp(identifier)}\\b`);
  return preview.some((line) => pattern.test(line)) ? 2 : 0;
};

export const revealEditorPosition = (view: EditorView, line: number, column = 1) => {
  const targetLine = Math.min(Math.max(line, 1), view.state.doc.lines);
  const docLine = view.state.doc.line(targetLine);
  const nextCharacter = Math.max(1, Math.min(column, docLine.length + 1));
  const position = docLine.from + nextCharacter - 1;
  view.dispatch({
    selection: EditorSelection.cursor(position),
    effects: EditorView.scrollIntoView(position, { y: 'center' }),
  });
  view.focus();
};

const setNavToken = StateEffect.define<CodeNavToken | null>();

const navTokenField = StateField.define<DecorationSet>({
  create() {
    return Decoration.none;
  },
  update(decorations, transaction) {
    const effect = transaction.effects.find((candidate) => candidate.is(setNavToken));
    if (!effect) {
      return decorations;
    }
    if (!effect.value) {
      return Decoration.none;
    }
    const builder = new RangeSetBuilder<Decoration>();
    builder.add(effect.value.from, effect.value.to, Decoration.mark({ class: 'oc-code-nav-token' }));
    return builder.finish();
  },
  provide: (field) => EditorView.decorations.from(field),
});

const navTheme = EditorView.baseTheme({
  '.oc-code-nav-token': {
    textDecoration: 'underline',
    cursor: 'pointer',
  },
});

export const createCodeNavigationExtension = (options: {
  filePath: string;
  onNavigate: (request: CodeNavRequest) => void;
}): Extension => {
  const plugin = ViewPlugin.fromClass(class {
    lastToken: CodeNavToken | null = null;

    updateToken(view: EditorView, token: CodeNavToken | null) {
      if (
        this.lastToken?.from === token?.from
        && this.lastToken?.to === token?.to
        && this.lastToken?.text === token?.text
      ) {
        return;
      }
      this.lastToken = token;
      view.dispatch({ effects: setNavToken.of(token) });
    }
  }, {
    eventHandlers: {
      mousemove(event, view) {
        if (!hasModifier(event)) {
          this.updateToken(view, null);
          return;
        }
        const position = view.posAtCoords({ x: event.clientX, y: event.clientY });
        if (position == null) {
          this.updateToken(view, null);
          return;
        }
        this.updateToken(view, tokenAtOffset(view.state.doc.toString(), position));
      },
      mouseleave(_event, view) {
        this.updateToken(view, null);
      },
      mousedown(event, view) {
        if (!hasModifier(event) || event.button !== 0) {
          return false;
        }
        const position = view.posAtCoords({ x: event.clientX, y: event.clientY });
        if (position == null) {
          return false;
        }
        const token = tokenAtOffset(view.state.doc.toString(), position);
        if (!token) {
          return false;
        }
        event.preventDefault();
        const line = view.state.doc.lineAt(token.from).number;
        options.onNavigate({
          ...token,
          filePath: options.filePath,
          line,
        });
        return true;
      },
    },
  });

  return [navTokenField, plugin, navTheme];
};
