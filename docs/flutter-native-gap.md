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
| Connection onboarding | landed | `MobileApp.tsx`, HANDOFF | Live HTTP + `--ui-password` unlock + token issuance still later |
| QR pairing | landed | `mobileQrScan.ts`, `connectionPayload.ts` | Persist payload + `relayUrl`. Thin client: no fake redeem session |
| iOS composer | landed | `OpenChamberComposer` | UIKit platform view, always on |
| Android composer | landed | IME viewInsets | Material + solid inset surface. ImeSync analogue still later |
| iOS liquid-glass dock | landed | `OpenChamberTabBar` | iOS 26 `UIGlassEffect`; older: system translucent bar |
| Android dock | landed (Material 3) | Web `MobileTabBar` | Keep solid/translucent Material `NavigationBar` |
| Live Activity / Dynamic Island | landed | `OpenChamberLiveActivity` | Local MVP, demo 5s timer until real sync |
| Share-in | landed | Share extension + `ShareReceiverActivity` | Exact instance+assistant. Catalog published from saved instances |
| Push | missing | APNs + FCM → `openchamber-push-relay` | NSE target exists and refreshes widget snapshot; relay bind later |
| WidgetKit + Control Center + NSE | landed (targets) | `OpenChamberWidget`, NSE | Real pbxproj targets. Snapshot write from live sync still later |
| Haptics | missing | `OpenChamberHaptics` | light / medium / heavy |
| Native back | missing | `OpenChamberNavigation` | Edge pan + predictive back for pushed Chat / Settings |
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
| Pairing | v2 payload parse + persist `relayUrl`. QR wired; redeem HTTP still later |
| Chat scroll | Reverse list prepend test + re-enter latest |
| No PIN lock | Widget test asserts no Face ID / PIN / passcode lock |
| No Chat dock tab | Widget test: 4 destinations |
| No iosNativeUi | Catalog + Settings home tests |
| `flutter analyze` + tests on Linux | Required this slice |
| Flutter CI YAML valid | Committed. **macos-15 simulator job not run on this Linux VM** |
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

## Next slices

1. Live HTTP connect + `--ui-password` unlock + pairing **redeem** (payload is already persisted)
2. Real session sync against official OpenCode / OpenChamber APIs (LegendList-class transcript) driving Live Activity instead of the 5s demo timer
3. FCM / APNs push-relay bind; presence-aware skip
4. Haptics + native back (edge pan / predictive back)
5. Virtual assets / HEIC / Android picker
6. Widget snapshot writes from live session index (targets exist; data is still demo/empty)
