# Sync architecture, event handling & store update rules

## Scope

This document covers the current client-side session/data architecture in `packages/ui/src/sync` and the rules for updating stores safely.

There are **two distinct session data scopes** in the UI:

1. **Directory-scoped sync stores**
   - Owned by the sync layer child stores created in `sync-context.tsx`
   - Source for per-directory live session/message/part/permission/question state
   - Backed by SSE / directory-scoped polling
   - Read via hooks like `useSessions()`, `useDirectorySync()`, `getSyncSessions()`, `getDirectoryState()`

2. **Global sessions cache**
   - Owned by `packages/ui/src/stores/useGlobalSessionsStore.ts`
   - Shared source of truth for the Sessions sidebar global lists and Session Retention cleanup
   - Holds:
     - global active sessions
     - global archived sessions
     - active sessions indexed by directory

These two scopes are intentionally different, but they are no longer equal peers for live UI truth.

### Why both exist

The directory-scoped sync stores are **not** a complete global view.

- They are created lazily per directory
- They only contain data for directories initialized in the current app session
- They are optimized for live per-directory domain data
- They do not maintain the complete global active+archived session view needed by the sidebar and retention settings

So:

- Use the **directory sync stores** for per-directory live session/message state
- Use the **global sessions store** for cold/global session coverage (especially archived pages and unopened directories)
- Use **aggregated child-store snapshots** for live session/status truth across already initialized directories
- Sidebar-only consumers may create and subscribe to a child store with
  `ensureChild(directory, { bootstrap: false })`. Global events can still route
  live status/permission updates into that store, but merely rendering a cached
  row must never start the directory's full bootstrap.

## Ownership map

| Layer / Store | Owns | Scope |
|---|---|---|
| child directory stores in `sync-context.tsx` | `session`, `message`, `part`, `permission`, `question`, etc. | One directory |
| `session-ui-store.ts` | Session selection, draft lifecycle, abort prompts, worktree metadata, SDK-facing action entrypoints | App UI state |
| `useGlobalSessionsStore.ts` | Global active sessions, global archived sessions, `sessionsByDirectory` | All opened project/worktree session lists |
| `viewport-store.ts` | Scroll anchors, session memory, loading indicators | App UI state |
| `input-store.ts` | Legacy pending input state plus keyed draft metadata, hydration, and persistence state | App UI state |
| `input-draft-metadata-store.ts` | Validated durable draft metadata, legacy staging, migration markers | Browser storage |
| `selection-store.ts` | Model/agent/variant selections | App UI state |
| `voice-store.ts` | Voice state | App UI state |

### Keyed draft metadata

`input-store.ts` owns memory-first validated `DraftRecord` state keyed by transport identity and draft owner. `DraftRecord` stores attachment metadata only; per-occurrence `AttachedFile` views, missing blob occurrence IDs, and attachment hydration/persistence state remain runtime memory. Local files and VS Code selections use blob locators, while file/http/server URLs use URL locators. Blob put and draft-reference retain complete before a snapshot containing that metadata enters the durability lane; quota and storage failures preserve editable memory views for explicit retry. Removal and replacement persist metadata before releasing old blob references. `moveDraftWithAttachments()` retains destination references, moves metadata, persists, then releases source references; synchronous `moveDraft()` remains URL-only. Hydration isolates transport generation, key epoch, and record identity, so delayed blob reads cannot replace newer attachment views. Disabled persistence keeps drafts and attachment views in memory without IndexedDB work. Legacy session drafts import into the migration's claimed transport; the legacy `new` record remains staged until `claimLegacyNewDraft()` receives its destination key. Queue admission and send ownership transfers remain outside this store.

`input-draft-durability-coordinator.ts` owns serialized draft durability. `input-store.ts` keeps memory-first records and submits scoped candidates through the coordinator; blob materialization, references, metadata ordering, rollback, release cleanup, and move transfers stay behind that boundary. Hydration seeds the coordinator once after migration, persists every touched snapshot, flushes durability before completion, and replays locally dirty keys after the durable baseline is available. Disabled persistence keeps editable memory records and blocks durable admission until re-enabled.

