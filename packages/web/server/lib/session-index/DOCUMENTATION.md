# Session Index Runtime

Every OpenChamber Web Server enables `session-index.sqlite` in its data
directory by default. Electron injects its user-data path explicitly.
`sessionIndexDbPath` and `OPENCHAMBER_SESSION_INDEX_DB_PATH` override that
default; the HMR startup script uses the environment override to isolate its
development index without changing settings or authentication storage.
`service.js` exclusively owns the WAL database and stores at most the
newest 20 root-session summaries per runtime and directory. It never stores
messages, attachments, permissions, provider data, or model metadata.
Sessions titled `smartfetch-secondary` are temporary SmartFetch model calls;
the index excludes them from every snapshot and clears prior summaries when a
matching session update arrives.

The server-side global OpenCode event subscriber writes session summary events
directly into this index. User `message.updated` events and `session.idle`
completion events advance the separate `activity_updated_at` ordering field,
while session status transitions update `status` and `status_changed_at`.
Renderer event handling never performs these index writes and assistant
streaming events never change session ordering.

`sync-runtime.js` owns cold-start synchronization. The renderer submits all
known project directories once to `POST /api/openchamber/session-index/sync`.
The runtime processes them sequentially, applies `start=lastSyncedAt` for recent
indexes, performs a full reconciliation after 24 hours, and commits each result
to SQLite. It publishes an in-memory revision after every state/SQLite change.

The renderer observes revisions with
`GET /api/openchamber/session-index/changes?since=<revision>`. This is a bounded
25-second long poll, not an SSE/WebSocket. Responses contain the current full
summary snapshot and aggregate progress, so reconnecting never needs an event
replay log. The renderer keeps this observer active after startup refresh work
becomes idle, and successful event-driven index writes publish a new revision
immediately.

The OpenCode proxy calls `noteInteractiveRequest()` for selected-session reads
and mutations. That aborts the current background list, yields for one second,
then resumes the same directory. Consequently a startup index refresh cannot
sit ahead of conversation content or user actions.

Runtimes that explicitly disable or cannot host the index receive deterministic
`501 unsupported` responses and retain the bounded SDK-backed loading path.
