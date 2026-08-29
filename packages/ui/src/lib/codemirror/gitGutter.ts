import { RangeSet, RangeSetBuilder, StateField } from '@codemirror/state';
import { EditorView, GutterMarker, gutter } from '@codemirror/view';
import type { Extension } from '@codemirror/state';

export type GitGutterKind = 'off' | 'untracked' | 'diff';

export type DirtyLineKind = 'add' | 'mod' | 'del';

export type DirtyLineMark = {
  line: number;
  kind: DirtyLineKind;
};

export type GitGutterConfig = {
  baseline: string;
  kind: GitGutterKind;
};

const LOOKAHEAD = 80;
const MAX_MARKED_LINES = 8_000;

class GitChangeMarker extends GutterMarker {
  constructor(readonly markKind: DirtyLineKind) {
    super();
  }

  eq(other: GitChangeMarker): boolean {
    return this.markKind === other.markKind;
  }

  toDOM(): HTMLElement {
    const mark = document.createElement('span');
    mark.className = `oc-git-gutter-mark oc-git-gutter-mark-${this.markKind}`;
    mark.setAttribute('aria-hidden', 'true');
    return mark;
  }
}

const markerByKind: Record<DirtyLineKind, GitChangeMarker> = {
  add: new GitChangeMarker('add'),
  mod: new GitChangeMarker('mod'),
  del: new GitChangeMarker('del'),
};

type LineHunk = {
  oldStart: number;
  oldCount: number;
  newStart: number;
  newCount: number;
};

const splitLines = (value: string): string[] => {
  if (value.length === 0) {
    return [''];
  }
  return value.split('\n');
};

const collectHunks = (originalLines: string[], currentLines: string[]): LineHunk[] => {
  const hunks: LineHunk[] = [];
  let oldIndex = 0;
  let newIndex = 0;

  const pushHunk = (oldStart: number, oldCount: number, newStart: number, newCount: number) => {
    if (oldCount === 0 && newCount === 0) {
      return;
    }
    hunks.push({ oldStart, oldCount, newStart, newCount });
  };

  while (oldIndex < originalLines.length && newIndex < currentLines.length) {
    if (originalLines[oldIndex] === currentLines[newIndex]) {
      oldIndex += 1;
      newIndex += 1;
      continue;
    }

    let found: LineHunk | null = null;
    for (let look = 1; look <= LOOKAHEAD && !found; look += 1) {
      if (oldIndex + look < originalLines.length && originalLines[oldIndex + look] === currentLines[newIndex]) {
        found = { oldStart: oldIndex, oldCount: look, newStart: newIndex, newCount: 0 };
        oldIndex += look;
        break;
      }
      if (newIndex + look < currentLines.length && originalLines[oldIndex] === currentLines[newIndex + look]) {
        found = { oldStart: oldIndex, oldCount: 0, newStart: newIndex, newCount: look };
        newIndex += look;
        break;
      }
      if (
        oldIndex + look < originalLines.length
        && newIndex + look < currentLines.length
        && originalLines[oldIndex + look] === currentLines[newIndex + look]
      ) {
        found = { oldStart: oldIndex, oldCount: look, newStart: newIndex, newCount: look };
        oldIndex += look;
        newIndex += look;
        break;
      }
    }

    if (found) {
      hunks.push(found);
      continue;
    }

    pushHunk(oldIndex, 1, newIndex, 1);
    oldIndex += 1;
    newIndex += 1;
  }

  if (oldIndex < originalLines.length || newIndex < currentLines.length) {
    pushHunk(
      oldIndex,
      originalLines.length - oldIndex,
      newIndex,
      currentLines.length - newIndex,
    );
  }

  return hunks;
};

export const computeDirtyLineMarks = (original: string, current: string): DirtyLineMark[] => {
  if (original === current) {
    return [];
  }

  const originalLines = splitLines(original);
  const currentLines = splitLines(current);
  const hunks = collectHunks(originalLines, currentLines);
  const marks: DirtyLineMark[] = [];

  for (const hunk of hunks) {
    if (hunk.oldCount > 0 && hunk.newCount === 0) {
      const line = Math.min(Math.max(hunk.newStart, 0) + 1, currentLines.length);
      marks.push({ line, kind: 'del' });
      continue;
    }

    const kind: DirtyLineKind = hunk.oldCount === 0 ? 'add' : 'mod';
    for (let offset = 0; offset < hunk.newCount; offset += 1) {
      marks.push({ line: hunk.newStart + offset + 1, kind });
      if (marks.length >= MAX_MARKED_LINES) {
        return marks;
      }
    }
  }

  return marks;
};

export const marksForGitGutter = (config: GitGutterConfig, current: string): DirtyLineMark[] => {
  if (config.kind === 'off') {
    return [];
  }
  if (config.kind === 'untracked') {
    const lineCount = splitLines(current).length;
    const marks: DirtyLineMark[] = [];
    for (let line = 1; line <= lineCount && line <= MAX_MARKED_LINES; line += 1) {
      marks.push({ line, kind: 'add' });
    }
    return marks;
  }
  return computeDirtyLineMarks(config.baseline, current);
};

const buildMarkerSet = (
  doc: { line: (number: number) => { from: number } },
  marks: DirtyLineMark[],
): RangeSet<GutterMarker> => {
  const builder = new RangeSetBuilder<GutterMarker>();
  const sorted = marks.slice().sort((left, right) => left.line - right.line);
  let lastLine = 0;
  for (const mark of sorted) {
    if (mark.line === lastLine || mark.line < 1) {
      continue;
    }
    lastLine = mark.line;
    try {
      const from = doc.line(mark.line).from;
      builder.add(from, from, markerByKind[mark.kind]);
    } catch {
      break;
    }
  }
  return builder.finish();
};

const gitGutterTheme = EditorView.baseTheme({
  '.oc-git-gutter-col': {
    width: '3px',
    minWidth: '3px',
  },
  '.oc-git-gutter-col .cm-gutterElement': {
    padding: '0',
    width: '3px',
  },
  '.oc-git-gutter-mark': {
    display: 'block',
    width: '3px',
    height: '100%',
  },
  '.oc-git-gutter-mark-add': {
    backgroundColor: 'var(--status-success)',
  },
  '.oc-git-gutter-mark-mod': {
    backgroundColor: 'var(--status-info)',
  },
  '.oc-git-gutter-mark-del': {
    backgroundColor: 'var(--status-error)',
    height: '2px',
    marginTop: '0.7em',
  },
});

export const createGitGutterExtension = (config: GitGutterConfig): Extension => {
  const field = StateField.define<RangeSet<GutterMarker>>({
    create(state) {
      return buildMarkerSet(state.doc, marksForGitGutter(config, state.doc.toString()));
    },
    update(markers, transaction) {
      if (!transaction.docChanged) {
        return markers;
      }
      return buildMarkerSet(transaction.state.doc, marksForGitGutter(config, transaction.state.doc.toString()));
    },
  });

  return [
    field,
    gutter({
      class: 'oc-git-gutter-col',
      markers: (view) => view.state.field(field),
      initialSpacer: () => markerByKind.mod,
    }),
    gitGutterTheme,
  ];
};
