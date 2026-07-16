# UI Stores

## Purpose

`packages/ui/src/stores` contains app-level Zustand stores for persistent UI state, runtime state, and feature caches.

Not all state in the UI belongs here.

Use a store when state is:

- shared across distant parts of the app
- needed outside a single component subtree
- cache-like and keyed by runtime identity (for example directory, branch, session id)
- updated imperatively from multiple surfaces

Do not put high-frequency local component state here just because it is convenient.

## Architecture

There are multiple store categories in this directory.

### Feature cache / query stores

These are the most performance-sensitive.

- `useGitStore.ts`
- `useGitHubPrStatusStore.ts`
- `useFilesViewTabsStore.ts`
- `useCommandsStore.ts`

These stores act like centralized keyed caches. UI should consume narrow slices from them instead of re-fetching the same data in multiple places.

`useCommandsStore` loads the official command catalog through the OpenCode SDK,
then resolves OpenChamber-owned scope metadata with one batched runtime request.
Never restore the per-command metadata `Promise.all` path: large command catalogs
otherwise create an N+1 preflight/request storm during cold startup.

### UI state stores

Examples:

- `useUIStore.ts`
- `useDirectoryStore.ts`
- `useFeatureFlagsStore.ts`
- `useUpdateStore.ts`

These stores coordinate visible app state, navigation, selected tabs, dialogs, and lightweight feature flags.

`useUIStore` keeps context-panel tab *content* directory-scoped (`contextPanelByDirectory`), but the *open* state of the right workspace (context panel for subagent/file preview/diff, plus right sidebar git/files) is session-correlated. `syncWorkspacePanelsForSessionSwitch()` captures the previous session snapshot into in-memory `sessionWorkspacePanelById` and restores the next session (or closes panels when there is no snapshot). `setCurrentSession()` is the single switch boundary that calls it.

`useConfigStore.ts` keeps provider and agent snapshots project-scoped. Its transient
provider/agent loading maps are keyed by the active config directory so a deeplink
into an uncached project can show explicit composer loading controls while cached
projects continue to render immediately during background refresh.

`ChatInput` subscribes directly to the active `agents` snapshot for permission
auto-accept visibility. It derives the selected agent's prompt capability locally,
so this UI decision adds no server request.

### Session / project coordination stores

Examples:

- `useProjectsStore.ts`
- `useGlobalSessionsStore.ts`
- `useSessionFoldersStore.ts`
- `useSessionFocusStore.ts`

These stores coordinate persistent project/session metadata across multiple views.

`useSessionFocusStore.ts` is intentionally transient and narrow. It records the
exact sidebar attention identity (`recent` or `project`, session, and project)
separately from the authoritative current session. Shortcut navigation and row
Active styling must read this identity instead of inferring origin from duplicate
session data.

`useGlobalSessionsStore.ts` distinguishes bounded display snapshots from the full
retention catalog. Sidebar active/archived loads are directory-keyed, capped, and
deduplicated. `fullCatalogSessionIds` and `fullCatalogGeneration` update only after
one complete active+archived catalog result; retention cleanup consumes that snapshot.
Directory refreshes preserve it, failed catalog loads preserve the prior snapshot,
and runtime switches clear it. Initial loading and background refreshing are separate
sets so an in-flight refresh never hides an existing session snapshot.

Electron cache refresh uses two timestamps per directory. Recent restarts query
the Electron Web Server, which performs `session.list(start=lastSyncedAt)` and
merges changed summaries into SQLite;
`lastFullSyncedAt` enforces a periodic full newest-page reconciliation so
offline deletes/archives cannot remain indefinitely.

Directory session loads also wait on the runtime-keyed OpenCode readiness
coordinator. Concurrent directories share one health-probe chain, so a cold
OpenCode process is not hit by parallel `session.list` calls. A runtime reset
invalidates both the directory requests and the matching readiness generation.
Cold directory refresh starts at three concurrent requests because each request
initializes directory-scoped OpenCode config and plugins. Successful completions
raise concurrency toward seven; timeout or overload feedback drops it to three
and then one. A failed readiness probe also enters a short runtime-scoped
cooldown, so queued directories share the same failure instead of starting a
new health-probe chain each time.

