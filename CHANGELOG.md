<path>/Users/yee.wang/Code/github/openchamber-yee/CHANGELOG.md</path>
<type>file</type>
<content>
1: # Changelog
2: 
3: All notable changes to this project will be documented in this file.
4: 
5: ## [1.16.38] - 2026-07-20

- **Event-driven sync:** replace session-index and message-queue long-polling with SSE revision tips so clients refresh snapshots only after authoritative changes or stream reconnects.
- **Queue dispatch:** let authoritative idle sessions dispatch queued messages as soon as the trailing assistant turn arrives, instead of waiting for `time.completed` metadata that added a visible drain gap.
- **Git discovery:** cap concurrent primary-root and worktree discovery requests, dedupe in-flight lookups, and share the same network gate with runtime-backed Git bridges.
- **Snippet expansion:** expand `#hashtag` references in the composer through a shared snippet registry with alias resolution, prepend/append blocks, and cycle protection.
- **Response style:** cache response style settings locally so queued and auto-send prompts can inject style instructions without a settings round trip.
- **Message queue runtime:** tighten transport capture checks, scope hydration, and invalidation handling across server-backed queue surfaces.

## [1.16.37] - 2026-07-20
6: 
7: - **Mobile tool diffs:** support multiple tool patches in the mobile diff navigator, adjusting `PendingMobileChangesDiff` to handle arrays of patches and updating the UI to display the complete tool-patch set.
8: - **Diff patch utilities:** extract shared patch-path extraction and multi-patch resolution into `diffPatchUtils`, with coverage for multi-file edits and `apply_patch` tool calls.
9: - **Global search placement:** add the global-search button alongside session-title controls on mobile and desktop, maintaining a consistent title-bar layout across surfaces.
10: - **Session revision data:** align context-panel and diff-view presentation with the authoritative session snapshot to keep show-revision and navigation state consistent.
11: - **Test coverage:** extend tool navigation, patch handling, session-UI store, and diff-view test suites for the multi-patch and revision-resolution paths.
12: 
13: ## [1.16.36] - 2026-07-20
14: 
15: - **Queued model routing:** resolve each session's selected agent, provider, model, and variant when admitting queued messages, then preserve that captured configuration through manual and automatic delivery.
16: - **Queue consistency:** share one send-configuration resolver across server-backed admission, legacy queue admission, and queued auto-send fallback paths.
17: - **Message history:** load older conversation history in consistent 30-message pages across desktop, VS Code, Web, and mobile surfaces.
18: - **Dispatch contract coverage:** verify that queued OpenCode prompts forward the exact model, agent, variant, message identity, directory, and parts payload.
19: 
20: ## [1.16.35] - 2026-07-20
21: 
22: - **Mac queue dispatch:** separate durable OpenChamber runtime identity from the upstream OpenCode endpoint so queued messages continue automatically after the active turn completes.
23: - **Queue delivery confirmation:** retain asynchronously accepted prompts in reconciliation until an exact message event or authoritative lookup confirms delivery, preventing premature queue removal and missing chat messages.
24: - **Queued attachments:** allow the scoped upload token and SHA-256 headers through packaged-client CORS preflight so local attachments can enter the server-backed queue.
25: - **Session and mention recovery:** resolve exact session references across directories and keep file-mention delivery aligned with the owning runtime and session.
26: - **Desktop lifecycle:** force-close remaining local HTTP connections during shutdown so app replacement and relaunch complete cleanly.
27: - **Navigation and Git:** refine command-palette placement and project results, and show the total pending commit count on Git sync actions.
28: 
29: ## [1.16.34] - 2026-07-20
30: 
31: - **Queued-message delivery:** make manual queue sends bypass busy-session settlement checks while retaining availability and durable dispatch fencing.
32: - **Queue reliability:** preserve manual dispatch intent across retries, wait for OpenCode readiness with the correct adapter contract, and generate OpenCode-compatible ascending message IDs so sent items appear in the current chat order.
33: - **Session recovery:** materialize exact sessions and messages from their owning directory when bounded bootstrap data omits the active session, restoring Send and Queue actions across older and cross-directory sessions.
34: - **Session deletion:** keep deleted sessions hidden throughout the undo window and reconcile authoritative session lists without resurrecting pending deletions.
35: - **Navigation surfaces:** improve command palette, sidebar top bar, and context-panel session behavior with consistent retained-session state and responsive dialog presentation.
36: 
37: ## [1.16.33] - 2026-07-20
38: 
39: - **Server-backed message queue:** add durable SQLite-backed queued messages with per-session ordering, concurrent delivery across sessions, retries, idempotent dispatch, restart recovery, and automatic migration from existing client queues.
40: - **Queued attachments:** persist queued-message attachments on the server with filename and MIME metadata, upload limits, secure storage, cleanup, and delivery recovery.
41: - **Queue synchronization:** synchronize queue edits, deletion, reordering, delivery state, and worktree lifecycle across Web, Electron, VS Code, hosted mobile, and Capacitor mobile clients.
42: - **Worktree topology:** persist custom worktree ordering, reconcile created and deleted worktrees with queued-message state, and restore known worktree directories during startup recovery.
43: - **Tool diff navigation:** open the exact file patch from `edit`, `multiedit`, and `apply_patch` tool calls across desktop, Web, and mobile diff surfaces.
44: - **Session streaming reliability:** improve SSE and WebSocket response timeouts, heartbeat tracking, empty-chunk handling, reconnect behavior, and recovery for busy sessions whose content stream has stalled.
45: - **Session reconciliation:** refresh stale message metadata from authoritative snapshots while preserving earlier local history and actively streaming message parts.
46: - **Desktop lifecycle:** gracefully stop the embedded OpenChamber server during Electron quit, restart, and update installation.
47: 
48: ## [1.16.32] - 2026-07-19
49: 
50: - **Responsive Web sessions:** add 500ms long-press action sheets for project, worktree, and session rows in the mobile Web sessions panel, with project sync and creation actions, worktree creation and confirmed deletion, plus session pin, share, and archive actions.
51: - **Touch selection:** cancel holds during scrolling or pointer cancellation, consume the generated click, suppress native touch callouts, and continuously clear browser text selection while an action sheet is open so session titles no longer retain a blue selection highlight.
52: - **Mobile interaction ownership:** move the shared long-press controller into the UI primitives layer so dedicated mobile and responsive Web surfaces use the same gesture thresholds and cleanup behavior.
53: - **Subagent banner:** keep agent and model on one row on narrow screens, and use a smaller shared type size for the read-only prompt message and metadata.
54: 
55: ## [1.16.31] - 2026-07-19
56: 
57: - **Composer IME:** keep native composition ownership over textarea value, selection, and atomic-reference correction until `compositionend`, preventing iOS marked text from becoming a native blue selection.
58: - **Session identity:** show the subagent read-only prompt banner only after the current directory confirms a session `parentID`; keep loading, missing, root, cached cross-directory, and generic read-only states free from false subagent banners.
59: - **Context transcripts:** derive read-only subagent presentation from the directory-scoped authoritative session entity in retained context-panel transcripts.
60: - **Mobile sessions:** clear pending long-press timers and click suppression when the sessions sheet unmounts, with coverage for quick taps, movement cancellation, reset, and context-menu closure.
61: - **iOS dependencies:** refresh the locked GoogleUtilities pods from 8.1.1 to 8.1.2.
62: 
63: ## [1.16.30] - 2026-07-19
64: 
65: - **Mobile chat:** preserve mobile worktree, project filter, and expanded group state across session-sheet refreshes; improve parent-session navigation and read-only prompt behavior.
66: - **Composer document:** add strict durable-document parser with serialization, equality validation, resource descriptions, and queue-canonical representation for v3/v4 message queues.
67: - **Composer mentions:** confirm authored file/agent mentions through the entire queue pipeline — admission, payload dispatch, ledger serialization, v3 migration, draft edit bridge, and attachment coordinator — with UTF-16 boundary validation and strict range enforcement.
68: - **Chat composer:** integrate confirmed file/agent mention passing from input to queued message creation; add send-plan and delivery modules for steerable queue dispatch.
69: - **Composer input:** preserve IME and native dictation edits when textarea reconciliation keeps the browser value and selection unchanged; apply text correction only when Session or Paste reference ranges cross the browser edit boundary.
70: - **Prompt availability:** separate read-only prompt guidance from submission blocking with shared availability rules and focused coverage.
71: - **UI event handling:** migrate cross-surface callbacks to stable `useEvent` handlers across mobile, multirun, session dialogs, integrations, and theme synchronization.
72: - **Composer highlighting:** render image-aware inline attachment icons and keep highlighted reference ranges aligned with composer edits.
73: - **Mobile session actions:** add long-press project, worktree, and session action surfaces with movement cancellation, click suppression, rename, pin, share, archive, delete, and clipboard flows.
74: - **PermissionCard:** refactor with structured metadata views via JsonSummaryView, i18n labels for Replace All, response format, Allow Once, and Always Agree; normalize metadata keys for consistent field display.
75: - **i18n:** add permission-card locale entries across all 11 supported languages.
76: - **Session reliability:** preserve session view state, reconcile stale directories from the authoritative index, and replay turn-diff navigation when context tabs reopen.
77: - **Queue reconciliation:** improve queue reconciliation, scope queued-message abort blocking to runtime and directory, and add reconciliation test coverage for ambiguous-dispatch edge cases.
78: - **Sidebar and navigation:** refine session navigation model with worktree state carry-over, improve session group section pinned-session handling, and add navigation model tests.
79: - **Unicode and metrics:** add unicodeMetrics utility with UTF-16 surrogate-pair boundary detection and text character-width analysis.
80: - **Foundation:** add session-prefetch cache, current-session entity hydration, sync store refinements, and planned infrastructure for streaming input-store integration.
81: - **Electron and developer tooling:** remove developer-only help log from queue worker, prune surplus Electron README note, and add composer delivery benchmarks.
82: 
83: ## [1.16.29] - 2026-07-19
84: 
85: - **Mobile chat:** add session mentions with autocomplete, bounded conversation context injection, and persistent large-paste references with expansion, highlighting, and deletion controls.
86: - **Diff review:** add direct file and turn diff surfaces across mobile sheets, iPad panels, and context panels, with changed-line navigation and improved patch metadata handling.
87: - **Scheduled tasks:** add project-scoped daily, weekly, one-time, and cron scheduling with timezone support, model and agent selection, manual runs, status events, concurrency limits, retries, and partial-failure isolation.
88: - **Scheduled-task automation:** add the `scheduled_task` OpenCode tool with permission prompts, managed capability bridging, authoritative session validation, and persisted task mutations.
89: - **OpenCode startup:** improve managed and external process ownership, HMR recovery, capability identity rotation, failed-child cleanup, onboarding availability polling, and manual startup retry.
90: - **Model selection:** add a reusable mobile model picker with provider and model search, favorites, recents, metadata, variants, filtering, and shared support across chat, agents, and scheduled tasks.
91: - **Chat and session reliability:** scope queued-message abort blocking to runtime and directory, improve queue reconciliation, preserve session view state, and replay turn-diff navigation when context tabs reopen.
92: 
93: ## [1.16.28] - 2026-07-18
94: 
95: - **Mobile projects:** connect the new-project action in the mobile draft project picker to the mobile directory explorer so users can create or add a project from the composer.
96: - **Mobile directory explorer:** consistently use the mobile overlay from mobile session surfaces and separate directory navigation from quick-add controls for reliable touch interaction.
97: - **Mobile composer:** align highlighted mirror text with textarea typography, spacing, wrapping, and line height so highlighted input and the caret stay synchronized across wrapped lines.
98: 
99: ## [1.16.27] - 2026-07-18
100: 
101: - **Mobile sessions:** keep session-sheet presentation progress anchored to the initial touch so rightward opening, leftward cancellation, and renewed rightward opening follow the same distance while threshold haptics remain stable.
102: 
103: ## [1.16.26] - 2026-07-18
104: 
105: - **Mobile sessions:** require clear reversal intent before cancelling a session-sheet presentation to reduce release-direction jitter.
106: - **Release integrity:** validate the complete artifact inventory through the draft Release ID so the final publication gate can inspect every asset before publishing the tag.
107: 
108: ## [1.16.25] - 2026-07-18
109: 
110: - **Mobile sessions:** preserve the session window's rendered elements, scroll position, project filter, expanded worktree groups, and pagination state across presentations while continuing to refresh authoritative session data.
111: 
112: ## [1.16.24] - 2026-07-18
113: 
114: - **Shared data layer:** migrate agents, commands, installed skills, MCP, GitHub authentication, plugins, skills catalogs, files, and plans to runtime-scoped TanStack Query caches with cancellation, retries, request sharing, bounded freshness, and stale-result protection.
115: - **Configuration isolation:** key configuration data by runtime transport and normalized directory, preserve complete snapshots across refresh failures, clear caches on runtime changes, and refresh only the affected scope after mutations.
116: - **Settings and stores:** make Query the owner of server-backed configuration state while stores retain selection, drafts, mutation progress, and diagnostics; update Settings search and configuration pages to consume the same authoritative snapshots.
117: - **Commands and skills:** batch agent and command metadata reads, resolve cold-cache slash commands before sending, and use the effective session, worktree, or draft directory consistently for composer highlighting, autocomplete, starter chips, skill links, and send-time command classification.
118: - **Plan editor:** add directory- and runtime-scoped plan resolution with explicit missing-file handling, per-document revisions, serial saves, pending-write flushes, retryable failures, stale-completion rejection, and cache updates after successful writes.
119: - **Diagram editor:** move diagram reads into the shared file cache, keep file switches isolated, update cached content after successful writes, and preserve the editor baseline when a save fails or returns an unsuccessful result.
120: - **Files and mobile:** unify directory listing, search, file content, and file status queries across shared and mobile surfaces; distinguish empty files from missing optional files and prevent older directory requests from replacing current results.
121: - **Mobile interaction:** add progressive previous/next session feedback while swiping across chat, signal the commit threshold with native haptics, and provide light haptic feedback for enabled button presses in Capacitor apps.
122: - **MCP and integrations:** unify MCP configuration and live status queries across Settings, dropdown, and mobile surfaces; scope connect, disconnect, OAuth, and configuration refreshes to their runtime and directory while surfacing status failures clearly.
123: - **Plugins, skills catalogs, and GitHub:** add shared authentication snapshots, resilient catalog pagination and deduplication, bounded source requests, registry normalization, and mutation-driven cache invalidation across Settings and picker dialogs.
124: - **Web and VS Code parity:** add batched configuration metadata routes, project-directory forwarding for agents, commands, skills, catalogs, and files, plus an optional-read contract across the Web server, VS Code bridge, and local filesystem proxy.
125: - **Routing and chat reliability:** keep valid session deep links stable after startup, reconcile stale session directories from the authoritative index, close text-selection menus synchronously during session switches, and refine composer leader-key hints.
126: - **Mobile windows:** add a shared motion and stacking system for top, bottom, left, and right overlays, with edge-aware dismissal, nested-scroll ownership, final-frame settlement, focus management, and near 1:1 touch tracking.
127: - **Mobile sessions:** group sessions by project root and worktree with branch labels, bounded expansion and remote pagination, add worktree creation, close the panel consistently after navigation, and reduce the header-swipe opening distance to 35% of the viewport.
128: - **Localization:** detect supported browser language preferences at startup, including regional Traditional Chinese and Portuguese variants, while preserving explicit locale selections.
129: - **Runtime compatibility:** generate WebView-compatible UUID v4 identifiers for drafts, queued messages, folders, plans, todos, remote instances, and connection metadata when the native random UUID API is unavailable.
130: - **Release integrity:** keep GitHub Releases in draft until the complete Desktop, Android, VSIX, blockmap, and update-manifest inventory passes validation, including a combined dual-architecture macOS update manifest.
131: 
132: ## [1.16.23] - 2026-07-18
133: 
134: - **Git workspace:** streamline branch, sync, history, stash, stage, and revert controls with pinned headers and aligned actions across tree and flat change views.
135: - **Async workflows:** add runtime-scoped query caching, cancellation, pagination, stale-result protection, and cache resets across web, desktop, mobile, and VS Code surfaces.
136: - **Chat and navigation:** restore composer focus after model or agent selection, refine queued-message controls and terminal shortcuts, improve message forking, and remove citations when attachments are deleted.
137: - **Session reliability:** hide temporary SmartFetch secondary sessions from live and indexed session lists while preserving pagination and clearing existing summaries.
138: - **Files and integrations:** improve mobile file browsing, GitHub issue and pull request search, scheduled tasks, diagrams, PWA detection, server text-to-speech, provider state, and quota refresh behavior.
139: 
140: ## [1.16.22] - 2026-07-17
141: 
142: - **Mobile composer:** tighten queued, reverted, and auto-review controls with smaller typography and denser spacing while preserving touch targets.
143: - **Mobile context:** replace the session metadata app icon with a live context-usage progress ring while preserving the existing metadata panel interaction.
144: - **Message actions:** show pending feedback and prevent duplicate revert or fork actions in message controls and the timeline.
145: 
146: ## [1.16.21] - 2026-07-16
147: 
148: - **Sessions:** add undoable archive and delete actions with a recovery window, plus archived-session browsing and restore controls.
149: - **Sidebar:** refine pinned sessions, project pagination, archive/delete actions, and modifier shortcut hints across desktop and mobile.
150: - **Chat and queues:** improve queued-message delivery, attachment deduplication, draft presets, and session-title continuity.
151: - **Mermaid:** add smoother pan and zoom controls, source copying, and SVG download support.
152: - **Reliability:** reduce startup and background request storms, improve runtime recovery, and pause hidden or inactive polling work.
153: 
154: ## [1.16.20] - 2026-07-16
155: 
156: - **Sidebar:** refine Mod+1…9 shortcut hints into compact inline chips that replace row actions while the modifier is held.
157: 
158: ## [1.16.19] - 2026-07-16
159: 
160: - **Sessions:** add undoable archive and delete actions with a 10-second recovery window, plus an archived-session manager for browsing and restoring sessions.
161: - **Sidebar:** simplify pinned session rows, improve project pagination with Show more/Show fewer controls, and streamline archive/delete actions across desktop and mobile.
162: - **Queued messages:** improve delivery ordering, message ID generation, persistence flushing, retry handling, and reconciliation across runtime changes and directory-scoped sessions.
163: - **Chat composer:** prevent duplicate pasted images, deduplicate optimistic attachments, and add expandable attachment and draft-preset layouts.
164: - **Mermaid:** add smoother pan, wheel zoom, pinch zoom, copy-source, and SVG download controls.
165: - **Session titles:** improve topic continuity, language selection, fork-title refreshes, and protection for manually renamed sessions.
166: - **Files and workspace:** align folder icon treatments across mobile, sidebar, file, and changes views, and refine the web sidebar brand layout.
167: - **Localization:** add translated copy for archived sessions, undo actions, pagination, and related settings across supported languages.
168: - **Documentation:** refresh the project overview in English and Chinese with current product screenshots.
169: 
170: ## [1.16.18] - 2026-07-16
171: 
172: - **Startup reliability:** remove the permission-control visibility probe that queried OpenCode during composer mount, preventing startup request storms when the managed server is still initializing.
173: - **Runtime requests:** coalesce health, upgrade-status, and other idempotent reads by runtime, transport, and credential generation, with short failure cooldowns for unavailable OpenCode instances.
174: - **Embedded chats:** pause hidden iframe initialization and background recovery work; keep upgrade checks on the primary app surface.
175: - **Files:** pause external-change polling for inactive editor tabs and avoid repeated hidden `fs/stat` traffic.
176: - **Desktop:** fix an Electron `Illegal invocation` crash caused by unbound native timer calls in the delayed upgrade check.
177: 
178: ## [1.16.17] - 2026-07-16
179: 
180: - **Chat:** new session send now shows a full-screen establishing page immediately (like fork), instead of keeping the draft composer visible during combined create+prompt.
181: - **Fork:** cold-start fork no longer fails silently — source sessions are resolved from the global session index or `session.get` when the directory child store hasn't hydrated yet.
182: - **Keyboard:** first Esc now shows "Press Esc again to abort" in the status row; the abort prompt is visible on every layout including expanded input and desktop.
183: - **Keyboard:** `Ctrl+C` (customizable) clears the composer and any queued messages without interfering with text selection copy.
184: - **Compact:** `Ctrl+X C` compact command no longer fixes a `normalizeCandidatePath` unbound-method error.
185: - **Sessions:** workspace panels (right sidebar + context panel) now restore their per-session state when switching conversations.
186: - **Sessions:** improved sidebar session tree deduplication and pinned session handling.
187: - **Status bar:** moved changed files and pending changes into a unified popover, cleaning up the status row layout.
188: 
189: ## [1.16.13] - 2026-07-16
190: 
191: - **Queued message delivery:** generate OpenCode-compatible `msg_` message identifiers, migrate queued legacy identifiers, and route terminal session events through their directory-scoped status stores so consecutive queued messages dispatch after the active response settles.
192: 
193: ## [1.16.12] - 2026-07-15
194: 
195: - **Composer and queue reliability:** persist drafts and attachment blobs across restarts, migrate queued messages to a transport- and directory-scoped ledger, and reconcile queued sends safely after runtime changes.
196: - **Message editing and delivery:** preserve the original message when opening it for editing, replace a staged turn together with its later messages on confirmation, classify send failures precisely, and emit sent notifications only after server confirmation.
197: - **Attachments:** support large data-URL attachment payloads through OpenChamber session routes and coordinate attachment cleanup across drafts and queued messages.
198: - **Chat navigation and feedback:** open changed files at the selected diff line and provide deduplicated streaming haptics for assistant text, reasoning, and tool activity on mobile.
199: - **Session behavior:** refresh forked-session titles after their first completed exchange and improve cross-store session lookup and fork diagnostics.
200: - **Runtime compatibility:** ensure Node development servers rebuild `better-sqlite3` for the active Node ABI after Electron builds, avoiding native-module load failures.
201: 
202: ## [1.16.11] - 2026-07-14
203: 
204: - **Release:** rebuild the current desktop, mobile, and VS Code artifacts from the `1.16.10` codebase.
205: 
206: ## [1.16.10] - 2026-07-14
207: 
208: - **Session index:** persist live activity timestamps and session status, ingest realtime session events, and preserve ordering across refreshes and restarts.
209: - **Session loading:** improve cross-runtime session recovery, runtime endpoint resets, lazy chunk recovery, and Electron refresh diagnostics.
210: - **Reliability:** expand session-index, event-reducer, global-session, and sync regression coverage.
211: 
212: ## [1.16.9] - 2026-07-14
213: 
214: - **AI summaries:** restrict Provider/model selection to callable summary models and clarify the behavior controlled by each prompt editor.
215: - **Custom API:** validate persisted custom OpenAI-compatible settings and cover save-to-call behavior without exposing API tokens.
216: 
217: ## [1.16.8] - 2026-07-14
218: 
219: - **AI summaries:** add dedicated summary settings for provider, custom OpenAI-compatible models, credentials, and prompts for commit messages and session titles.
220: - **Sessions:** surface live cross-project activity in the sidebar and improve project navigation, ordering, and directory exploration.
221: - **Settings:** improve metadata, search, defaults, localization, and responsive settings layout across supported languages.
222: - **Editor:** expand file-extension language detection and cover the mapping with regression tests.
223: 
224: ## [1.16.6] - 2026-07-14
225: 
226: - **AI summaries:** configure provider or custom OpenAI-compatible models, API credentials, and separate prompts for commit messages and session titles.
227: - **Global configuration:** discover and edit only configuration files available on the current runtime, including `.json` and `.jsonc` variants.
228: - **Projects:** the new-project directory dialog closes its source menu before opening, promotes Add Project to the primary footer action, and keeps already-added folders navigable so their child projects remain accessible.
229: - **Cross-runtime settings:** desktop and VS Code persist the current global configuration selection and refresh small-model configuration after changes.
230: 
231: ## [1.16.5] - 2026-07-14
232: 
233: - **Session titles:** auto-refresh now keeps naming the overall feature/subject across follow-ups and wrap-up turns like commit/push, instead of retitling from the last housekeeping message.
234: - **Keyboard shortcuts:** the Ctrl+X leader chord no longer lets Chinese/Japanese IME composition leak letters into the composer.
235: - **Composer:** model/provider menus return focus to the chat input after Esc/Enter.
236: 
237: ## [1.16.4] - 2026-07-14
238: 
239: - **Composer:** streamline the input toolbar and add the `/goal` system command. Active goals now use a compact, removable outline target state.
240: 
241: ## [1.16.3] - 2026-07-14
242: 
243: - **Global configuration:** saving OpenCode, oh-my-opencode-slim, and oh-my-openagent raw configuration now parses the JSON request body correctly.
244: 
245: ## [1.16.2] - 2026-07-14
246: 
247: - **Session recovery:** clients now reconcile stale running state after disconnects or OpenCode restarts without letting incomplete historical messages keep the composer loading.
248: - **Subagent recovery:** task cards stop their loading state when authoritative parent or child session status confirms interruption, while preserving the original tool history for diagnostics.
249: - **Status polling:** periodic reconciliation follows live busy or retry sessions only, reducing repeated status requests caused by historical incomplete messages.
250: 
251: ## [1.16.1] - 2026-07-14
252: 
253: - **Performance:** large session sidebars stay responsive while chats stream, including setups with many projects, worktrees, and sessions. Opening a long chat after an empty or aborted agent turn also no longer repeatedly loads larger portions of its history.
254: - Chat: an optional Prompt Navigator adds a marker rail beside desktop chats; hover to preview prompts, click to jump between them, or assign a shortcut in Keyboard Shortcuts settings (thanks to @makeittech).
255: - Chat: shell-mode command cards now update their status and output while the command runs, with syntax highlighting for the command and output.
256: - Chat/Subagents: task cards now track the correct subagent when several run at once, preventing one subagent's activity or "Open subtask" action from pointing to another session.
257: - Chat/Subagents: "Open subtask" now works for nested subagents inside the side-panel chat, with a Parent action to return to the previous subagent (thanks to @ameshkov).
258: - Sessions: temporary project lookup failures no longer remove worktree groups from the sidebar.
259: - Small Model: custom OpenAI-compatible providers now use the base URL and API key from OpenCode configuration (thanks to @ameshkov).
260: 
261: ## [1.16.0] - 2026-07-13
262: 
263: - **Session goals:** arm the new target button in the composer and your next prompt becomes a [goal](https://docs.openchamber.dev/session-goals/) — the session keeps working toward it on its own, with an independent small-model audit checking each finished turn, until the objective is verifiably complete, blocked, or over its optional token budget. The loop runs on the server, so it continues with the app closed and survives restarts. A goal strip above the composer shows progress with pause/resume; goals can also start from the plan-implement dialog, from scheduled tasks ("Run as goal"), or with the new "Craft a Goal" starter and `/craft-goal` command. While a goal runs, per-turn "ready" notifications are replaced by a single notification when it settles.
264: - **Usage:** OpenCode Go usage tracking is here, and Codex quota windows now show the correct reset times.
265: - **Remote access:** connecting over the relay got much faster — the app no longer waits for a stale local address to time out before trying the relay (previously up to ~20 seconds on a phone away from home). When your computer gets a new local IP, paired devices now learn the new address over the relay and quietly move back to the local network on their own — no re-pairing. The phone's launch screen shows which device it is connecting to.
266: - Remote access: running several OpenChamber instances on the same machine no longer makes paired devices land on a random one of them — only one process per machine serves the relay now. This was behind intermittent "Unable to reach server" errors on paired phones.
267: - Permissions: per-session auto-accept now lives on the server — sessions keep auto-accepting tool calls while the app is closed and after a server restart, subagent sessions inherit the setting, and it can be enabled on a draft before the first message (thanks to @bashrusakh for the draft fix).
268: - Chat: subagent sessions can now be prompted directly — open a subagent from the context panel and send it follow-up messages (off by default, available in settings).
269: - Chat: queued messages now send when the session is already idle instead of waiting forever in some cases, pending agent questions stay answerable after a server restart, and session renames no longer flicker back to the old title (thanks to @bashrusakh).
270: - Files: the file viewer has a markdown preview toggle (thanks to @greghaynes).
271: - Sidebar: projects can be sorted by different modes with a direction toggle, pinned sessions survive refreshes, and the file tree stays expanded while it refreshes (thanks to @bashrusakh).
272: - Command palette: projects are included in the fuzzy search alongside sessions and files (thanks to @bashrusakh).
273: - Settings: chat visual settings are grouped into labeled sections, and a new editor font size setting for the code editor (thanks to @bashrusakh).
274: - GitHub: PR and issue context now resolves against the source repository in fork workflows (thanks to @bashrusakh).
275: - Agents: saving agent settings from the UI no longer drops custom YAML frontmatter fields (thanks to @bashrusakh).
276: - Notifications: session errors and subagent completions now notify reliably across desktop, web, and mobile.
277: - Editor: "Open in" now recognizes VS Code Insiders.
278: - Windows: paths no longer mismatch on drive letter casing, which could split one project into duplicates (thanks to @bashrusakh).
279: - Mobile: the sessions sidebar opens instantly instead of taking many seconds on some devices (thanks to @tomzx).
280: - Mobile: renaming a saved instance no longer breaks its connection — the stored access token was getting lost on edit.
281: - Mobile: on Android 15 the app no longer draws under the status bar.
282: - Security: requests that spoof local host headers to look like same-machine traffic are rejected.
283: ## [1.15.29] - 2026-07-13
284: 
285: - **Cross-device session sync:** preserve the event directory for remotely created sessions and surface global busy or retry activity in the session list before a directory store is subscribed.
286: 
287: ## [1.15.28] - 2026-07-13
288: 
289: - **Mobile haptics:** mark a newly opened native app as foreground immediately so streaming and toast feedback work from the first launch after installation.
290: 
291: ## [1.15.27] - 2026-07-13
292: 
293: - **Mobile haptics:** refresh visible streaming text every 20ms, provide matching light haptic feedback, and trigger the same feedback whenever an in-app toast appears.
294: 
295: ## [1.15.26] - 2026-07-13
296: 
297: - **Command autocomplete:** pressing Enter on a skill only inserts it into the composer so arguments or context can be added first; system and OpenCode commands still run immediately.
298: 
299: ## [1.15.25] - 2026-07-13
300: 
301: - **Per-agent model memory:** when OpenChamber settings do not override the default session model, new sessions and agent switches restore each agent's last user-selected model and variant instead of falling back to OpenCode defaults.
302: 
303: ## [1.15.24] - 2026-07-13
304: 
305: - **Global configuration:** add a dedicated editor for OpenCode, oh-my-opencode-slim, and oh-my-openagent configuration, with safe save and restart flows across web, desktop, and VS Code runtimes.
306: - **Session and project navigation:** refine sidebar grouping, bulk actions, folder controls, session focus, project controls, and startup state for a faster, more consistent workspace experience.
307: - **Files, diffs, and comments:** improve change-list controls, file and diff navigation, inline-comment actions, and code-selection affordances.
308: - **Composer attachments:** render attachment citations consistently and remove their corresponding files whenever citation text is deleted with character, selection, or word deletion.
309: - **Visual polish:** refresh settings, controls, typography, keyboard hints, authentication, and mobile layout details across the application.
310: 
311: ## [1.15.23] - 2026-07-13
312: 
313: - **Project icon styling:** use the project icon itself across chat, mobile, scheduled tasks, multi-run, project settings, and sidebar surfaces, with a cleaner shared visual treatment.
314: - **Session sidebar focus:** preserve keyboard focus after selecting a session row, remount rows correctly when they move between sidebar contexts, and select the full session title when rename begins.
315: - **macOS ARM64 app build:** produce a directly runnable Apple Silicon `OpenChamber.app` bundle for local desktop use.
316: 
317: ## [1.15.22] - 2026-07-12
318: 
319: - **Sidebar pinned sessions:** replace the central "Activity" section with per-directory pinned sessions that persist across restarts, reducing session list noise and keeping important conversations visible.
320: - **Sidebar focus and navigation:** simplified focus reconciliation and numbered-navigation scoping let keyboard-driven session switching and numbered shortcuts share one recent/visible session row order.
321: - **Session-title express refresh:** set `requestedAt` on the session when in-browser generation starts so that reconnects don't retry the same request; the server routes explicit sidebar requests through the same generation flow without depending on the background throttle or the settings gate.
322: - **Mobile status bar:** session counter popover respects multi-run and file-review sessions.
323: 
324: ## [1.15.21] - 2026-07-12
325: 
326: - **Tool row layout:** each tool and reasoning block use a stable flow-root wrapper with padding that works consistently in grouped and sequential tool rows, replacing fragile margin collapsing on mobile and desktop.
327: - **Smart-title reliability:** sidebar requests set a pending flag and persist errors to session metadata; the server immediately arms generation on explicit requests and clears transient state on failure.
328: - **Small-model introspection:** the settings picker verifies provider API availability before listing candidates, and `/api/small-model` returns an async provider list.
329: - **Router deeplink resilience:** deep-linked sessions wait for the global startup index; missing or unresolvable sessions redirect home after a timeout.
330: - **Assistant status i18n:** add full Polish, Portuguese, and Ukrainian translations for async status messages.
331: 
332: ## [1.15.20] - 2026-07-12
333: 
334: - **Tool output styling:** align file and Git path labels with the shared secondary tool-description color across progressive and completed tool rows.
335: 
336: ## [1.15.19] - 2026-07-12
337: 
338: - **Cross-runtime session startup:** Web, Electron, and mobile restore project session summaries from the shared SQLite index, while background synchronization stays bounded and session panels avoid redundant global history requests.
339: - **Session forks:** show a dedicated transition while OpenCode copies a conversation, suppress duplicate fork events, and open the fork from one bounded initial message page.
340: - **Mobile generation controls:** keep stop controls in the composer, simplify the status row, and preserve streaming haptics with the visible response lifecycle.
341: - **Authentication startup:** dismiss the initial loading layer when authentication or network recovery needs to present an interactive screen.
342: 
343: ## [1.15.18] - 2026-07-12
344: 
345: - **Native haptics:** synchronize feedback with visible streaming updates. Thinking vibrates once when its UI first appears, while assistant text vibrates once per rendered text update; fixed-interval pulses are removed.
346: - **Mobile generation controls:** keep the stop action available inside the collapsed composer while the current response is running.
347: 
348: ## [1.15.17] - 2026-07-12
349: 
350: - **Mobile message queue:** refine the queued-message card with tighter padding, smaller type and icons, denser rows, a shorter scroll region, and compact corners while preserving the established desktop layout.
351: 
352: ## [1.15.16] - 2026-07-12
353: 
354: - **Mobile session picker:** consolidate phone session selection into the slide-up panel. The existing top-left folders button and session deep links open it, while a right swipe across more than half the conversation provides a gesture shortcut.
355: - **Mobile session navigation:** horizontal swipes switch conversations only when they begin on the collapsed or expanded composer; vertical gestures and conversation content retain their native scrolling and interaction behavior.
356: - **Mobile session status:** running conversations use the shared busy ring, unread conversations use the desktop information marker, and completed conversations no longer show an idle status dot.
357: - **Mobile generation controls:** the conversation status row exposes the shared stop action while generation is active, and Android back navigation returns from a child conversation to its parent.
358: - **Mobile input feedback:** streaming output drives continuous light native haptics, touch controls use immediate scale feedback, and the mobile keyboard Send key submits the composer while Shift+Enter inserts a line break.
359: 
360: ## [1.15.15] - 2026-07-12
361: 
362: - **Mobile session navigation:** swipe across the conversation in any direction to move between newer and older sessions, and swipe right across the header to open the project and session list without relying on Android system-edge gestures.
363: - **Mobile session controls:** running sessions use the same server-backed busy state and spinning status ring as desktop; visible rows and collapsed project, worktree, or child-session groups can stop their active work directly.
364: - **Mobile touch feedback:** buttons and interactive rows respond immediately on touch-down, with disabled, nested, drag, and reduced-motion behavior handled consistently.
365: - **Native haptics:** Android and iOS clients provide a light, throttled haptic pulse while the visible conversation is streaming, and stop when the stream ends or the app moves to the background.
366: - **Message recovery:** failed sends and slash-command operations restore composer text, attachments, queued messages, synthetic parts, and inline drafts without overwriting content entered while the request was pending.
367: 
368: ## [1.15.14] - 2026-07-12
369: 
370: - **Mobile new conversations:** parse JSON bodies for the OpenChamber create-with-first-prompt endpoint, restoring New Chat creation over direct and relay connections.
371: - **Task status:** simplify task rows, keep semantic list markup, and center the active task without moving keyboard focus when the status panel opens.
372: 
373: ## [1.15.13] - 2026-07-12
374: 
375: - **New conversations:** normal first prompts are now orchestrated by the OpenChamber server, which creates the OpenCode session and admits the first message through one authenticated runtime operation.
376: - **Remote reliability:** relay disconnects no longer cancel in-flight conversation setup. Message-ID idempotency deduplicates reconnect retries and preserves partial create/prompt outcomes without duplicate sessions or messages.
377: - **Mobile feedback:** submitting a new conversation immediately shows an establishing state and locks duplicate input; failures restore the draft and message for retry.
378: - **Mobile sessions:** swiping left across chat content opens the Sessions sheet while edge session switching, vertical scrolling, controls, and horizontal code scrolling retain their gestures.
379: - **Mobile copy:** the Sessions sheet preserves the authored `New Chat` capitalization.
380: - **Cross-runtime parity:** Web, Electron, relay clients, and VS Code share the same create-with-prompt result contract, including explicit create, prompt, conflict, unavailable, and ambiguous-delivery recovery states.
381: - **Task status:** the expanded task list highlights and focuses the active task with clearer status, priority, progress, and scrolling behavior.
382: 
383: ## [1.15.12] - 2026-07-12
384: 
385: - **CI:** enforce all-platform builds (desktop + Android + iOS) on every release tag.
386: 
387: ## [1.15.11] - 2026-07-12
388: 
389: - **Release:** fix version bump and changelog to trigger desktop + Android build pipeline.
390: 
391: ## [1.15.10] - 2026-07-12
392: 
393: - **Mobile i18n:** unify all mobile "new session" copy to "New Chat" across 10 locales.
394: - **Sidebar i18n:** capitalize section titles "recent" → "Recent", "projects" → "Projects", "syncing sessions" → "Syncing sessions…".
395: 
396: ## [1.15.9] - 2026-07-12
397: 
398: - **Desktop updates:** macOS checks `yee94/openchamber` Releases directly, detects newer versions correctly, and opens the matching Release for manual installation instead of incorrectly reporting that the app is up to date.
399: - **Release links:** desktop, mobile, VS Code, install, documentation, and release workflow links now consistently target `yee94/openchamber`.
400: - **Release automation:** tag releases build macOS, Windows, Android, and VS Code artifacts without starting an iOS/TestFlight build. npm publishing is explicitly skipped when no npm credential is configured.
401: 
402: ## [1.15.8] - 2026-07-12
403: 
404: - **Mobile (new layout):** overflow menu leads with New session; the composer-side `+` new-chat button is removed. Attach uses a paperclip icon, and the expanded composer top handle spacing is tighter.
405: - **Chat chrome:** mobile info/status chips align icon stroke and meta type with tool rows; assistant header badges use slightly tighter mobile type.
406: 
407: ## [1.15.7] - 2026-07-12
408: 
409: - **Android updates:** the Capacitor client now checks `yee94/openchamber` GitHub Releases directly, reads the latest stable release version and notes, and uses the uploaded APK asset as its update download URL.
410: 
411: ## [1.15.6] - 2026-07-12
412: 
413: - **Chat message actions:** clearer medium-stroke icons on send and reply (shared size), with a coordinated footer — actions and duration/time meta share color, grouped spacing, slightly smaller meta type, and left-aligned chrome on mobile.
414: 
415: ## [1.15.5] - 2026-07-12
416: 
417: - **Session sidebar:** only sessions with verified SubAgent children show an expansion chevron. Electron persists child-session membership in its SQLite index, updates it immediately while a delegation is created or removed, and reconciles it in the background after launch without delaying the sidebar.
418: - **Markdown:** horizontal rules now use balanced spacing and a subtler theme-aware divider.
419: 
420: ## [1.15.4] - 2026-07-11
421: 
422: - **Deep-link projects:** `openchamber://new-session?directory=…` now reuses the matching project or worktree, and registers an unmatched directory as a project before its first session is created. Sessions opened this way reliably appear in the project sidebar without duplicate project entries.
423: 
424: ## [1.15.3] - 2026-07-11
425: 
426: - **Android release:** publish the signed Android APK and AAB alongside this release, so the mobile client is available from GitHub Releases.
427: 
428: ## [1.15.2] - 2026-07-11
429: 
430: - **Session startup performance:** Electron restores each project's latest session summaries from its own SQLite index, then refreshes OpenCode incrementally instead of rebuilding the full sidebar on every launch.
431: - **Foreground responsiveness:** session-index work now runs as a single server-owned background job. Conversation content, children, and message mutations preempt it, so selecting a session no longer waits behind project-wide refreshes.
432: - **Startup experience:** a first run shows deterministic global loading progress; cached starts show the prior sidebar immediately and apply SQLite updates through a low-priority long poll.
433: - **Request reduction:** project lists are capped to the newest 20 root sessions, history uses cursor-driven "Show more" pagination, and session children load only when a user expands a parent session.
434: - **Reliability:** runtime-transition bursts, readiness races, stale async writes, repeated tray/sidebar refreshes, and duplicate session/message loads were consolidated or cancelled safely.
435: - **Session and chat rendering:** removed neighbor-session/history prefetch work that was not user initiated, tightened directory-level request deduplication, and preserved existing snapshots on transient failures.
436: 
437: ## [1.15.1] - 2026-07-11
438: 
439: - **Desktop releases:** GitHub Releases and update metadata now publish from `yee94/openchamber`.
440: - **macOS packaging:** desktop artifacts use ad-hoc signing with no Apple Developer account or notarization requirement; macOS updates are installed manually, while Windows retains in-app automatic updates.
441: - **Release automation:** manual GitHub Actions releases can publish desktop artifacts without npm or mobile signing credentials, validate version consistency, and preserve dry-run releases as drafts.
442: 
443: ## [1.15.0] - 2026-07-10
444: 
445: - **Remote access:** a new [private relay](https://docs.openchamber.dev/private-relay/) lets you reach your instance from anywhere — no open ports and no third-party tunnel, over an end-to-end-encrypted tunnel. It turns on by itself when you pair a device over it and turns off once no paired device uses it (thanks to @yulia-ivashko).
446: - **Mobile:** the native iOS and Android apps open for testing — join the [iOS public beta on TestFlight](https://testflight.apple.com/join/5ek6GU1E) or grab the Android APK from the [latest release](https://github.com/yee94/openchamber/releases/latest). Connect by scanning a QR code from "Add a device" on your server; the app then moves between your local network and the private relay on its own — leaving home carries the open session onto the relay and coming back returns it to Wi-Fi, no re-pairing. Saved instances show a live Connected status with the active transport, iPad gets a split layout with a persistent sessions sidebar and a resizable Changes/Files sidebar, and the app checks for OpenChamber updates itself (Android shows a download toast).
447: - **Pairing:** a redesigned ["Add a device"](https://docs.openchamber.dev/connect-devices/) dialog asks where you'll use the device — Anywhere (relay with local network preferred at home), Home network only, or This computer only — then shows a large scannable QR code with a copyable link, and closes itself once the device connects. Links are single-use expiring codes redeemed on connect instead of embedding a long-lived token in the QR (thanks to @yulia-ivashko).
448: - Devices: the "Connect to this server" list now shows each paired device with a live status — Connected · Local network or Relay — and a platform badge (iOS, Android, macOS, Windows, Linux). Re-pairing or re-entering the password on the same device updates its existing entry instead of adding a duplicate.
449: - Devices: a paired phone or desktop names the connection after the server's hostname; the name typed when creating the link labels the device in the server's list.
450: - Desktop: saved servers keep every transport their pairing link carried — the app connects directly on your network and falls back to the relay away from it, including when opening a server in a new window and when restoring the connection after a restart.
451: - Desktop: the header dropdown (instance / usage / MCP) was restyled with cards — usage grouped per provider, hosts showing a colored status line with ping and the active host highlighted, and MCP servers in one card. Host statuses persist between openings instead of flashing "Unknown", and switching to an already-checked host is immediate.
452: - Desktop: the servers list in Settings shows live per-server reachability, and importing a pairing link is the primary way to add a server.
453: - Desktop: Windows builds can launch at login and minimize to the system tray (thanks to @achcyano).
454: - Chat/Tools: every tool call now expands to show its input, result, and errors, including MCP, plugin, and custom tools; Read and Skill stay compact links to their files. JSON results open in a new navigable summary view with linked URLs and expandable nested data, alongside tree and raw JSON views.
455: - Chat/Tools: expanded file-edit and patch results now include per-file buttons to open the diff or jump to the first changed line in the file editor.
456: - Chat/Thinking: reasoning parts stay separate and in chronological order instead of merging into one block, and collapsed previews no longer show empty trailing HTML comments.
457: - Projects: each project can now set its own default model (thanks to @makeittech).
458: - Diff/Chat: added a Last turn mode to the Diff view, and latest-turn changed-file chips in chat now open that snapshot while older turn chips stay read-only.
459: - Chat: Mermaid diagrams now have zoom controls (thanks to @c-w-xiaohei).
460: - Chat: code blocks can show line numbers that stay aligned while streaming, and a new Wrap Code Block Lines setting (Settings → Chat) controls long-line wrapping.
461: - Chat: with Sticky User Header enabled, user messages no longer float over earlier messages in long conversations.

(Output capped at 50 KB. Showing lines 1-461. Use offset=462 to continue.)
</content>