import { LSPPlugin, Workspace, type WorkspaceFile } from '@codemirror/lsp-client';
import type { ChangeSet, Text } from '@codemirror/state';
import type { EditorView } from '@codemirror/view';

type WorkspaceFileUpdate = {
  file: WorkspaceFile;
  prevDoc: Text;
  changes: ChangeSet;
};

import { fileUriToPath } from './lspUris';

type DisplayFileFn = (path: string) => Promise<EditorView | null>;

class TrackedFile implements WorkspaceFile {
  constructor(
    readonly uri: string,
    readonly languageId: string,
    public version: number,
    public doc: Text,
    public view: EditorView,
  ) {}

  getView(): EditorView | null {
    return this.view;
  }
}

export class OpenChamberWorkspace extends Workspace {
  files: WorkspaceFile[] = [];
  private readonly versions = new Map<string, number>();
  private readonly displayFileFn: DisplayFileFn;

  constructor(client: ConstructorParameters<typeof Workspace>[0], displayFileFn: DisplayFileFn) {
    super(client);
    this.displayFileFn = displayFileFn;
  }

  private nextVersion(uri: string): number {
    const next = (this.versions.get(uri) ?? -1) + 1;
    this.versions.set(uri, next);
    return next;
  }

  syncFiles(): readonly WorkspaceFileUpdate[] {
    const updates: WorkspaceFileUpdate[] = [];
    for (const file of this.files) {
      const view = file.getView();
      if (!view) {
        continue;
      }
      const plugin = LSPPlugin.get(view);
      if (!plugin || plugin.unsyncedChanges.empty) {
        continue;
      }
      updates.push({
        changes: plugin.unsyncedChanges as ChangeSet,
        file,
        prevDoc: file.doc,
      });
      file.doc = view.state.doc;
      file.version = this.nextVersion(file.uri);
      plugin.clear();
    }
    return updates;
  }

  openFile(uri: string, languageId: string, view: EditorView): void {
    const existing = this.getFile(uri);
    if (existing instanceof TrackedFile) {
      existing.view = view;
      existing.doc = view.state.doc;
      return;
    }
    const file = new TrackedFile(uri, languageId, this.nextVersion(uri), view.state.doc, view);
    this.files.push(file);
    this.client.didOpen(file);
  }

  closeFile(uri: string, _view?: EditorView): void {
    const file = this.getFile(uri);
    if (!file) {
      return;
    }
    this.files = this.files.filter((candidate) => candidate !== file);
    this.client.didClose(uri);
  }

  override displayFile(uri: string): Promise<EditorView | null> {
    const open = this.getFile(uri)?.getView();
    if (open) {
      return Promise.resolve(open);
    }
    const path = fileUriToPath(uri);
    if (!path) {
      return Promise.resolve(null);
    }
    return this.displayFileFn(path);
  }
}
