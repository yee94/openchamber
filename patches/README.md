# Dependency patches

Local diffs applied by **Bun** at `bun install` time via root `package.json` → `patchedDependencies`.

They are **not** dead git leftovers. CI and Docker must keep this directory next to `package.json` / `bun.lock` **before** install runs.

## How install applies them

| Path | Applies patches? |
|------|------------------|
| `bun install` / `bun install --frozen-lockfile` (GitHub Actions) | Yes — install-time `patchedDependencies` |
| `bun install --ignore-scripts` (Docker image deps stage) | Yes — scripts skipped, **patches still applied** if `patches/` is copied first |
| Legacy `patch-package` postinstall | **Removed** — do not reintroduce; both patches are Bun-native |

If a patch file is missing or the version key drifts from the lockfile, install **fails** (preferred over silent unpatched builds).

## Active patches

| Package | File | Why |
|---------|------|-----|
| `@tanstack/virtual-core@3.17.8` | `@tanstack%2Fvirtual-core@3.17.8.patch` | Clamp virtualizer `calculateRange` scroll offset to real bounds during end-anchor adjustments (chat history). |
| `ghostty-web@0.4.0` | `ghostty-web@0.4.0.patch` | Safe `fromCodePoint` for bad terminal code points; optional `lineHeight` cell metrics. |

Each `.patch` file starts with a `# TODO(remove): …` header (same criteria as below).

## TODO: when to remove

### `@tanstack/virtual-core`

Remove the patch file **and** the `patchedDependencies` entry when upstream clamps range `scrollOffset` the same way (or an official API makes it unnecessary). 3.17.8 still does not.

Checklist:

1. Bump `@tanstack/react-virtual` / `virtual-core` past the patched version.
2. Delete the patch + `patchedDependencies` line; `bun install`.
3. Virtualized chat: scroll up + load more — no blank range / jump from unclamped offset during measure.
4. Focused UI chat / timeline tests still pass.
5. Re-check on each `@tanstack/react-virtual` / `virtual-core` bump past 3.17.8. Upstream 3.17.8 still does not include this clamp (3.17.5 only clamps tracked offset at 0).

### `ghostty-web`

Remove when a released `ghostty-web` includes invalid-codepoint guards and `lineHeight` (or we no longer need those behaviors).

Checklist:

1. Bump `ghostty-web` past `0.4.0`.
2. Delete the patch + `patchedDependencies` line; `bun install`.
3. Terminal theme/`lineHeight` spacing still matches UI.
4. Invalid codepoint streams do not throw in the canvas text path.
5. UI terminal surfaces build cleanly.

## Editing a patch

1. Change the package under `node_modules` (or use a clean extract).
2. Produce a Bun-style diff with paths relative to the package root (`a/dist/...`, not `a/node_modules/...`).
3. Keep the `# TODO(remove):` header.
4. Point `patchedDependencies` at the new versioned filename when the dependency version changes.
5. Run `bun install` and re-verify the affected surface.