## Session list rules

### Directory-scoped session list

Use the directory-scoped sync store when the UI needs the live session list for the **current directory**.

Examples:

- current chat/session switching
- per-directory session/message bootstrap
- session/message/part SSE updates

### Global session list

Use `useGlobalSessionsStore` when the UI needs a **shared global session cache**.

Current consumers:

- `useSessionAutoCleanup.ts`

### Live cross-directory session/status view

Use the sync hooks backed by aggregated child stores when the UI needs **live truth** for sessions or statuses across all initialized directories.

Current consumers:

- `SessionSidebar.tsx`
- `SessionNodeItem.tsx`
- `Header.tsx`
- agent/session activity surfaces using `useGlobalSessionStatus()` / `useAllSessionStatuses()`

Cross-directory selectors subscribe to the narrow child-store field they aggregate. Session aggregation listens to `state.session`; per-session status listens only to that session's `state.session_status` entry. Unrelated streaming events such as `message.part.delta` must not trigger global session/status scans.

`scoped-session-status.ts` owns exact `(directory, sessionID)` status reads and subscriptions. A missing child-store snapshot reads as `unknown`; a successful directory status snapshot with no matching entry reads as `idle`. Its registry subscription rebinds when a requested directory store appears, and status listeners ignore parts plus other session IDs.

Imperative cross-directory session lookups use the cached ID index from `getAllSyncSessionMap()`. The index is rebuilt only when a child store's `state.session` reference changes; permission lineage checks must reuse it instead of rebuilding a full session map per call.

### Mutation responsibility

`useGlobalSessionsStore` is not maintained by SSE directly. It is kept correct by:

1. shared global fetch/reconciliation via `loadSessions()` / `refreshGlobalSessions()`
2. direct mutation from session actions after successful SDK calls:
   - create
   - title update
   - share
   - unshare
   - archive
   - delete
   - retention cleanup batch archive/delete

This keeps cold/global lists responsive without requiring a refetch after every change.

Live activity/status indicators must not depend on this cache. They must derive from aggregated child-store state.

Cross-directory status aggregation resolves duplicate session entries by the
latest live session source. Session-index ordering timestamps and persisted
status transitions are owned by the OpenChamber server's global event
subscriber. Renderer session events update visible metadata only; time-only
session updates, busy/retry transitions, and token/message delta events do not
replace the global session list or write the SQLite index. The session-index
long poll remains active after startup so a user message's ordering revision
promotes that session inside its project immediately.

Sidebar directory refreshes are intentionally bounded snapshots, not full catalogs:

- active and archived requests are independent and capped at 20 rows per directory
- directory-sync bootstrap also loads only 20 root sessions; it no longer performs a 500-row full pagination pass or a 200-row mixed root/child prefetch
- active requests coalesce by directory with bounded concurrency
- active pagination stores a per-directory cursor; reaching the local Show more boundary requests and appends the next 20 roots
- child sessions arrive through live `session.created` events. Historical
  `session.children` recovery is requested only when the user selects that
  parent session; the startup watchdog must not fan out one request per active
  or persisted parent
- `loadingDirectories` means no usable active snapshot; `refreshingDirectories` keeps stale rows visible
- archived rows load only when the archived bucket is expanded
- retention must wait for `hasLoadedFullCatalog` and use `ensureFullGlobalSessionsLoaded()`, never treat a bounded directory snapshot as authoritative for cleanup

### Runtime session index cold-start ownership

