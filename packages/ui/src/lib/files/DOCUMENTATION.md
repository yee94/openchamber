# File explorer decorations

## Purpose

Shared Git decoration and ghost-node helpers for the Files explorer. The Git
changes panel still owns staged/unstaged lists; this module overlays status
onto the full filesystem tree.

## Contract

- `buildFileGitDecorationIndex` maps `GitStatus.files` onto absolute and
  relative paths in O(changed files). Tree rows look up in O(1).
- Status codes read both `index` and `working_dir`. A delete on either side
  wins so unstaged removals stay visible.
- Deleted paths that are no longer on disk are injected as `ghost` nodes when
  the parent directory is listed. Expanding a ghost directory uses
  `ghostChildrenForDirectory` and must not call `listDirectory`.
- `decorateFileTreeChildren` reuses the input object when no ghosts are added.

## Consumers

- `SidebarFilesTree`
- `FilesView` tree

Git status freshness for those surfaces is owned by `useVisibleGitStatusSync`.

Line-level editor marks live in `lib/codemirror/gitGutter.ts`. Command-click
uses a language server when the OpenChamber host can spawn
`typescript-language-server` (`lib/codemirror/lspSession.ts`, server
`packages/web/server/lib/lsp`). Relative imports and same-file / search
lookups remain the fallback when LSP is down or the file is not TS/JS.

## Follow-ups

Parked for a later pass. Do not treat these as unfinished work in this branch.

- Allowlist more language servers on the same `/api/lsp/ws` pipe (Python, Go, Rust).
- Decide whether mobile Files gets Cmd+click (desktop/web only today).
- VS Code webview: inherit the host language service, or keep the OpenChamber server path.
- Relay e2e for `/api/lsp/ws`.
- Richer `FilesAPI.search` previews so the heuristic fallback can jump cross-file when LSP is down.
- Browser / Preview smoke for tree letters, gutter bars, and TS/JS go-to-definition after tsserver cold start.
