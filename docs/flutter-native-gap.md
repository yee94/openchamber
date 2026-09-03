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
| Projects home + `项目 · 分支` | landed | Demo rows; unread dot kept (1.19.2). Plus menu 扫一扫 / 切换实例. |
| Chat skeleton | landed | Reverse list (LegendList analogue) + native composer chrome. Re-enter jumps to latest (1.19.3-beta.5). |
| Settings home + all slugs | landed | Search + grouped drill-in. Real-enough: instances, appearance, notifications, about. |
| Appearance `iosNativeUi` | **not present** | Do not rebuild. Native is always on. |
| Plan mode / project notes / Todo | **not present** | Removed in 1.19.2. Do not rebuild. |
| Capgo OTA | **not ported** | WebView web-bundle hot update only. Flutter ships IPA/APK. |
| Flutter CI | landed | `.github/workflows/flutter-mobile-ci.yml` automatic on this track |
| Signed release workflow | landed | `.github/workflows/flutter-mobile-release.yml` — existing secret names only |

## Settings slug checklist (`MOBILE_SETTINGS_PAGE_SLUGS`)

| Slug | Group | First-slice page |
|---|---|---|
| `instances` | connection | Real-enough list + add + QR TODO |
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

## Native parity (always on — not optional)

| Contract | Status | Main source | Flutter next slice |
|---|---|---|---|
| Connection onboarding | landed | `MobileApp.tsx`, HANDOFF | Live HTTP + `--ui-password` unlock + token issuance |
| QR pairing | stub | `mobileQrScan.ts`, ML Kit | ML Kit; Android Google scanner then CameraX; `openchamber://connect?v=2&p=`; persist `relayUrl` |
| iOS composer | stub | `OpenChamberComposer`, `native-composer-keyboard.mjs` | Always-on UIKit liquid-glass pill/card, IME, `/` `@`, attach, Send/Stop, warm-on-home, hide-on-leave |
| Android composer | stub | Capacitor WebView composer + `ImeSyncBridge` | Native Material composer + IME analogue. **No WebView path.** |
| iOS liquid-glass dock | stub | `OpenChamberTabBar` (iOS 26 `UIGlassEffect`) | Platform `UITabBar` for the four roots. Older iOS: system translucent bar, not a fake glass clone |
| Android dock | landed (Material 3) | Web `MobileTabBar` | Keep solid/translucent Material `NavigationBar` |
| Live Activity / Dynamic Island | missing | `OpenChamberLiveActivity` | iOS 17+, one Activity, 5s busy, no rebuild after user dismiss, no `pushType` yet |
| Share-in | missing | Share extension + `ShareReceiverActivity` | App Group `group.com.yee94.openchamber`; honor exact instance+assistant |
| Push | missing | APNs + FCM → `openchamber-push-relay` | Presence-aware skip; language-aware APNs title; re-bind on relay URL; NSE `mutable-content` |
| WidgetKit + Control Center + NSE | missing | `OpenChamberWidget`, NSE | Same four bundle IDs and App Group as Capacitor profiles |
| Haptics | missing | `OpenChamberHaptics` | light / medium / heavy |
| Native back | missing | `OpenChamberNavigation` | Edge pan + predictive back for pushed Chat / Settings |
| Secure storage | stub | `@aparajita/capacitor-secure-storage` | iOS Keychain + Android keystore-backed store. Never log tokens |
| Deep links | stub | `openchamber://` | Pairing, notification taps, widgets, Control Center |
| Virtual assets / HEIC / Android picker | missing | `OpenChamberVirtualAsset`, `OpenChamberMedia` | Later |
| External browser | missing | Android-only plugin | Later |
| App-icon badge | missing | HANDOFF | Later |
| Status bar | stub | Capacitor overlay | Use Flutter/system insets |
| Capgo OTA | **will not port** | `@capgo/capacitor-updater` | Full IPA/APK via signed-release. About still shows native vs instance versions |

## Android degradation (intentional — native Android, not fake iOS)

| iOS-native effect | Android product path |
|---|---|
| iOS 26 liquid-glass dock | Material 3 `NavigationBar` (solid / translucent) |
| UIKit liquid-glass composer | Material composer + IME viewInsets / later ImeSync analogue |
| Live Activity / Dynamic Island | Not applicable |
| WidgetKit / Control Center / NSE | FCM + Android widgets later; not a glass clone |
| UIImpactFeedbackGenerator | `performHapticFeedback` later |
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
| `.github/workflows/flutter-mobile-ci.yml` | push/PR on `work/flutter-native` (+ `cursor/flutter-native-8ab3`), `workflow_dispatch` | `flutter pub get` + analyze + widget tests; Android debug APK (ubuntu, Java 21); iOS simulator (`macos-15`) |
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

First-slice Flutter Xcode project has **Runner only**. The release workflow still **decodes all four profiles**. Archive/export currently signs Runner (`com.yee94.openchamber`). Widget / NSE / Share **targets** are the next native slice; TestFlight of a complete extension-bearing IPA waits on those targets.

Capgo (`mobile-beta-ota.yml`) stays Capacitor/WebView. Flutter does not consume Capgo channels.

## Acceptance checklist

| Check | This slice |
|---|---|
| iOS Simulator four-tab shell + pushed Chat | Commands below; needs Mac/Xcode. Linux VM: analyze/tests only |
| Android emulator LAN HTTP + IME composer | Manifest allows cleartext; IME uses Flutter `viewInsets` |
| Settings slug walkthrough | Widget test walks all slugs + About |
| Keyboard / IME | Composer above `SafeArea`; Android ImeSync analogue still stub |
| Pairing | URL + `openchamber://connect?v=2&p=` parse; QR is stub |
| Chat scroll | Reverse list prepend test + re-enter latest |
| No PIN lock | Widget test asserts no Face ID / PIN / passcode lock |
| No Chat dock tab | Widget test: 4 destinations |
| No iosNativeUi | Catalog + Settings home tests |
| `flutter analyze` + tests on Linux | Required this slice |
| Flutter CI YAML valid | Committed |
| Signed-release YAML references existing secrets | Committed |

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

## Next slices

1. Keychain / keystore `SecureStore` (replace in-memory)
2. Live HTTP connect + password unlock + pairing redeem + `relayUrl`
3. ML Kit / CameraX QR + `openchamber://` cold launch
4. Always-on iOS UIKit composer + UIGlassEffect dock + Live Activity / Widget / NSE / Share targets (same bundle IDs)
5. Always-on Android composer IME analogue, share receiver, FCM
6. Session sync against official OpenCode / OpenChamber APIs (LegendList-class transcript)
7. Wire Widget/NSE/Share into the Flutter Xcode project so TestFlight export can attach all four profiles