The runtime session index (SQLite-backed) provides one durable session-summary
source. The legacy per-directory `localStorage` session list is removed
on child-store creation and must not be reintroduced. `main.tsx` establishes a
startup barrier before React effects; `SessionStartupCoordinator` starts the
session-index flow after registered settings hydration, restores the SQLite snapshot,
refreshes each known root/worktree directory through the bounded scheduler,
writes one transaction batch, then releases normal global and directory
bootstrap. A runtime that reports the capability as unsupported uses the
existing bounded SDK-backed path. A successful
empty root page replaces stale index rows; a failed page preserves its last
good cache.

Password-gated runtimes force a fresh settings hydration after authentication
and keep the app tree behind the auth gate until persisted project paths have
been applied. This prevents a pre-authenticated `401` settings request from
becoming the cached startup result consumed by the session coordinator.

## Session message loading

- The imperative session-selection path and the reactive `useSync()` path share
  one app-wide single-flight request keyed by runtime, directory, session,
  requested limit, and pagination cursor. They must not issue duplicate tail
  requests during a React mount or provider remount, and a smaller concurrent
  request must not satisfy a larger request.
- Session materialization coalescing is scoped to the owning directory store.
  A remounted `SyncProvider` must start its own commit path even when the
  runtime, directory, and session ids match an old in-flight request; transport
  single-flight can still share the HTTP response, but the new store must not
  reuse a promise that only commits into a detached store.
- Initial history is a 30-message tail page on every surface. An assistant-only
  partial tail fetches up to eight missing parent user messages by exact message
  ID, then commits the merged records; it never expands to a 100/150-message
  page while searching for a turn boundary. Loading failures are subscribable
  and preserve the prior ready records for retry.
- Message loading status is runtime-scoped. Reactive request de-duplication is
  local to the owning directory-store lifecycle, so a remounted provider still
  commits a shared transport response into its own store.
- Older history is user-driven pagination (`loadMore`) only. Desktop and VS Code
  must not automatically prepend a 100-message page after initial render.
- A rejected shared request is removed from the coordinator so the next
  explicit/reactive attempt can retry; failure must never be cached as an empty
  authoritative history.
- Reconnect recovery may poll lightweight status for multiple active sessions,
  but it materializes `session.get + session.messages` only for the currently
  viewed session. Background busy/incomplete sessions wait until selection and
  continue receiving live events without fetching their bodies.
- A successful directory status snapshot records its conservative request-start
  time. Historical assistant/tool activity that started before that boundary and
  is absent from the active-only snapshot resolves as idle. Activity created
  after the boundary waits for live status, and a failed snapshot preserves the
  previous unresolved state.
- The periodic status watchdog polls only sessions with live `busy` or `retry`
  status. Historical incomplete messages participate in one-shot reconnect
  recovery without keeping a directory on the five-second polling path.
- Network session-detail and message-page reads for the current selection use
  high fetch priority; background materialization of other sessions does not.
  Broad
  cold-start discovery reads (status, config, Git, quota, and bounded session
  lists) use low priority, so opening a chat is not stuck behind an already
  queued bootstrap burst. This is only a direct-network scheduling hint; relay
  request ordering and request payloads are unchanged.

## Runtime endpoint lifecycle

- A runtime transport identity change means the normalized direct endpoint URL
  or relay descriptor changed. A direct-runtime key alias on the same endpoint
  is storage metadata, not a transport change, and must not reset app state or
  remount `SyncProvider`.
- Updating a bearer token or request headers for the same endpoint is a
  credential refresh, not a runtime switch. It must update transport auth in
  place without re-running global bootstrap, authentication checks, or opening
  another global event stream.
- Startup host restoration can publish several intermediate endpoint identities
  in one short burst. App reset and authentication consumers coalesce that burst
  and apply only its final identity; never remount `SyncProvider` once per
  intermediate host/token state.

### Queue transport and admission invariants

