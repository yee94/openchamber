# GitHub Integration (Auth Foundation)

This repo now has a GitHub auth foundation intended to be reused by all future GitHub features (PRs/issues/worktrees/etc).

It provides:
- GitHub OAuth Device Flow connect UX
- persistent token storage per runtime
- a small runtime API surface for UI
- server-side Octokit usage (web runtime)

## Scopes

Default scopes requested:

```
repo read:org workflow read:user user:email
```

Notes:
- Email is fetched from `/user` when available, otherwise `/user/emails` (requires `user:email`).
- Actions performed via this OAuth token are performed “as the user” (not a bot), but the OAuth App is visible under GitHub “Authorized OAuth Apps”.

## UI

Settings entry:
- `packages/ui/src/components/sections/openchamber/GitHubSettings.tsx`

Behavior:
- shows connected user card (avatar + name/email/login)
- Connect triggers Device Flow and polls until authorized
- Disconnect clears the stored token

## Runtime API (UI)

`RuntimeAPIs.github` is optional (some environments may not expose it).

Types:
- `packages/ui/src/lib/api/types.ts` (`GitHubAPI`, `GitHubAuthStatus`, `GitHubDeviceFlowStart`, `GitHubDeviceFlowComplete`)

Methods:
- `authStatus(): { connected, user?, scope? }`
- `authStart(): { deviceCode, userCode, verificationUri, verificationUriComplete?, expiresIn, interval, scope? }`
- `authComplete(deviceCode): { connected: true, user, scope? } | { connected: false, status?, error? }`
- `authDisconnect(): { removed: boolean }`
- `me?(): user` (optional, mostly for debugging)

Implementations:
- Web: `packages/web/src/api/github.ts`
- Desktop: `packages/desktop/src/api/github.ts` (calls Tauri commands)
- VS Code: `packages/vscode/webview/api/github.ts` (bridge messages)

## Web Runtime (Express server)

Endpoints (JSON):

- `GET /api/github/auth/status`
  - returns `{ connected: false }` or `{ connected: true, user, scope }`

- `POST /api/github/auth/start`
  - returns device flow payload:
    - `{ deviceCode, userCode, verificationUri, verificationUriComplete?, expiresIn, interval, scope }`

- `POST /api/github/auth/complete`
  - request: `{ deviceCode }`
  - returns either pending or success:
    - pending: `{ connected: false, status, error }`
    - success: `{ connected: true, user, scope }`

- `DELETE /api/github/auth`
  - clears stored token
  - returns `{ success: true, removed: boolean }`

- `GET /api/github/me`
  - returns the authenticated user summary

Code:
- endpoints: `packages/web/server/index.js`
- token store + config defaults: `packages/web/server/lib/github-auth.js`
- Octokit factory: `packages/web/server/lib/github-octokit.js`
- device flow helpers: `packages/web/server/lib/github-device-flow.js`

## Desktop Runtime (Tauri)

Tauri commands:
- `github_auth_status`
- `github_auth_start`
- `github_auth_complete` (param: `deviceCode`)
- `github_auth_disconnect`
- `github_me`

Code:
- `packages/desktop/src-tauri/src/commands/github.rs`
- wired in invoke handler: `packages/desktop/src-tauri/src/main.rs`

## VS Code Runtime

Bridge message types handled in extension:
- `api:github/auth:status`
- `api:github/auth:start`
- `api:github/auth:complete`
- `api:github/auth:disconnect`
- `api:github/me`

Code:
- storage + device flow + `/user` fetch: `packages/vscode/src/githubAuth.ts`
- bridge handlers: `packages/vscode/src/bridge.ts`

## Token Storage

- Web/server runtime: `~/.config/openchamber/github-auth.json`
  - file mode `0600` best-effort

- Desktop runtime: `~/.config/openchamber/github-auth.json`
  - file mode `0600` best-effort

- VS Code runtime: `${extensionGlobalStorage}/github-auth.json`
  - file mode `0600` best-effort

Stored fields (current shape; can evolve):

```json
{
  "accessToken": "…",
  "scope": "…",
  "tokenType": "bearer",
  "createdAt": 1730000000000,
  "user": {
    "login": "…",
    "id": 123,
    "avatarUrl": "…",
    "name": "…",
    "email": "…"
  }
}
```

## Official OAuth App

Default OAuth client id is baked in:
- `Ov23liNd8TxDcMXtAHHM`

Overrides:
- Web/server: `OPENCHAMBER_GITHUB_CLIENT_ID` (env)
- Scopes override (web/server): `OPENCHAMBER_GITHUB_SCOPES` (env)

Note: UI editing of client id/scopes was intentionally removed to reduce user confusion.

## How to Use in New Features

Preferred pattern:
- UI triggers new feature flows.
- Backend (web server or desktop/vscode runtime command/bridge) performs GitHub API calls using the stored token.
- Do not expose the token to the UI.

Web/server feature endpoints should:
- require `{ connected: true }` state (return 401 if not connected)
- use Octokit with `auth` set to stored token
- accept repo/issue/pr identifiers from UI and fetch needed context

Future “context bootstrap” idea:
- Add endpoints that take `{ owner, repo, number }` and return:
  - issue/PR body
  - comments
  - changed files (PR)
  - diff/patch summary
Then UI can start a session with a prefilled prompt.