On Electron, `useGlobalSessionsStore` is also the UI owner for the SQLite
session-index startup state. The root coordinator restores summaries first and
then starts one server-owned background job. A low-priority long poll applies
new SQLite revisions and updates `startupSyncProgress`; it must not issue
per-directory OpenCode requests from the renderer. Do not add a second
session-summary cache to browser storage or a sidebar-local startup refresh.

## Git / PR Stores

The Git and PR stores are the most important stores to understand before editing this directory.

### `useGitStore.ts`

`useGitStore` is a centralized per-directory Git cache.

Core model:

- top-level keyed by `directory`
- each directory entry contains:
  - repo detection
  - status
  - branches
  - log
  - identity
  - diff cache
  - per-directory loading flags
  - freshness timestamps

Important properties:

- `directories: Map<string, DirectoryGitState>` is the source of truth
- loading state is per-directory, not global
- `ensureStatus()` and `ensureAll()` are the preferred entry points for consumers
- in-flight dedupe exists for status and `ensureAll()`
- diff data is separately cached and capped with size + count limits

### `useGitHubPrStatusStore.ts`

`useGitHubPrStatusStore` is a centralized PR cache keyed by `directory::branch`.

Core model:

- each entry stores:
  - current PR status payload
  - loading / error state
  - whether initial status was resolved
  - refresh timestamps
  - watch count
  - runtime params
  - resolved identity

Important properties:

- `ensureEntry()` initializes a key lazily
- `setParams()` attaches runtime context
- `startWatching()` / `stopWatching()` are for true live PR consumers only
- `refreshTargets()` supports one-shot multi-target bootstrap without turning on live watching
- persisted cache is for page refresh continuity, not for broad background syncing

## Ownership Rules

These rules are important. Breaking them tends to reintroduce idle CPU churn, stale UI, or rerender fanout.

1. No broad `directories` or `entries` subscriptions in normal UI components.
2. No root pollers for Git or PR.
3. No broad idle sweeps across many directories.
4. Prefer store `ensure*` methods over direct runtime API calls from views.
5. Visible consumers should drive refresh. Hidden consumers should not.
6. Header should not depend on PR store.
7. Closed sidebar should not create live PR work.
8. File tree Git status should update only when the file tree is visible.

## Message queue ledger

`message-queue-ledger.ts` owns the JSON-safe v4 durable queue contract under
`openchamber_message_queue_ledger_v4`. Its parser accepts only plain DTOs,
bounded strings and collections, durable URL locators, and blob IDs; runtime
`File`, `Blob`, bytes, `data:` and `blob:` values remain outside metadata.
Attachment references and recovery issues carry complete display metadata.
Local, server, and VS Code sources have mutually exclusive path fields, and
the parser enforces canonical scope keys plus global queue, operation, and
message identity uniqueness. Shared limits bound scopes, rows, attachments,
issues, content, and legacy byte decoding.
Detailed reads preserve raw metadata, normalized valid rows, parse issues, and
degraded scope keys. Compatibility reads report partial metadata as corrupt, so
only a complete snapshot becomes authoritative. Queue, operation, and message
IDs remain globally unique across scopes. Repository persistence deep-clones
admitted snapshots, coalesces concurrent flush waiters, and cancels pending work
when durability is disabled while an active write completes.
The canonical scope key uses the v3 encoding. Persisted sending work normalizes
to reconciling during migration/hydration. The ledger sink serializes writes and
reports unavailable, quota, corrupt, serialization, and cancelled outcomes.

`message-queue-migration.ts` imports the v3 Zustand envelope only while v4 is
absent. It assigns deterministic IDs, retains bound data-URL bytes before the
v4 commit, records attachment migration issues, and preserves the legacy payload
for degraded migrations. Attachment issues take terminal unresolved ownership;
legacy retry, ambiguous, definitive, and unresolved states map to strict v4
state shapes. Partial or corrupt v4 metadata enters recovery-required mode and
performs zero migration mutation. Existing v4 metadata remains authoritative.

The v3 message queue physically partitions entries by
`transportIdentity + directory + sessionID`. Queue item identity has three
separate IDs: `queueItemID` identifies the ledger row, `operationID` identifies
one send operation, and `messageID` identifies the admitted message for server
confirmation. States progress through queued, sending, reconciling, retrying,
failed, and confirmed removal; persisted `sending` entries hydrate as
`reconciling` because delivery status requires confirmation.

