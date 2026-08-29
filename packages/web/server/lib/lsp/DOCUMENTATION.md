# Language server runtime

## Purpose

OpenChamber-owned Language Server Protocol (LSP) bridge. The Files editor talks
JSON-RPC over a WebSocket; this module owns language-server processes and the
stdio `Content-Length` framing. Electron does not spawn language servers —
desktop already runs this web server in-process.

## Contract

- Path: `GET /api/lsp/ws?directory=<abs>` (WebSocket upgrade).
- Frames are **JSON-RPC bodies only**. No LSP headers on the wire. The server
  adds and strips `Content-Length` when talking to the child.
- The client does not choose a binary. Only an allowlisted server may start
  (`typescript-language-server --stdio`). `cwd` is the requested directory.
- One child per resolved directory. Idle children exit after the last socket
  disconnects. A hard cap evicts the oldest unused child.
- Auth and origin match terminal/dictation: UI session or `oc_url_token`, plus
  origin check. The path must stay on both WebSocket allowlists:
  `ALLOWED_WS_PATHS` and `isUrlAuthWebSocketPath`.
- Register this runtime in the startup pipeline **before** the generic
  OpenCode proxy.

## Runtime parity

- Local web and desktop: supported when the server can see `directory`.
- Relay / hosted-mobile / Capacitor: the **host** runs the language server
  against host-visible files. The phone never spawns `tsserver`.
- VS Code webview: uses the same OpenChamber server when that server can see
  the folder. It does **not** inherit the VS Code host language service.

## Files

- `stdio-framing.js` — encode/decode LSP headers.
- `process-manager.js` — spawn, refcount, idle shutdown.
- `runtime.js` — WebSocket upgrade, JSON-RPC pump, and startup entry.

## Follow-ups

Parked. Same list as `packages/ui/src/lib/files/DOCUMENTATION.md`. Next languages reuse this pipe; do not add a second WebSocket product.