- `message-queue-runtime-controller.ts` owns the v4 queue runtime snapshot,
  hydration state, mutation serialization, and scope-reference stability.
  `message-queue-runtime.ts` exposes a lazy default facade. Importing it and
  obtaining the facade perform zero storage, migration, hydration, or
  reconciliation work; explicit `hydrate()` opens that durable boundary.
  Every mutating call captures its runtime at the public API boundary; a queued
  serialized operation retains that capture through blob and metadata work.
  `message-queue-dispatch.ts` is the dependency-injected v4 dispatch boundary.
  It owns send acquisition, durable sending/reconciliation transitions, exact
  confirmation, and the pure one-head-per-scope scheduler planner.
  The v3 production queue remains authoritative until the Lane 4 atomic cutover.

- `queue-attachment-coordinator.ts` owns queue and send blob references. Queue
  references use `queueItemID`; temporary send references use `operationID` and
  monotonic BigInt-derived string acquisition tokens. Token-matched release owns send cleanup.
  Admission acquires queue references before persisting v4 metadata and rolls
  them back on a failed write. Removal persists metadata before releasing both
  reference classes; release failures enter its retryable cleanup ledger.
- The coordinator serializes every operation and validates runtime transport,
  generation, and currentness before commit. The v4 ledger is authoritative for
  queue desired references during hydration/reconciliation. Live reconciliation
  includes active send references; startup reconciliation begins with an empty
  send desired set and clears stale send ownership. Cleanup entries are discarded
  when the same queue or send reference becomes desired again.
- A metadata write that completes as the runtime becomes stale still becomes the
  controller's durable baseline before the caller receives its `stale` result.
- Partial or corrupt v4 hydration enters a recovery-required read-only state.
  Valid rows from a partial snapshot remain visible, while every metadata or blob
  mutation waits for a complete authoritative hydrate. Disabled hydration reads
  and seeds the baseline while performing zero blob mutations and metadata writes.

- Queue ownership uses stable transport identity plus directory and session ID.
  Legacy bulk binding persists one snapshot, prepends bound rows, and cleans the
  source references after commit.
  Runtime generation captures the active transport lifetime; delayed work validates
  that generation before committing to a child store or queue scope.
- Child-store async work captures its owning store and directory. Shared HTTP
  responses may serve concurrent requests, while each live child store commits
  only through its own current capture.
- Queue failures classify as pre-dispatch retry, ambiguous dispatched
  reconciliation, or definitive rejection. Reconciliation confirms through the
  response or HTTP records before a queued item is removed.
- Reconciliation keeps persistent `reconciliationChecks`, `reconciliationDeadlineAt`,
  and `reconciliationNextCheckAt`. In-flight checks own no timer; each miss writes
  the next persistent check time, which drives the single global scheduler wake.
  Exhausted checks or a reached deadline resolve to editable `unresolved` items;
  Edit and Remove release that terminal state without another POST.
- Message-sent confirmation precedes dependent queue side effects. A composer
  queue admission completes before it consumes inline drafts, body text, or
  attachments. Local chat commands retain these composer resources across both
  successful actions and action failures. Legacy queue rows remain visible in
  their legacy scope until an explicit send path performs a bulk bind into the
  active bound scope.

## Session action rules

Session actions live in `session-actions.ts` and are the canonical place for SDK-calling session mutations that affect global session lists.

Rules:

1. If an action mutates session list membership or visible session metadata, update `useGlobalSessionsStore` there.
2. If an action targets a session by ID, resolve the **session's own directory**. Do not assume the current directory is correct.
3. `session-ui-store.ts` should delegate to `session-actions.ts` for these mutations instead of duplicating SDK calls.
4. `setCurrentSession()` announces a monotonic session-switch intent before directory resolution or store publication. Delayed visual/transition callbacks must validate that intent and silently discard stale work.
5. Sidebar previous/next navigation is scope-aware. `SessionSidebar` publishes the Recent order plus logically visible project rows to `session-navigation.ts`; keyboard and native-menu actions share that registry and update the explicit session Focus before committing current-session authority. Project-origin navigation is restricted to the current expanded project and never falls through to hidden rows or another project.
6. Global Mod+1…9 navigation is session-row based, not project based. `SessionSidebar` combines the currently revealed Recent rows with logically visible project rows, caps the visual order at nine, and publishes it through `sidebar-numbered-navigation.ts`. The numbered activation preserves the selected row's exact Recent/Project Focus identity.

