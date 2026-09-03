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
| Flutter CI | landed | `.github/workflows/flutter-mobile-ci.yml` automatic on this track |
| Signed release workflow | landed | `.github/workflows/flutter-mobile-release.yml` — existing secret names only |

## Settings slug checklist (`MOBILE_SETTINGS_PAGE_SLUGS`)

| Slug | Group | First-slice page |
|---|---|---|
| `instances` | connection | List + add + QR scan (persist v2 payload / relayUrl) |
| `appearance` | personalization | Language + theme. **No iosNativeUi.** |
| `chat` | personalization | Structured placeholder |
| `notifications` | personalization | Real-enough toggles (local + push hint) |
| `sessions` | personalization | Structured placeholder |
| `summary-ai` | personalization | Structured placeholder |
| `projects` | workspace | Structured placeholder |
| `git` | workspace | Structured placeholder |
| `providers` | opencode | Structured placeholder |
| `agents` | opencode | Structured placeholder |
| `assistants` | opencode | Structured placeholder |
| `behavior` | opencode | Structured placeholder |
| `commands` | opencode | Structured placeholder |
| `mcp` | opencode | Structured placeholder |
| `plugins` | opencode | Structured placeholder |
| `magic-prompts` | content | Structured placeholder |
| `snippets` | content | Structured placeholder |
| `skills.installed` | content | Structured placeholder |
| `usage` | system | Structured placeholder |
| `voice` | system | Structured placeholder |
| `about` | system | App name, native client `1.19.3-beta.5`, instance version separate |

## Second-slice status (this PR)

| Surface | Status | Notes |
|---|---|---|
| Four Xcode targets in `Runner.xcodeproj` | landed | Runner `com.yee94.openchamber`; Widget `…OpenChamberWidget` (17.0); NSE `…OpenChamberNotificationService`; Share `…OpenChamberShareExtension`. App Group `group.com.yee94.openchamber`. Embed App Extensions `dstSubfolderSpec = 13`. No `DEVELOPMENT_TEAM` baked in. |
| Release YAML four-profile signing | landed | `flutter-mobile-release.yml` pbxproj replacements + ExportOptions map all four bundle IDs / existing profile secrets |
| iOS composer UIKit platform view | landed | `UIGlassEffect` on iOS 26; system blur on older iOS. Attachments, `/` `@` stub that pan-scrolls, IME, Send/Stop. Warm overlay on Projects; hide immediately on leave. Occupancy = collapsed 56pt only |
| iOS 26 glass tab bar | landed | Chrome-only `UITabBarController`. Older iOS: system translucent `UITabBar`. Chat remains pushed. Widget tests stay on Material `NavigationBar` |
| Live Activity local MVP | landed (iOS 17+) | One Activity, 5s demo timer, `pushType: nil`, no rebuild after dismiss. Android channel is a no-op |
| SecureStore | landed | Production `PlatformSecureStore`: iOS Keychain + Android Keystore AES-GCM. Tests still inject `MemorySecureStore`. Never logs values |
| QR + deep link | landed (thin redeem) | iOS VisionKit `DataScanner` (Apple on-device ML; not a Google ML Kit CocoaPod). Android Google Code Scanner then CameraX + ML Kit. Parses v2 `p=` and persists `relayUrl` / pairing secret. **Does not** call a made-up redeem HTTP API |
| Android IME + share | landed | Solid `viewInsets` surface. `ShareReceiverActivity` + Direct Share shortcuts. Exact instance+assistant only — no silent default |
| Simulator CI | documented | `flutter build ios --simulator --no-codesign` includes the new targets. Simulator often skips extension signing. Linux VM cannot run this. **This agent did not run the macos-15 job.** |
| Capgo / plan / notes / Todo / Chat dock | **not present** | Do not rebuild |

## Native parity (always on — not optional)

