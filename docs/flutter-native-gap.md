# Flutter native rewrite — gap matrix

Independent track: **`work/flutter-native`**. Do **not** merge to `main`. Do **not** touch the 1.18 TanStack line (`cursor/tanstack-chat-physics-29a6`, `v1.18.5`, PR #4).

Native is the product. There is **no** Appearance `openchamber.iosNativeUi` toggle and **no** WebView-fallback switch. iOS native chrome (composer, liquid-glass dock on iOS 26, Live Activity, share, NSE, widgets, haptics, IME) is always on. Android uses native Android surfaces (Material 3, native composer, IME analogue, share receiver, FCM, CameraX/ML Kit, keystore storage) — not a broken iOS glass clone, and not a WebView composer.

## Baseline (read on main, 2026-09-03)

| Fact | Value |
|---|---|
| `main` HEAD | `3a164b6` `release: v1.19.3-beta.5` |
| Root `package.json` | `1.19.3-beta.5` |
| CHANGELOG `[Unreleased]` | empty |
| Required prior | `1.19.3-beta.4` (`ee9532c`) home pinned/in-progress subtitle `项目 · 分支` |

## Files read on main (do not guess)

Tabs / shell

- `packages/ui/src/mobile/mobileTabs.ts` — four roots only: `projects` / `assistant` / `scheduled` / `settings`
- `packages/ui/src/mobile/MobileTabsRoot.tsx`
- `packages/ui/src/mobile/MobileTabBar.tsx`
- `packages/ui/src/mobile/MobilePhoneShell.tsx`
- `packages/ui/src/mobile/useNativeIosTabBar.ts`
- `packages/ui/src/lib/iosNativeUi.ts` — Capacitor WebView-era gate (`openchamber.iosNativeUi`, default **off**). **Deleted for Flutter.** Native is always on.

Surfaces

- `packages/ui/src/mobile/projects/MobileProjectsHome.tsx`
- `packages/ui/src/mobile/projects/useMobileProjectsHomeModel.ts` (`formatHomeSessionSubtitle`)
- `packages/ui/src/mobile/projects/useMobileProjectsHomeModel.test.ts`
- `packages/ui/src/mobile/chat/MobileChatScreen.tsx`
- `packages/ui/src/mobile/assistant/MobileAssistantTab.tsx`
- `packages/ui/src/mobile/scheduled/MobileScheduledTab.tsx`
- `packages/ui/src/mobile/settings/MobileSettingsTab.tsx`
- `packages/ui/src/components/chat/TimelineList.tsx` — LegendList (`initialScrollAtEnd`, `maintainScrollAtEnd`, `maintainVisibleContentPosition`)
- `packages/ui/src/apps/MobileApp.tsx` — Capacitor-only connection onboarding
- `packages/ui/src/apps/mobileQrScan.ts`

Settings

- `packages/ui/src/lib/settings/metadata.ts` (`MOBILE_SETTINGS_PAGE_SLUGS`, groups)
- `packages/ui/src/components/sections/shared/SETTINGS_DESIGN_SPEC.md`
- `.agents/skills/settings-ui-patterns/SKILL.md`
- `packages/ui/src/lib/i18n/messages/en.ts`, `en.settings.ts`, `zh-CN.ts`, `zh-CN.settings.ts`

Native contracts / shell

- `packages/mobile/HANDOFF.md`
- `packages/mobile/README.md`
- `packages/mobile/contracts/*` (`index`, composer, keyboard, haptics, share, navigation, media, tab-bar, virtual-asset, external-browser)
- `packages/ui/src/lib/native-ios-composer.ts`
- `packages/mobile/ios/App/OpenChamberWidget/OpenChamberLiveActivity.swift`
- `packages/mobile/android/app/src/main/AndroidManifest.xml` (LAN `usesCleartextTraffic`)
- `CHANGELOG.md` (1.19.0–1.19.3-beta.5)
- `.github/workflows/mobile-ci.yml`
- `.github/workflows/mobile-release.yml`
- `.github/workflows/mobile-beta-ota.yml`

## First-slice status

| Surface | Status | Notes |
|---|---|---|
| Branch `work/flutter-native` from `3a164b6` | landed | Also mirrored on `cursor/flutter-native-8ab3` |
| `apps/mobile_flutter` iOS + Android | landed | Capacitor `packages/mobile` left in place |
| Splash | landed | Holds while auto-connect resolves |
| Connection onboarding | landed | URL, pairing link, client token, instance UI password, saved list, auto-connect, delete-active → connect. **No local PIN / Face ID.** |
| Four-tab dock | landed | Projects / Assistant / Scheduled / Settings. Chat is **pushed**. |
| Projects home + `项目 · 分支` | landed | Slice 1 used demo rows. Slice 3 replaced them with `GET /api/openchamber/session-index`. Unread dot kept (1.19.2). Plus menu 扫一扫 / 切换实例. |
| Chat skeleton | landed | Reverse list (LegendList analogue) + native composer chrome. Slice 3 loads the live transcript and Send/Stop hit official APIs. Re-enter jumps to latest (1.19.3-beta.5). |
| Settings home + all slugs | landed | Search + grouped drill-in. Real-enough: instances, appearance, notifications, about. |
| Appearance `iosNativeUi` | **not present** | Do not rebuild. Native is always on. |
| Plan mode / project notes / Todo | **not present** | Removed in 1.19.2. Do not rebuild. |
| Capgo OTA | **not ported** | WebView web-bundle hot update only. Flutter ships IPA/APK. |
| Flutter CI | landed | `.github/workflows/flutter-mobile-ci.yml` automatic on this track. **#13** `332ad6f82` and **#14** `77baf9b6f` both fully green (analyze + Android APK + iOS simulator). **#15** `10f97ff86` iOS simulator **failed** (`OpenChamberFlutterPlugins.swift:598` missing `await` on MainActor `mime`). **#16** `37074feea` fully green: https://github.com/yee94/openchambery/actions/runs/33715865698. **#17** `1f32bed56` fully green: https://github.com/yee94/openchambery/actions/runs/33716649360. **#18** `74aec2072` fully green: https://github.com/yee94/openchambery/actions/runs/33717269010. **#19** `17d1822bc` cancelled by the next push. **#20** `d740f4164` fully green (analyze + Android debug APK + iOS simulator): https://github.com/yee94/openchambery/actions/runs/33718295396. Linux analyze-test alone is never treated as green. |
| Signed release workflow | landed | `.github/workflows/flutter-mobile-release.yml` — existing secret names only |

## Settings slug checklist (`MOBILE_SETTINGS_PAGE_SLUGS`)

| Slug | Group | Fifth-slice page |
|---|---|---|
| `instances` | connection | List + add + QR scan (persist v2 payload / relayUrl) |
| `appearance` | personalization | Language + theme. **No iosNativeUi.** |
| `chat` | personalization | Real: GET/PUT `/api/config/settings` (`chatRenderMode`, `messageStreamTransport`, `followUpBehavior`, reasoning/wrap/spellcheck) |
| `notifications` | personalization | Real: local toggles + PUT `nativeNotificationsEnabled` / `notifyOn*` + APNs/FCM register |
| `sessions` | personalization | Real: defaults + retention fields from the settings blob |
| `summary-ai` | personalization | Real: settings blob + GET `/api/small-model` callable list |
| `projects` | workspace | Real: `projects[]` from the settings blob |
| `git` | workspace | Real: gitmoji / view mode + GET `/api/git/identities` |
| `providers` | opencode | Real: GET `/api/config/catalog/providers` (failure ≠ empty) |
| `agents` | opencode | Real: GET `/api/agent` |
| `assistants` | opencode | Real: GET `/api/openchamber/assistants/snapshot` |
| `behavior` | opencode | Real: response-style fields + GET `/api/behavior/agents-md` |
| `commands` | opencode | Real: POST `/api/config/commands/metadata` `{catalog:true}` |
| `mcp` | opencode | Real: GET `/api/config/mcp` |
| `plugins` | opencode | Real: GET `/api/config/plugins` |
| `magic-prompts` | content | Real: GET `/api/magic-prompts` overrides |
| `snippets` | content | Real: GET `/api/config/snippets` |
| `skills.installed` | content | Real: GET `/api/config/skills?summary=true` |
| `usage` | system | Real: GET `/api/quota/{providerId}` per official id; one failure stays on that row |
| `voice` | system | Real: `sttProvider` + GET `/api/dictation/status` + GET `/api/tts/status` |
| `about` | system | App name, native client `1.19.3-beta.5`, instance version separate |

## Second-slice status (this PR)

| Surface | Status | Notes |
|---|---|---|
| Four Xcode targets in `Runner.xcodeproj` | landed | Runner `com.yee94.openchamber`; Widget `…OpenChamberWidget` (17.0); NSE `…OpenChamberNotificationService`; Share `…OpenChamberShareExtension`. App Group `group.com.yee94.openchamber`. Embed App Extensions `dstSubfolderSpec = 13`. No `DEVELOPMENT_TEAM` baked in. |
| Release YAML four-profile signing | landed | `flutter-mobile-release.yml` pbxproj replacements + ExportOptions map all four bundle IDs / existing profile secrets |
| iOS composer UIKit platform view | landed | `UIGlassEffect` on iOS 26; system blur on older iOS. Attachments, `/` `@` stub that pan-scrolls, IME, Send/Stop. Warm overlay on Projects; hide immediately on leave. Occupancy = collapsed 56pt only |
| iOS 26 glass tab bar | landed | Chrome-only `UITabBarController`. Older iOS: system translucent `UITabBar`. Chat remains pushed. Widget tests / Android use the Flutter floating capsule (`tab-projects` … `tab-settings`), not Material `NavigationBar` |
| Live Activity local MVP | landed (iOS 17+) | One Activity, 5s demo timer, `pushType: nil`, no rebuild after dismiss. Android channel is a no-op |
| SecureStore | landed | Production `PlatformSecureStore`: iOS Keychain + Android Keystore AES-GCM. Tests still inject `MemorySecureStore`. Never logs values |
| QR + deep link | landed (thin redeem) | iOS VisionKit `DataScanner` (Apple on-device ML; not a Google ML Kit CocoaPod). Android Google Code Scanner then CameraX + ML Kit. Parses v2 `p=` and persists `relayUrl` / pairing secret. **Does not** call a made-up redeem HTTP API |
| Android IME + share | landed | Solid `viewInsets` surface. `ShareReceiverActivity` + Direct Share shortcuts. Exact instance+assistant only — no silent default |
| Simulator CI | documented | `flutter build ios --simulator --no-codesign` includes the new targets. Simulator often skips extension signing. Linux VM cannot run this. **This agent did not run the macos-15 job.** |
| Capgo / plan / notes / Todo / Chat dock | **not present** | Do not rebuild |

## Native parity (always on — not optional)

| Contract | Status | Main source | Notes |
|---|---|---|---|
| Connection onboarding | landed | `MobileApp.tsx`, HANDOFF, `mobileConnections.ts` | Live `GET /health`, `GET/POST /auth/session`, pairing redeem. Persist **full** lan+relay candidate set. 1.5s LAN headstart then relay race. Auto-connect last token. Delete-active → connect. Badge `已连接 · 局域网` / `已连接 · 中继`. |
| QR pairing | landed | `mobileQrScan.ts`, `connectionPayload.ts` | Persist full v2 candidates (`lan` + `relayUrl` + `hostEncPubJwk` + grant + `serverId`). Redeem on the first reachable transport (LAN race, then official E2EE tunnel). Reload must not drop relay. |
| iOS composer | landed | `OpenChamberComposer` | UIKit platform view, always on |
| Android composer | landed | IME viewInsets | Material + solid inset surface. ImeSync analogue still later |
| iOS liquid-glass dock | landed | `OpenChamberTabBar` | iOS 26 `UIGlassEffect`; older: system translucent bar |
| Android dock | landed (capsule) | Web `MobileTabBar` | Flutter floating capsule, same four roots. Not liquid glass |
| Live Activity / Dynamic Island | landed | `OpenChamberLiveActivity` | Driven from `GET /api/session/status` busy/retry; start after 5s; `pushType` nil; no rebuild after dismiss |
| Share-in | landed | Share extension + `ShareReceiverActivity` | Exact instance+assistant. Catalog published from saved instances |
| Push | landed (host register) | APNs + FCM → `openchamber-push-relay` | Mobile `POST /api/push/apns-token` + `POST /api/push/visibility`. Host binds relay. iOS requests APNs token. Android copies Capacitor `google-services.json` (`com.yee94.openchamber` / `openchamber-8bf7e`) and reads the FCM token via the native Firebase SDK — still **null** if Firebase is unavailable (not invented). Presence skip is **host-side** (`isAnyInteractiveClientVisible`) |
| WidgetKit + Control Center + NSE | landed | `OpenChamberWidget`, NSE | Snapshot JSON `{attentionCount, recentSessions}` written to App Group `widgetSnapshot` from the live index |
| Haptics | landed | `OpenChamberHaptics` | light / medium / heavy via method channel |
| Native back | landed | Capacitor `OpenChamberNavigation` | iOS `UIScreenEdgePanGestureRecognizer` drives `IosNativePageRoute`. Android `PredictiveBackPageTransitionsBuilder`. |
| Secure storage | landed | Keychain / Android Keystore | Never log tokens |
| Deep links | landed | `openchamber://` | Pairing cold-launch, share-inbox, session jump URI |
| Virtual assets / HEIC / Android picker | landed | `OpenChamberVirtualAsset`, `OpenChamberMedia` | Android `ACTION_PICK_IMAGES`, iOS PHPicker, HEIC transcode, in-memory virtual-asset create/append/finish. Composer uploads `PUT /api/fs/prompt-attachments/:id` then `file://` parts. Flutter preview is `Image.memory` — the `openchamber-asset://` scheme is for WebView. |
| External browser | landed | Capacitor `OpenChamberExternalBrowser` | Flutter `openchamber/external_browser` on iOS + Android. http(s) only. Used by provider/MCP OAuth. |
| App-icon badge | landed (iOS) | session-index `attentionCount` | iOS `applicationIconBadgeNumber` when writing the widget snapshot. No `GET /badge-count`. Android has no official badge API without a posted notification. |
| Status bar | stub | Capacitor overlay | Use Flutter/system insets |
| Capgo OTA | **will not port** | `@capgo/capacitor-updater` | Full IPA/APK via signed-release |

## Android degradation (intentional — native Android, not fake iOS)

| iOS-native effect | Android product path |
|---|---|
| iOS 26 liquid-glass dock | Flutter floating capsule (same four roots). Not `UIGlassEffect` |
| UIKit liquid-glass composer | Solid floating pill + IME viewInsets. Not a fake glass clone |
| Live Activity / Dynamic Island | Not applicable |
| WidgetKit / Control Center / NSE | FCM + Android widgets later; not a glass clone |
| UIImpactFeedbackGenerator | `performHapticFeedback` (light / medium / heavy) |
| LAN HTTP | `android:usesCleartextTraffic="true"` (landed) |

## Recent main — required / do not rebuild

| Version | Rule |
|---|---|
| 1.19.0 | Native composer / iOS 26 dock / Live Activity / push-relay CLI exist on Capacitor. Flutter must reimplement as native, not WebView. |
| 1.19.2 | **Removed** plan mode (`/plan-feature`) and project notes/Todo — do not rebuild |
| 1.19.2 mobile | Pinned/in-progress unread rows match normal session style; keep unread dot |
| 1.19.3-beta.1 | Session search matches loaded directory titles + keyword highlight |
| 1.19.3-beta.2/3 | Scheduled opens that task’s history with filter; in-progress from start |
| 1.19.3-beta.4 | Pinned/in-progress subtitle `项目 · 分支` (`formatHomeSessionSubtitle`) |
| 1.19.3-beta.5 | Re-entering a session scrolls to latest, not the last sent user message |

## CI / CD (this slice)

Capacitor pipelines on `main` are unchanged (`mobile-ci.yml`, `mobile-release.yml`, `mobile-beta-ota.yml`).

| Workflow | Trigger | What |
|---|---|---|
| `.github/workflows/flutter-mobile-ci.yml` | **push to `work/flutter-native` only** + `workflow_dispatch` | Parallel `analyze-test` / `android-debug` / `ios-simulator`. Flutter **3.32.8** pinned. No `pull_request`. iOS job is a real `flutter build ios --simulator --no-codesign` and asserts `Runner.app`. **#13 (`332ad6f82`, [run 33713282610](https://github.com/yee94/openchambery/actions/runs/33713282610))** and **#14 (`77baf9b6f`, [run 33714058628](https://github.com/yee94/openchambery/actions/runs/33714058628))** fully green. |
| `.github/workflows/flutter-mobile-release.yml` | `workflow_dispatch` only | Decode **existing** Android keystore + iOS p12 / four profiles; signed Android APK/AAB; iOS archive/export + TestFlight gated by `build_ios` (default **false**) |

Secret names reused (do not invent new ones; do not print values):

- Android: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`
- Gradle env: `OPENCHAMBER_ANDROID_KEYSTORE_PATH` / `_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD`, `OPENCHAMBER_ANDROID_VERSION_CODE` / `VERSION_NAME`
- iOS: `IOS_DISTRIBUTION_CERTIFICATE_BASE64`, `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`, `IOS_APP_PROFILE_BASE64`, `IOS_WIDGET_PROFILE_BASE64`, `IOS_NSE_PROFILE_BASE64`, `IOS_SHARE_PROFILE_BASE64`, `IOS_APP_PROFILE_NAME`, `IOS_WIDGET_PROFILE_NAME`, `IOS_NSE_PROFILE_NAME`, `IOS_SHARE_PROFILE_NAME`, `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`

Bundle IDs / App Group (profiles already match):

- `com.yee94.openchamber`
- `com.yee94.openchamber.OpenChamberWidget`
- `com.yee94.openchamber.OpenChamberNotificationService`
- `com.yee94.openchamber.OpenChamberShareExtension`
- App Group `group.com.yee94.openchamber`

Second-slice Flutter Xcode project has **four native targets**. Release workflow decodes all four profiles **and** writes provisioning settings + ExportOptions for all four bundle IDs. Simulator (`flutter build ios --simulator --no-codesign`) compiles the extension targets; signing those `.appex` bundles on simulator is commonly skipped — signed four-profile export is the macos-26 `flutter-mobile-release.yml` job only.

Capgo (`mobile-beta-ota.yml`) stays Capacitor/WebView. Flutter does not consume Capgo channels.

## Acceptance checklist

| Check | This slice |
|---|---|
| iOS Simulator four-tab shell + pushed Chat | Needs Mac/Xcode. Linux VM: analyze/tests only |
| Four native targets in pbxproj | Landed (Runner / Widget / NSE / Share) |
| Android emulator LAN HTTP + IME composer | Manifest allows cleartext; composer uses solid `viewInsets` |
| Settings slug walkthrough | Widget test walks all slugs + About |
| Keyboard / IME | Android solid viewInsets. iOS UIKit composer owns IME |
| Pairing | v2 parse + redeem on LAN or official E2EE tunnel. Tunnel-open failure stays on connect |
| Chat scroll | Reverse list prepend test + re-enter latest |
| No PIN lock | Widget test asserts no Face ID / PIN / passcode lock |
| No Chat dock tab | Widget test: 4 destinations |
| No iosNativeUi | Catalog + Settings home tests |
| `flutter analyze` + tests on Linux | Required this slice |
| Flutter CI YAML | Push-only on `work/flutter-native`; parallel jobs; iOS job asserts `Runner.app`. **#13 green** on `332ad6f82`: https://github.com/yee94/openchambery/actions/runs/33713282610. **#14 green** on `77baf9b6f`: https://github.com/yee94/openchambery/actions/runs/33714058628 |
| Signed-release YAML attaches all four profiles | Committed. **Signed archive not run here** |

## Commands

```bash
cd apps/mobile_flutter
flutter pub get
flutter analyze
flutter test
flutter run -d ios          # macOS
flutter run -d android
flutter build apk --debug
```

Signed Android (CI already does this; local only if you have the keystore — do not commit it):

```bash
export OPENCHAMBER_ANDROID_KEYSTORE_PATH=...
export OPENCHAMBER_ANDROID_KEYSTORE_PASSWORD=...
export OPENCHAMBER_ANDROID_KEY_ALIAS=...
export OPENCHAMBER_ANDROID_KEY_PASSWORD=...
flutter build apk --release
```

## Third-slice status

| Surface | Status | Notes |
|---|---|---|
| Live HTTP connect | landed | `GET /health`, `GET/POST /auth/session` (`issueClientToken`, `dedupeKey`). Tokens in SecureStore key `openchamber.mobile.token.${encodeURIComponent(connectionKey)}`. Never logged |
| Pairing redeem | landed | `POST /api/client-auth/pairing/redeem` on the winning transport. Persist the **full** candidate list (every LAN + relay). LAN headstart ~1.5s, then race relay. Relay-only still persists `relay://$serverId` + `hostEncPubJwk` + grant |
| Session index home | landed | `GET /api/openchamber/session-index`. Failure ≠ empty. Search + highlight (1.19.3-beta.1). Pinned/in-progress subtitle `项目 · 分支`. Works through the tunnel after a successful relay redeem (unit-tested on a memory wire; no live `wss://` from this VM) |
| Chat transcript + Send/Stop | landed | `GET /api/openchamber/sessions/:id/messages?turns=6`. Send `POST /api/session/:id/prompt_async`. Stop `POST /api/session/:id/abort`. Live `GET /api/global/event` SSE; 2s/4s poll is reconnect fallback only |
| New session | landed | Projects plus-menu `POST /api/session?directory=` using a directory from the loaded index. Honest error if no directory — not a snackbar-only stub |
| Live Activity from busy | landed | Status map `busy`/`retry` arms a single 5s timer (polls do not reset it). `pushType` nil. No rebuild after dismiss |
| Push register | landed | iOS APNs + Android FCM → host `POST /api/push/apns-token` (`platform: ios\|android`). Re-binds when `relayUrl` / instance id changes. Visibility: Flutter `AppLifecycleState` + 20s heartbeat → `POST /api/push/visibility`. Presence skip remains **host-side** |
| Haptics + native back | landed | See parity table |
| Widget snapshots | landed (sparse) | Written after each successful index load |
| Flutter CI concurrency | landed | Push to `work/flutter-native` only + `workflow_dispatch`. Single group `flutter-mobile-ci-work-flutter-native`. Jobs run in parallel (no `needs`). iOS job asserts `build/ios/iphonesimulator/Runner.app`. **#13 green:** https://github.com/yee94/openchambery/actions/runs/33713282610 |

## Fourth-slice status

| Surface | Status | Notes |
|---|---|---|
| E2EE relay tunnel | landed (HTTP mux) | Byte-compatible port of `protocol.ts` / `crypto.ts` / `handshake.ts` / `tunnel-codec.ts` / `tunnel-client.ts` fetch path. Layer 1 `ws/wss` + `v=1&role=client&serverId` (+ optional `grant`). Layer 2 ECDH P-256 + HKDF-SHA-256 (`openchamber-relay-v1`) + AES-256-GCM. Layer 3 HTTP frames, odd client stream ids, negotiated single-frame batches. Dummy parse base `http://tunnel.invalid`. **Not invented.** |
| Tunneled WebSockets | landed (dictation) | Slice 10 ports `openWebSocket` / `WsOpen`…`WsClose` / `oc_url_token` for `/api/dictation/ws`. Event pipeline still uses SSE, not `/api/global/event/ws`. |
| Frame-batching window | partial | Handshake advertises `batch`; single-frame `0x00` envelopes are sent. The 150ms multi-frame body batcher from `createOutboundFrameBatcher` is not ported — legal per protocol. |
| Live event path | landed (SSE) | `GET /api/global/event` with bearer + `Last-Event-ID`. Poll remains reconnect fallback. |
| Android FCM | landed (native SDK) | Copied `packages/mobile/android/app/google-services.json`. No new secret names. Token still null if Firebase init/token fails. |
| Session create | landed | `POST /api/session` |
| iOS simulator CI | asserted | `flutter build ios --simulator --no-codesign` plus `test -d build/ios/iphonesimulator/Runner.app` |

## Fifth-slice status

| Surface | Status | Notes |
|---|---|---|
| Settings completeness | landed (list + official fields) | Every `MOBILE_SETTINGS_PAGE_SLUGS` page except already-real instances/appearance/about now reads official APIs. Slice 6 adds create/edit/delete. Slice 7 adds Provider/MCP OAuth and plugin file write. |
| Settings blob | landed | GET/PUT `/api/config/settings` is a merge PUT, same as `createWebSettingsAPI`. Failure keeps the previous snapshot. |
| Notifications finish | landed | Toggles PUT `nativeNotificationsEnabled` / `notifyOnCompletion` / `notifyOnError` / `notifyOnQuestion`. Background push still uses `POST /api/push/apns-token`. |
| Tunneled WebSockets | landed (dictation) | Slice 10. SSE remains the live event path. |
| Virtual assets / HEIC / picker | landed | See sixth-slice. |

## Sixth-slice status

| Surface | Status | Notes |
|---|---|---|
| Native photo picker | landed | Android `MediaStore.ACTION_PICK_IMAGES` (+ `ACTION_GET_CONTENT` fallback). iOS `PHPicker` on the main actor. |
| HEIC transcode | landed | Official `{data, mime, quality?}` → `{data, mime:'image/jpeg'}`. Accept only `image/heic` / `image/heif`. 32 MiB pick / 25 MiB upload. |
| Virtual image asset | landed (native store) | `create` / `append` / `finish` / `cancel`. Flutter composer preview uses `Image.memory`, not the WebView scheme. |
| Composer image send | landed | `PUT /api/fs/prompt-attachments/{id}` raw bytes + SHA-256 headers, then `prompt_async` `file` parts with `file://` URLs. Never `data:` / `blob:`. |
| Settings entity editors | landed | Providers API key `PUT /api/auth/{id}`; agents/MCP/commands/skills CRUD; assistants POST/PATCH/DELETE + expectedRevision; plugins entry create/edit/delete; skills install `POST /api/config/skills/install`. |
| Provider / MCP OAuth | landed (official paths) | Provider `POST /api/provider/{id}/oauth/authorize` + `/oauth/callback`. MCP SDK `POST /api/mcp/{name}/auth` + `/auth/callback` plus OpenChamber `POST/GET/DELETE /api/mcp/auth/pending`. Opens the system browser. Completes from `openchamber://` callback or pasted code. Auto provider mode calls callback immediately. Live hosted-provider/MCP browser round-trip was **not** exercised from this Linux VM. |
| Plugin file editor | landed | GET/POST/PUT/DELETE `/api/config/plugins/file` — same as `usePluginsStore`. |
| Assistant tab | landed | `GET /api/openchamber/assistants/snapshot`. Enable via `PUT /api/openchamber/assistants/settings`. Tap opens bound `sessionID` or `POST .../session/new`. |
| Scheduled tab | landed | Cards show status + schedule + next-run (never name-only). Run now `POST /api/projects/{projectId}/scheduled-tasks/{taskId}/run` marks `running` from start, then reloads history. |
| App-icon badge | landed (iOS) | From widget-snapshot `attentionCount`. Not a new REST endpoint. |

## Seventh-slice status

| Surface | Status | Notes |
|---|---|---|
| External browser | landed | MethodChannel `openchamber/external_browser`, Capacitor-compatible `open` + http(s) only |
| Provider OAuth | landed (memory + UI) | Official authorize/callback. Browser open + deep-link/code complete. Not a dead `needsBrowser` error. |
| MCP OAuth | landed (memory + UI) | Official `mcp.auth.start/callback` + `/api/mcp/auth/pending`. Same redirect/callback contract as `McpPage` / `McpOAuthCallbackPage`. |
| Plugin source files | landed | Official file GET/POST/PUT/DELETE |
| Chat tool cards | landed | Diff / file op / permission / task (tok/s) cards. Not raw JSON. Permission reply `POST /api/permission/{id}/reply`. |
| Scheduled in-progress cards | landed | Status from start; run-now optimistic `running`; schedule/next/error so cards are not blank names |
| #15 CI | **iOS red on 10f97ff86** | Swift MainActor `mime` missing await. Fixed in Slice 7 (`37074feea`). Do not cite #15 as green. |
| #16 CI | **green on 37074feea** | Analyze + Android debug APK + iOS simulator: https://github.com/yee94/openchambery/actions/runs/33715865698 |

## Eighth-slice status

Read on main (do not invent): `MobileChatScreen.tsx` is a shell around the same `ChatView` as desktop. Tool/activity/mermaid rendering is shared.

| Surface | Status | Main source | Notes |
|---|---|---|---|
| Unified + side-by-side diff | landed (native) | `ToolPart.tsx` `PatchDiff` + `DiffViewToggle.tsx` | Default **unified**. Toggle to side-by-side. Live lines refresh with the transcript. **Not** `@pierre/diffs`. |
| Context-tool grouping | landed | `contextToolGrouping.ts`, `ContextToolGroup.tsx` | Consecutive `read` / `glob` / `grep` / `list` only. Exploring while live / Explored + search/read/list counts. |
| Activity disclosure | landed | `ProgressiveGroup.tsx`, `activityExpansion.ts` | Title chrome: Working while live, Processed when settled. Locked open while the turn is live. Permission stays outside. |
| Permission prompt UX | landed | `PermissionCard.tsx` | Warning + “Permission required” + tool name, patterns, tool-specific body, 3-column Allow once / Always agree / Deny. Reply path unchanged. |
| Mermaid in chat | landed (source card) | `MarkdownRendererImpl.tsx` + `beautiful-mermaid` | Fenced ` ```mermaid ` becomes a first-class card. **No** SVG / pan-zoom — `beautiful-mermaid` is not added. |
| Skill-tool grouping | **Slice 9** | `SkillToolGroup.tsx`, `skillToolGrouping.ts` | Not in Slice 8. |
| Capgo / plan / notes / Todo / Chat dock / iosNativeUi | **will not port** | — | Unchanged. |

## Ninth-slice status

Read on main (do not invent): skill grouping is `isSkillGroupTool` + `SkillToolGroup`. `MobileChatScreen` has no mic; `ChatInput` → `ComposerDictation` uses `/api/dictation/ws`. There is no image-generation tool — image preview is `type: file` + `mime: image/*` (`tool: 'image-preview'`). TTS is message-body `POST /api/tts/speak` / `/api/dictation/tts/speak`, not composer.

| Surface | Status | Main source | Notes |
|---|---|---|---|
| Skill-tool grouping | landed | `skillToolGrouping.ts`, `SkillToolGroup.tsx` | Consecutive `skill` (including `runtime.skill:N`) collapse to “Load Skill” + names (3 visible, overflow). Lone skill still uses the group header. |
| Composer voice (STT) | landed | `ComposerDictation`, `dictation-client.ts` | Slice 10: official `/api/dictation/ws` + 16 kHz PCM. `UnavailableDictation` is no longer the production path. |
| Bash / fetch / search cards | landed | `ToolPart.tsx`, `toolPresentation.tsx` | Expandable Shell Command / Fetch URL / Web Search (and Code Search) with command/url/query titles, not raw JSON. |
| Question card | landed | `toolPresentation.tsx` `question` | First-class Question card. |
| Image preview | landed | `FileAttachment.tsx` `tool: 'image-preview'` | `type: file` + `image/*` is a named Image card **outside** Activity. No invented image-gen tool. |
| Generated commit / PR JSON | landed | `generatedJsonResult.ts` | Assistant text that is commit/PR JSON becomes a card, not a raw dump. |
| Composer TTS | **not composer** | `useLocalTTS.ts` | Message-body `/api/tts/speak`. Settings → Voice already reads `/api/tts/status`. |
| todowrite / todoread | **will not port** | Todo removed in 1.19.2 | Do not rebuild. |
| Capgo / plan / notes / Todo / Chat dock / iosNativeUi | **will not port** | — | Unchanged. |

## Remaining gaps

1. Device-only checks (do not invent another slice): live hosted-provider / MCP OAuth in a real system browser; a relay-paired **phone** on a live `wss://` host (home LAN ↔ away relay hot-switch); live microphone PCM on a real device; the iOS Local Network prompt on a real iPhone. Memory/fake transport proves the 1.5s LAN/relay race, full-candidate persist+reload, and candidates-refresh hot-switch. **Not 真机过.**
2. Android launcher badge — official Push Relay (`packages/relay-server/src/push/schema.js`) rejects `platform === 'android'` and only builds APNs `aps.badge`. There is no FCM send path to hang `NotificationCompat.setNumber` on. Do not invent ShortcutBadger. iOS badge is local `attentionCount` + `aps.badge`.
3. Capgo / plan / notes / Todo / Chat dock tab / `iosNativeUi` — will not port.
4. Pierre `@pierre/diffs` / `beautiful-mermaid` SVG — will not add packages.
5. Experimental session-list fallback when index returns 501 — not a 1.19 mobile happy path.
6. Official nearby is LAN / home network (`mobileConnections.ts`). There is **no** 「附近」 string and **no** Bonjour/mDNS/NWBrowser/NSD — do not add a scanner UI.

## Tenth-slice status

Read on main (do not invent): composer STT is `/api/dictation/ws` + `audio/pcm;rate=16000;bits=16` via `openRuntimeWebSocket` and `oc_url_token`. Message actions expose Read aloud (`POST /api/tts/speak`). TTS is HTTP, not a socket.

| Surface | Status | Main source | Notes |
|---|---|---|---|
| Composer dictation PCM + WS | landed | `dictation-client.ts`, `use-dictation-audio-source.ts` | Production `OfficialDictation` opens `/api/dictation/ws`, waits `ready`, `start`/`chunk`/`finish`. Native iOS/Android capture emits ~1s 16 kHz PCM16LE base64. No on-device STT. |
| Tunneled WebSockets + `oc_url_token` | landed (dictation) | `tunnel-client.ts` `openWebSocket`, `runtime-auth.ts` | `WsOpen`/`WsOpened`/`WsText`/`WsClose`. Mint `POST /auth/url-token` before connect. Needed because dictation is a WebSocket. |
| Message TTS | landed | `MessageBody.tsx`, `useServerTTS.ts` | Assistant Read aloud → `POST /api/tts/speak` `{text, voice, speed, summarize:false}` then native playback. |
| Event `/api/global/event/ws` | landed | `event-pipeline.ts` | Slice 11. Prefer WS, SSE fallback. |
| Capgo / plan / notes / Todo / Chat dock / iosNativeUi | **will not port** | — | Unchanged. |

## Eleventh-slice status

Read on main (do not invent): `event-pipeline.ts` prefers `/api/global/event/ws` (`ready` / `event` / `error` / `backpressure`, `lastEventId` + `oc_url_token`) and falls back to SSE. Android badge is APNs `aps.badge` / iOS only on the official push relay.

| Surface | Status | Main source | Notes |
|---|---|---|---|
| Event pipeline WS + SSE fallback | landed | `event-pipeline.ts` | Relay uses tunneled WS. Memory tests stay on SSE (no fake LAN socket). Mint failure → SSE for 60s, same as main. |
| Android launcher badge | **gap (honest)** | `APNS.md`, `relay-server/src/push/schema.js` | No official FCM send. Do not invent a badge API. |
| Capgo / plan / notes / Todo / Chat dock / iosNativeUi | **will not port** | — | Unchanged. |

## Twelfth-slice status (official look + always-on native chrome)

Yee rejected the Material 3 WidgetTester shots (underline fields, full-width search, flat session list, play-triangle scheduled rows, Projects tab stuck selected). This slice restores the README IA (`docs/references/mobile_*.png` / `packages/ui/src/mobile/*`) without adding product features.

### Visual gap matrix vs README

| Surface | README target | Flutter now | Remaining pixel gap |
|---|---|---|---|
| Projects | Dense nested session rows + subtle 「更多」. Small thin glyphs. Search smaller than `+`. Nested worktrees. | Type: large title stays 32 / tracking 1.6 / height 1.28. Session rows 14 / 0.28 / 1.28 with 7px vertical padding. Meta 13 / 0.35 / 1.45. Icons: search 26 / `+` 28 / glyph 9; leading circle 16; dock glyph 11 in 18×18 squircle. Card/dock shadows are softer than official CSS (README lift). Colors stay catalog orange/sand. | WidgetTester dock is opaque, not `UITabBar` / `UIGlassEffect`. Session count is fixture-driven (20, not 50). |
| Chat | Pushed (dock hidden). Slim header. Dense file list. Ring send. | Same IA. Header title 15 / w500. Body height 1.55 / tracking 0.35. File marks 12×9. Composer `+` 11, send ring 18 / stop 5, scroll FAB 20. User bubble is a primary wash on `OcTokens.card`, not a photo recolor. | **WidgetTester ≠ live iOS glass.** Real iOS keeps `UITextView` + `UIGlassEffect`. No official Grok brand asset. File-type marks are painted MD/TS/TSX. |
| Scheduled | Compact cards, title↔meta gap kept open. Small status glyphs. Shared filter capsule. `+` is catalog primary, not ink black. | Title 16 / 0.45 / 1.32. Meta 13 / 0.35 / 1.45 with 8px gap. Status circle 16 / glyph 7. `+` 28 filled primary. Filter chips sit in one muted track; selected 「全部」 is a soft card pill. Paused rows are greyscale + 0.78 fade. | Create-task `+` is chrome-only. Overflow `...` still calls run-now. |
| Assistant | Contact cards (avatar, name, mode, summary). Enable guide only when off | Landed. No 「启用助理」 toggle on the catalog. | Official guide hero images are not bundled. |
| Settings | Large title, pill search, inset groups. Appearance = language + theme | Landed | Detail pages still use compact back + title. |
| Connect | QR primary, inset grouped fields, no floating-label overlap | Landed | Manual section stays expanded by default so tests can fill URL/token. |
| Tab dock | Four roots, selected glyph = theme primary. Only the active root keeps the selected pill. | iOS: `UITabBarController`. Android/tests: floating capsule with painted glyphs. Selected pill uses `OcSelectedSpring` (not a 300ms linear fade). | WidgetTester capsule is Material-elevation, not `UIGlassEffect`. This VM cannot run an iOS Simulator. |

### Native APIs (always on — grep `apps/mobile_flutter/ios`)

| API | Status |
|---|---|
| `UITabBar` / `UITabBarController` | Wired (`OpenChamberTabBarView.swift`) |
| `UITextView` composer + `UIGlassEffect` runtime lookup | Wired (`OpenChamberComposerView.swift`) |
| `ActivityKit` Live Activity | Wired (`OpenChamberLiveActivityManager.swift`) |
| `UIImpactFeedbackGenerator` | Wired (haptics plugin + composer send/attach) |
| `PHPickerViewController` | Wired (media plugin) |
| `UIDocumentPickerViewController` | Wired (composer Files action) |
| VisionKit QR on MainActor | Wired |
| Keychain (`SecItem*`) | Wired |
| Share Extension + App Group + NSE + Widget | Wired (existing targets) |
| `UIScreenEdgePanGestureRecognizer` | **Installed** on the Flutter view (`OpenChamberNavigationPlugin`). Enabled only while an `IosNativePageRoute` is on the stack. Flutter `popGestureEnabled` is **false** so Cupertino/Material swipes cannot replace it. Progress is coalesced on `CADisplayLink` (same commit rule as Capacitor: ≥0.35 or ≥0.08 + vx≥700). Swipe-commit fires medium impact. |

### Android degradations (intentional)

- Dock: Material floating capsule, not liquid glass.
- Composer: solid pill + `viewInsets`, not `UIGlassEffect`.
- No Live Activity / Dynamic Island / WidgetKit.
- Photo picker: system Photo Picker (`ACTION_PICK_IMAGES`).
- Haptics: `performHapticFeedback`.

## Thirteenth-slice status (WebView design tokens)

Source of truth: `packages/ui/src/styles/design-system.css` (`:root` / `.dark` OKLCH) and `packages/ui/src/styles/mobile.css` (`--oc-mobile-*`, `--surface-*` fallbacks). Mobile CSS does **not** override `--primary`. Appearance is Light / Dark / System only.

Flutter maps the catalog through `OcTokens` (`apps/mobile_flutter/lib/theme/oc_tokens.dart`) for `Brightness.light` and `Brightness.dark`. OKLCH is converted once (`oklch.dart`). Hex below is the resolved sRGB clip. `.dark` comments in `design-system.css` (e.g. `#151313` / `#edb449`) are approximate annotations, not a second palette.

README photos are the **type/icon optical** target (tracking, leading, glyph scale). Official `--primary` stays orange / golden sand (`#e66200` / `#e5a900`). Do **not** recolor Projects / Chat / Scheduled to the photo's UIKit blue / grouped gray — those are a different theme. `OcOptical` holds the measured sizes. Appearance Light / Dark / System still switches `OcTokens`.

Live WebView then overwrites `:root` with Flexoki (`#BC5215` / `#fffdf4`) via ThemeSystem. Flutter Appearance has no theme picker, so Light/Dark follow the design-system defaults — not Flexoki JSON. That is an honest leftover, not a parallel invented palette.

| CSS var | Flutter token | Light (oklch → hex) | Dark (oklch → hex) |
|---|---|---|---|
| `--background` / `--surface-background` | `background` / `surfaceBackground` | `oklch(0.97 0.02 85)` → `#fbf4e6` | `oklch(0.16 0.01 30)` → `#110c0b` |
| `--foreground` / `--surface-foreground` | `foreground` / `surfaceForeground` | `oklch(0.25 0.02 40)` → `#2a1e1a` | `oklch(0.85 0.02 90)` → `#d3cdbf` |
| `--card` / `--surface-elevated` | `card` / `surfaceElevated` | `oklch(0.99 0.01 90)` → `#fefcf4` | `oklch(0.19 0.01 40)` → `#181210` |
| `--card-foreground` | `cardForeground` | same as foreground | same as foreground |
| `--popover` | `popover` | same as card | `oklch(0.24 0.01 40)` → `#241e1c` |
| `--primary` / `--ring` / `--sidebar-primary` | `primary` / `ring` / `sidebarPrimary` | `oklch(0.65 0.2 55)` → `#e66200` | `oklch(0.77 0.17 85)` → `#e5a900` |
| `--primary-foreground` | `primaryForeground` | `oklch(0.99 0.01 90)` → `#fefcf4` | `oklch(0.16 0.01 30)` → `#110c0b` |
| `--secondary` / `--accent` | `secondary` / `accent` | `oklch(0.92 0.02 80)` → `#ece3d6` | `oklch(0.29 0.01 40)` → `#302a28` |
| `--muted` / `--surface-muted` | `muted` / `surfaceMuted` | `oklch(0.9 0.015 75)` → `#e4ddd3` | `oklch(0.33 0.01 40)` → `#3a3432` |
| `--muted-foreground` | `mutedForeground` | `oklch(0.45 0.02 50)` → `#5f524c` | `oklch(0.75 0.02 80)` → `#b5ada0` |
| `--destructive` | `destructive` / `statusError` | `oklch(0.55 0.25 25)` → `#df000d` | `oklch(0.65 0.15 30)` → `#db6656` |
| `--border` / `--sidebar-border` | `border` / `sidebarBorder` | `oklch(0.85 0.02 70)` → `#d7ccc0` | `oklch(0.31 0.01 35)` → `#352f2d` |
| `--input` | `input` | `oklch(0.88 0.02 75)` → `#dfd6c9` | same as muted |
| `--chart-1` | `chart1` / `statusInfo` | `oklch(0.58 0.15 230)` → `#0088c1` | `oklch(0.68 0.12 230)` → `#32a5d4` |
| `--chart-2` | `chart2` / `statusSuccess` | `oklch(0.58 0.15 145)` → `#33903c` | `oklch(0.68 0.12 145)` → `#66ac69` |
| `--chart-3` | `chart3` | same as primary | `oklch(0.7 0.13 95)` → `#b89d2b` |
| `--chart-4` | `chart4` | `oklch(0.55 0.18 30)` → `#c53829` | `oklch(0.65 0.14 45)` → `#d37040` |
| `--chart-5` | `chart5` | `oklch(0.6 0.16 85)` → `#ab7500` | `oklch(0.68 0.12 55)` → `#d1834b` |
| `--sidebar` | `sidebar` | `oklch(0.95 0.02 80)` → `#f6ede0` | same as background |
| `--sidebar-accent` | `sidebarAccent` | `oklch(0.9 0.02 75)` → `#e6dcd0` | same as popover |
| `--oc-mobile-page-background` | `pageBackground` | muted 18% over background | same mix |
| `--oc-mobile-border` | `mobileBorder` | foreground 6% | foreground 3% |
| `--form-surface-border` | `formSurfaceBorder` | foreground 8% | foreground 8% |
| `--radius` / `--form-control-radius` | `OcTokens.radius` | 10 | 10 |
| `--oc-mobile-surface-radius` | `surfaceRadius` | 24 | 24 |
| `--oc-mobile-inset-radius` | `insetRadius` | 16 | 16 |
| `--oc-mobile-control-radius` | `controlRadius` | 20 | 20 |
| `--oc-mobile-root-title-size` | `rootTitleSize` | 32 | 32 |
| `--text-markdown` (mobile) | `textMarkdown` | 15 | 15 |
| `--text-ui-header` (mobile) | `textUiHeader` | 14 | 14 |
| `--text-ui-label` / `--text-meta` (mobile) | `textUiLabel` / `textMeta` | 13 | 13 |
| `--oc-mobile-dock-height` | `dockHeight` | 68 | 68 |

Product chrome **not** in the semantic catalog: agent-count purple `OcProductChrome.agentAccent` (`#7A5CFF`).

`--oc-mobile-glass-fill` is **not** faked in Flutter. iOS keeps `UIGlassEffect` / `UITabBar`. Android/WidgetTester dock and composer stay opaque `surfaceElevated`.

## Fourteenth-slice status (native press / spring / back)

Motion only. Sibling chrome owns color / type / radii / shadows. Chat stays a pushed page (dock hidden). No `iosNativeUi` toggle.

### What is real UIKit vs Flutter spring

| Interaction | iOS | Android / WidgetTester |
|---|---|---|
| Card / row / circular + / search / dock-tab press | Flutter `Pressable` scale **0.975** (finger-down **immediate**, release 260ms official overshoot cubic). Highlight = `--oc-mobile-press-fill` (foreground 7%). Cancel on drag-out. | Same timing and scale. No glass clone. |
| iOS composer Send / + / mic | **UIKit** `UIView.animate` spring 0.975 + reused `UIImpactFeedbackGenerator` | Flutter `Pressable` on the solid pill |
| Haptics | **Always-on UIKit**: one prepared generator per style (`OpenChamberHapticFeedback`). Light = tab + row. Medium = send / + attach / swipe-commit. Never `HapticFeedback.*` on iOS. | `performHapticFeedback` CLOCK_TICK / KEYBOARD_TAP / LONG_PRESS |
| Interactive back | **`UIScreenEdgePanGestureRecognizer`** on the Flutter view, left edge only, `CADisplayLink` progress. Flutter `IosNativePageRoute.popGestureEnabled = false`. | System predictive back (`PredictiveBackPageTransitionsBuilder`). Already started. |
| Push / pop Chat | `IosNativePageRoute` = Cupertino slide (UINavigationController), 350ms `fastEaseInToSlowEaseOut`. Not a 300ms linear fade. | `MaterialPageRoute` + predictive back |
| Tab switch | iOS `UITabBarController` (native). Flutter roots stay `IndexedStack` (instant, not a fade). | Flutter capsule: press scale + `OcSelectedSpring` (iOS CASpring 522.35 / 45.71) on the selected pill |
| 任务/历史记录 + filter chips | Flutter press + selected CASpring (not an instant snap) | Same |

Feel it on a device: `apps/mobile_flutter/README.md` § Feel press / spring / back. WidgetTester covers press scale, drag-out cancel, selected spring, and that the iOS route refuses a Flutter pop gesture.

## Fifteenth-slice status (official 附近 / LAN connect)

Official nearby is **LAN / home network**, not Bonjour. Source of truth: `packages/ui/src/apps/mobileConnections.ts`, `connectionPayload.ts`, Capacitor `Info.plist` `NSLocalNetworkUsageDescription`, zh-CN `已连接 · 局域网` / `已连接 · 中继`.

| Surface | Status | Notes |
|---|---|---|
| iOS Local Network usage string | landed (plist) | Copied official English `NSLocalNetworkUsageDescription`. Kept camera/mic strings and ATS `NSAllowsLocalNetworking` + `NSAllowsArbitraryLoads`. **Device-only:** the iOS prompt was not shown on a real phone. |
| Persist full v2 candidates | landed | `lan` + `relayUrl` + `hostEncPubJwk` + grant + `serverId`. Reload keeps relay; does not collapse to a single LAN URL. Legacy `{url, relayUrl}` migrates. |
| `probeConnectionCandidates` race | landed (memory) | LAN headstart 1.5s, then race relay. LAN win → `mobile.instances.status.connectedDirect`. Relay-only / LAN timeout → `connectedRelay`. Tunnel-open failure stays on connect. |
| Candidate refresh + hot-switch | landed (memory) | `GET /api/client-auth/connection/candidates`. Fresh LAN replaces http LAN-class directs; https + relay preserved. Empty / failed fetch is skip, not wipe. Reprobe after update when on relay (home). Resume reprobe is production-only. |
| Bonjour / 「附近」 scanner | **will not add** | Official product has neither. |
| Live phone home ↔ away | **device-only** | Not claimed. Memory/fake transport only. |