Examples of global-store updates performed in `session-actions.ts`:

- `createSession()` -> `upsertSession(session)`
- `updateSessionTitle()` -> `upsertSession(result.data)`
- `shareSession()` / `unshareSession()` -> `upsertSession(result.data)`
- `archiveSession()` -> `archiveSessions([id], archivedAt)`
- `deleteSession()` -> `removeSessions([id])`

### Fork transition and event isolation

OpenCode publishes one `message.updated` event per cloned message and one
`message.part.updated` event per cloned part while `session.fork` runs. The UI
must not materialize that complete copied history into the directory store.

- Enter the shared fork transition view before dispatching the SDK request.
- Suppress copied message/part events for the target session while the request
  is active.
- When the real session ID arrives, select it and load the normal bounded tail
  page through `fetchMessagesForSession()`.
- Keep a short message-ID cutoff after the response so transport-buffered copy
  events cannot refill the complete history. Newer user/assistant events pass
  through normally.
- A current-session fork during `busy` or `retry` targets the latest user
  message. The active assistant message remains outside the forked history.

### New conversation orchestration

Normal first prompts from an open draft use the optional runtime
`conversations.createWithPrompt` capability. Web and mobile send one
OpenChamber-owned request; the server creates the OpenCode session and admits
the first prompt. VS Code provides the same contract through its extension-host
bridge. Existing sessions, shell input, slash commands, explicit delivery
modes, and older runtimes keep the regular SDK sequence.

The client generates the message ID before the request. The server/runtime host
uses it as the bounded operation key, so reconnect retries reuse the in-flight
or completed operation instead of creating another session. The draft remains
visible in a submitting state until a real session ID is returned.

After success, commit the real session to directory routing, global session
state, selection state, and the optimistic shadow map. If SSE delivered the
message first, preserve that authoritative object and skip optimistic insertion.
Create-phase failures restore the draft and input. Prompt-phase failures keep
the created session; ambiguous delivery is confirmed by message ID and is never
automatically re-submitted.

### Queue dispatcher execution invariants

`message-queue-dispatch.ts` keys flights by scope, queue item, operation, and
message IDs. Dispatch, reconciliation, and sending recovery share that identity
flight. Payload acquisition returns a monotonic token; each non-confirmed path
releases its own token. Durable confirmation removes queue and send references
before one best-effort notification. The planner exposes one head and one
nearest wake per scope; Lane 4 owns session busy and blocked eligibility.

Reconciliation persists `pending` next checks and durable `unresolved` terminal
states. Authoritative misses increment a safe-integer count; unavailable queries
preserve it while scheduling a bounded wake. Hydrated `sending` rows recover by
persisting `sending → reconciling` without a POST.

## The golden rule

When creating a draft in `handleDirectoryEvent`, **only clone the state fields the event will mutate**. Never spread all fields eagerly.

```typescript
// WRONG — clones everything, breaks referential equality for all subscribers
const draft = {
  ...current,
  session: [...current.session],
  message: { ...current.message },
  part: { ...current.part },
  permission: { ...current.permission },
  // ...
}

// RIGHT — only clone what this event type touches
const draft = { ...current }
switch (event.type) {
  case "message.part.delta":
    draft.part = { ...current.part }
    break
}
```

## Why this matters

Zustand skips re-renders when a selector returns the same reference (`Object.is`). If you spread `session: [...current.session]` but the event only modifies `part`, the `session` array gets a new reference. Every component using `useSessions()` re-renders for nothing.