| Contract | Status | Main source | Notes |
|---|---|---|---|
| Connection onboarding | landed | `MobileApp.tsx`, HANDOFF | Live `GET /health`, `GET/POST /auth/session`, pairing redeem. Auto-connect last token. Delete-active → connect |
| QR pairing | landed | `mobileQrScan.ts`, `connectionPayload.ts` | Persist payload + `relayUrl` + `hostEncPubJwk` + grant. Redeems `POST /api/client-auth/pairing/redeem` on the first reachable transport (LAN, then official E2EE tunnel) |
| iOS composer | landed | `OpenChamberComposer` | UIKit platform view, always on |
| Android composer | landed | IME viewInsets | Material + solid inset surface. ImeSync analogue still later |
| iOS liquid-glass dock | landed | `OpenChamberTabBar` | iOS 26 `UIGlassEffect`; older: system translucent bar |
| Android dock | landed (Material 3) | Web `MobileTabBar` | Keep solid/translucent Material `NavigationBar` |
| Live Activity / Dynamic Island | landed | `OpenChamberLiveActivity` | Driven from `GET /api/session/status` busy/retry; start after 5s; `pushType` nil; no rebuild after dismiss |
| Share-in | landed | Share extension + `ShareReceiverActivity` | Exact instance+assistant. Catalog published from saved instances |
| Push | landed (host register) | APNs + FCM → `openchamber-push-relay` | Mobile `POST /api/push/apns-token` + `POST /api/push/visibility`. Host binds relay. iOS requests APNs token. Android copies Capacitor `google-services.json` (`com.yee94.openchamber` / `openchamber-8bf7e`) and reads the FCM token via the native Firebase SDK — still **null** if Firebase is unavailable (not invented). Presence skip is **host-side** (`isAnyInteractiveClientVisible`) |
| WidgetKit + Control Center + NSE | landed | `OpenChamberWidget`, NSE | Snapshot JSON `{attentionCount, recentSessions}` written to App Group `widgetSnapshot` from the live index |
| Haptics | landed | `OpenChamberHaptics` | light / medium / heavy via method channel |
| Native back | landed | Flutter routes | iOS `CupertinoPageRoute` edge pan; Android `PredictiveBackPageTransitionsBuilder` |
| Secure storage | landed | Keychain / Android Keystore | Never log tokens |
| Deep links | landed | `openchamber://` | Pairing cold-launch, share-inbox, session jump URI |
| Virtual assets / HEIC / Android picker | missing | `OpenChamberVirtualAsset`, `OpenChamberMedia` | Later |
| External browser | missing | Android-only plugin | Later |
| App-icon badge | missing | HANDOFF | Later |
| Status bar | stub | Capacitor overlay | Use Flutter/system insets |
| Capgo OTA | **will not port** | `@capgo/capacitor-updater` | Full IPA/APK via signed-release |

## Android degradation (intentional — native Android, not fake iOS)

