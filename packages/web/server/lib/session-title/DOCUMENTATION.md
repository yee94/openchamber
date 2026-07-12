# Session Title Refresh

Server-side watcher that regenerates a session's sidebar title from the
**latest** conversation turns with the small model (`lib/small-model`), then
PATCHes `title` plus `metadata.openchamber.titleRefresh`.

OpenCode only auto-titles once from the first user message
(`SessionPrompt.ensureTitle`). Long sessions often drift to a different topic;
this module keeps the sidebar title aligned with what the user is currently
discussing, throttled to at most once per 5 minutes per session.

## Flow

1. `createSessionTitleRuntime` is a consumer of the server's global SSE
   fan-out (`index.js` → `globalMessageStreamHub.subscribeEvent`), same
   pattern as session-assist. Purely event-driven — dormant sessions never
   generate anything.
2. `session.status: idle` arms a 15-second quiet timer; any `busy`/`retry`
   status or a fresh user `message.updated` clears it.
   A sidebar smart-title request sets `titleRefresh.requestedAt`; its
   `session.updated` event arms the same flow immediately.
3. On fire:
   - Skip when Settings → Chat → session title refresh is off.
   - Skip sub-agent sessions (`parentID`), multi-run/fusion structural titles,
     and titles the user manually renamed (current title ≠ last auto title
     we wrote, and not still the OpenCode default placeholder).
   - Enforce the 5-minute throttle (`TITLE_THROTTLE_MS`). If still inside the
     window, re-arm for the remaining time instead of dropping the refresh.
   - Require 2+ real user turns (unless the title is still the default
     placeholder) so OpenCode's first-message title can land first.
   - Skip when `forMessageID` still matches the latest assistant message
     (no new content since the last refresh).
   - Set `metadata.openchamber.titleRefresh.isGenerating` while the small
     model call is active so connected clients animate the existing sidebar
     title as a loading state.
   - Call `generateSmallModelText` with the latest few turns, biased toward
     the most recent topic, restricted to the session's own provider unless
     the user explicitly configured a small model.
4. Clean the model output to a single short line, then PATCH `title` and
   `metadata.openchamber.titleRefresh` (`lastAutoTitle`, `forMessageID`,
   `generatedAt`) from a fresh session read so concurrent metadata writes
   are preserved. Transient `requestedAt` and `isGenerating` flags clear
   after the model call finishes.

## Settings gate

`sessionTitleRefreshEnabled` in OpenChamber settings (Settings → Chat,
default on) controls background title refreshes. Explicit smart-title actions
still run when background refresh is disabled.

## Manual rename contract

After this module writes a title, further auto-refreshes only proceed while
`session.title === titleRefresh.lastAutoTitle` (or the title is still the
OpenCode default). Renaming in the sidebar breaks that equality and stops
auto updates for that session.

## Limitations

- Lives in the web server, so VS Code (extension-only) does not generate
  refreshes; it still receives `session.updated` title changes produced by a
  web/desktop instance of the same OpenCode server.
- First OpenCode-generated title (no `titleRefresh` metadata yet) may be
  replaced once the conversation has 2+ real user turns — that is intentional.