During streaming, `message.part.delta` fires ~60 times/sec. Eagerly cloning all fields caused every subscriber in the entire app to re-render 60/sec — a 10x overhead. Targeted cloning reduced MessageList renders from ~1972 to ~296 per session.

## Event → field mapping

Keep this in sync with `handleDirectoryEvent` in `sync-context.tsx`:

| Event type | Fields to clone |
|---|---|
| `session.created/updated/deleted` | `session`, `permission`, `todo`, `part` |
| `session.diff` | `session_diff` |
| `session.status` | `session_status` |
| `todo.updated` | `todo` |
| `message.updated` | `message`, `part` when a loaded session observes a new assistant before its first part |
| `message.removed` | `message`, `part` |
| `message.part.updated/removed/delta` | `part` |
| `vcs.branch.updated` | (none — mutates `draft.vcs` directly) |
| `permission.asked/replied` | `permission` |
| `question.asked/replied/rejected` | `question` |
| `lsp.updated` | `lsp` |

## Adding a new event type

1. Add the case to the event reducer (`event-reducer.ts`)
2. Add a corresponding case to the switch in `handleDirectoryEvent` (`sync-context.tsx`) that clones **only** the fields your reducer writes to
3. If your event fires frequently (more than a few times per second), verify that unrelated components don't re-render — check with the stream perf counters

## Selector hygiene

Select leaf values, not containers:

```typescript
// WRONG — returns entire Map/object, new reference on any mutation
useDirectorySync((s) => s.permission)

// RIGHT — returns the value for one key, stable unless that key changes
useDirectorySync((s) => s.permission[sessionID] ?? EMPTY)
```

Same applies to `useStreamingStore` — select `.get(key)` not the Map itself.

## Store splitting pattern

### Why split

A single Zustand store with N properties means every subscriber's selector re-evaluates on every state change — even if the change is unrelated to what that subscriber reads. During streaming, `sessionMemoryState` updates ~60/sec. Before the split, all 68+ `useSessionUIStore` subscribers re-evaluated on each update. After splitting into focused stores, only `useViewportStore` subscribers (2-3 components) re-evaluate.

The optimization multiplies with targeted event cloning: fewer new references per event × fewer subscribers per store = dramatically less work per SSE frame.

### The stores

| Store | Owns | When it changes |
|-------|------|-----------------|
| `session-ui-store.ts` | Session selection, draft lifecycle, abort, worktree, SDK actions | Session switch, draft open/close |
| `voice-store.ts` | Voice connection/activity state | Voice toggle |
| `input-store.ts` | Pending input text, synthetic parts, attached files | User typing, file attach, revert/edit/fork |
| `selection-store.ts` | Per-session model/agent/variant choices | Model/agent picker |
| `viewport-store.ts` | Scroll anchors, session memory state, sync status | Streaming, scroll, session switch |

### Rules for new UI state

1. **Never add to `session-ui-store`** unless it's session selection, draft lifecycle, or abort state
2. **Group by change frequency** — state that changes during streaming (viewport, memory) must not live with state that changes on user action (selections, input)
3. **Group by subscriber set** — if only 2 components read a value, it should be in a store that only those 2 components subscribe to
4. **Prefer a new store over growing an existing one** if the new state has different subscribers or change frequency
5. **Cross-store reads use `.getState()`** — actions in one store that need to read another store call `useOtherStore.getState()` (imperative, no subscription)

### Anti-patterns

```typescript
// WRONG — stuffing unrelated state into one store
const useEverythingStore = create(() => ({
  voiceMode: "idle",
  scrollAnchor: 0,
  selectedModel: null,
  pendingInput: "",
  // 20 more fields...
}))

// RIGHT — separate stores by concern + change frequency
const useVoiceStore = create(() => ({ voiceMode: "idle" }))
const useViewportStore = create(() => ({ scrollAnchor: 0 }))
const useSelectionStore = create(() => ({ selectedModel: null }))
const useInputStore = create(() => ({ pendingInput: "" }))
```