| iOS-native effect | Android product path |
|---|---|
| iOS 26 liquid-glass dock | Material 3 `NavigationBar` (solid / translucent) |
| UIKit liquid-glass composer | Material composer + IME viewInsets / later ImeSync analogue |
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
| `.github/workflows/flutter-mobile-ci.yml` | **push to `work/flutter-native` only** + `workflow_dispatch` | Parallel `analyze-test` / `android-debug` / `ios-simulator`. Flutter **3.32.8** pinned. No `pull_request`. iOS job is a real `flutter build ios --simulator --no-codesign` and asserts `Runner.app`. **Run #9 on `16a6eb215`:** analyze+tests **success**, Android debug APK **success**, iOS **failed** — `Runner.xcodeproj` parse error (`missing semicolon in dictionary` on extension `buildSettings`). Fixed in slice 4 by closing those dictionaries with `};`. **Do not claim this slice green until a later Actions run finishes.** |
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
| Flutter CI YAML | Push-only on `work/flutter-native`; parallel jobs; iOS job asserts `Runner.app`. **Actions green is not claimed from this VM** |
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
| Pairing redeem | landed | `POST /api/client-auth/pairing/redeem` on first reachable candidate. LAN first, then official E2EE tunnel (`packages/ui/src/lib/relay/*`). Relay-only persists `relay://$serverId` + `hostEncPubJwk` + grant |
| Session index home | landed | `GET /api/openchamber/session-index`. Failure ≠ empty. Search + highlight (1.19.3-beta.1). Pinned/in-progress subtitle `项目 · 分支`. Works through the tunnel after a successful relay redeem (unit-tested on a memory wire; no live `wss://` from this VM) |
| Chat transcript + Send/Stop | landed | `GET /api/openchamber/sessions/:id/messages?turns=6`. Send `POST /api/session/:id/prompt_async`. Stop `POST /api/session/:id/abort`. Live `GET /api/global/event` SSE; 2s/4s poll is reconnect fallback only |
| New session | landed | Projects plus-menu `POST /api/session?directory=` using a directory from the loaded index. Honest error if no directory — not a snackbar-only stub |
| Live Activity from busy | landed | Status map `busy`/`retry` arms a single 5s timer (polls do not reset it). `pushType` nil. No rebuild after dismiss |
| Push register | landed | iOS APNs + Android FCM → host `POST /api/push/apns-token` (`platform: ios\|android`). Re-binds when `relayUrl` / instance id changes. Visibility: Flutter `AppLifecycleState` + 20s heartbeat → `POST /api/push/visibility`. Presence skip remains **host-side** |
| Haptics + native back | landed | See parity table |
| Widget snapshots | landed (sparse) | Written after each successful index load |
| Flutter CI concurrency | landed | Push to `work/flutter-native` only + `workflow_dispatch`. Single group `flutter-mobile-ci-work-flutter-native`. Jobs run in parallel (no `needs`). iOS job asserts `build/ios/iphonesimulator/Runner.app`. **This agent did not claim Actions green** |

## Fourth-slice status

| Surface | Status | Notes |
|---|---|---|
| E2EE relay tunnel | landed (HTTP mux) | Byte-compatible port of `protocol.ts` / `crypto.ts` / `handshake.ts` / `tunnel-codec.ts` / `tunnel-client.ts` fetch path. Layer 1 `ws/wss` + `v=1&role=client&serverId` (+ optional `grant`). Layer 2 ECDH P-256 + HKDF-SHA-256 (`openchamber-relay-v1`) + AES-256-GCM. Layer 3 HTTP frames, odd client stream ids, negotiated single-frame batches. Dummy parse base `http://tunnel.invalid`. **Not invented.** |
| Tunneled WebSockets | **gap** | `openWebSocket` / `WsOpen`…`WsClose` / `oc_url_token` from `packages/ui/src/lib/relay/tunnel-client.ts` and `packages/ui/src/lib/runtime-auth.ts` are **not** ported. Health / redeem / auth / session-index / prompt / SSE do not need them. Event pipeline on main prefers `/api/global/event/ws` then falls back to SSE (`event-pipeline.ts`). Flutter uses SSE only. |
| Frame-batching window | partial | Handshake advertises `batch`; single-frame `0x00` envelopes are sent. The 150ms multi-frame body batcher from `createOutboundFrameBatcher` is not ported — legal per protocol. |
| Live event path | landed (SSE) | `GET /api/global/event` with bearer + `Last-Event-ID`. Poll remains reconnect fallback. |
| Android FCM | landed (native SDK) | Copied `packages/mobile/android/app/google-services.json`. No new secret names. Token still null if Firebase init/token fails. |
| Session create | landed | `POST /api/session` |
| iOS simulator CI | asserted | `flutter build ios --simulator --no-codesign` plus `test -d build/ios/iphonesimulator/Runner.app` |

## Remaining gaps

1. Tunneled WebSockets + `oc_url_token` (`packages/ui/src/lib/relay/tunnel-client.ts` `openWebSocket`, `packages/ui/src/lib/runtime-auth.ts`)
2. Experimental session-list fallback when index returns 501
3. Virtual assets / HEIC / picker
4. Capgo / plan / notes / Todo / Chat dock tab — will not port
5. A relay-paired **phone** talking to a real hosted relay was **not** exercised from this Linux VM. Dart client ↔ Dart host memory-wire proves redeem + session-index. Live `wss://` + real host private key is still a device/network check.