Sending and reconciling items remain immutable while dispatch ownership or
delivery status is unresolved. The v3 auto-send owner tracks dispatch flights
by exact scope, queue item, operation, and message identity; live `sending`
heads outside that registry recover into reconciling (same as v4). Queued heads and due
retrying heads auto-dispatch only with an authoritative scoped `idle` status.
Failed and unresolved entries are terminal queue states and require explicit
manual Send, Edit, or Remove. Manual Send resets failed, retrying, and unresolved
heads through `resetQueueItemForDispatch` before one new send attempt. Reconciliation persists
its check count, deadline, and `nextCheckAt`; in-flight requests own no timer,
while the global scheduler wakes once at the earliest persisted next check. A
max-check or deadline terminal result becomes unresolved and triggers no auto
POST.
Legacy migration preserves known bound owners and places unresolved entries in
an unbound legacy scope until an explicit bulk send bind. Legacy rows remain
visible in that scope. Queue UI selects one scope or one item at a time; it
avoids broad ledger subscriptions, cross-scope scans in render paths, and
selector allocations that amplify queue updates.

## Selector Rules

Use leaf selectors.

Good:

- `useGitStatus(directory)`
- `useGitBranches(directory)`
- `useGitBranchLabel(directory)`
- `useGitRepoStatusMap(directories)`
- `usePrVisualSummaryByKeys(keys)`

Bad:

- `useGitStore((state) => state.directories)` in feature components
- `useGitHubPrStatusStore((state) => state.entries)` in feature components
- render-time scans over every PR entry for a single project/group badge

Why this matters:

- Zustand reruns selectors on every `set`
- rerenders are avoided only if the selected result stays referentially stable
- broad subscriptions magnify fanout even when only one directory changed

## Performance Rules

### 1. Preserve references for unaffected entities

If directory `A` changes, directory `B` should keep the same derived reference where possible.

### 2. Keep loading state per entity

Do not add new global `isLoadingWhatever` flags for keyed cache work.

### 3. Avoid hidden work

If a surface is not visible, it should not keep refreshing Git/PR state.

Examples:

- `PullRequestSection` may watch a PR while visible
- `SessionSidebar` may bootstrap missing PR data for expanded visible groups
- hidden sidebar should not watch PRs

### 4. Prefer one-shot event hints over polling

Example already in use:

- successful mutating tools emit a centralized Git refresh hint through `sessionEvents`
- visible `GitView` / `DiffView` consume the hint and refresh current-directory status

This is preferred over background polling.

### 5. Treat `diffStats` carefully

`GitStatus.diffStats` may be omitted by light status fetches.

Rules:

- do not erase richer existing `diffStats` with a lighter payload
- if a UI surface requires per-file `+/-` stats, it must ensure a full enough status payload exists

### 6. Keep diff cache bounded

Diff cache has explicit limits because large repos can otherwise blow up memory.

Do not raise limits casually.

## Refresh Model

### Git

Expected model:

- `GitView` / `DiffView` ensure current-directory Git state when visible
- explicit Git actions refresh status/branches/log as needed
- successful file-mutating tools can issue a one-shot Git refresh hint
- no root-level background Git polling

### PR

Expected model:

- `PullRequestSection` is the only true live PR watcher
- `SessionSidebar` may do one-shot bootstrap for expanded visible project/worktree groups if PR info is missing
- no live PR work for header
- no background PR sweeps outside visible demand

## Known Intentional Fallbacks

There is still one explicit fallback path worth knowing about:

- `SessionSidebar` may call `checkIsGitRepository(...)` during initial worktree/project discovery when store state is not populated yet

This is currently acceptable as a narrow bootstrap fallback.

Do not widen it into a polling or broad refresh system.

## When Editing These Stores

Before changing store shape or selectors, ask:

1. Is this keyed by the right identity (directory, branch, session, root)?
2. Will this force unrelated consumers to rerender?
3. Should this be visible-demand-driven instead of background-driven?
4. Is there already a store cache for this data?
5. Am I duplicating fetch ownership in a component when it should live in a store action?

## Validation Checklist

After meaningful Git/PR store changes, verify manually:

1. Idle desktop app stays quiet on draft/chat screen.
2. Git view still loads status, branches, log, identity.
3. Diff view still opens the correct file and stays in sync.
4. Worktree sessions still show branch labels in header.
5. Expanded sidebar projects/worktrees can show PR state without requiring prior selection.
6. Hidden surfaces do not reintroduce live background work.
