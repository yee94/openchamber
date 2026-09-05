# OpenChamber Flutter mobile

Independent **native-first** Flutter rewrite of OpenChamber mobile.

- Track: `work/flutter-native` (do **not** merge to `main`)
- Product baseline: `main` @ `70ad324` / `1.19.5-beta.14` (Flutter still does **not** claim 真机过)
- Capacitor shell (`packages/mobile`) stays on this branch; this app sits beside it
- Chat list analogue: reverse `ListView` (LegendList behavior). No TanStack Virtual / StickToBottom / Virtua
- Native is the product: no Appearance `openchamber.iosNativeUi` toggle, no WebView fallback
- Capgo OTA is **not** ported. Ship full IPA/APK via `.github/workflows/flutter-mobile-release.yml`

App id: `com.yee94.openchamber` (release). Debug Android uses Capacitor’s `applicationIdSuffix` `.debug` → `com.yee94.openchamber.debug`, launcher **OpenChamber v2**, so it installs beside the official Capacitor app. Launcher art is the same official OpenChamber mark as `packages/mobile` (Android mipmaps + adaptive icon, iOS `AppIcon`); only the debug label/package distinguish v2. FCM `google-services.json` already lists that debug package (same Firebase project; no new secrets). Token is still null if Firebase init fails — not invented.

Gap / acceptance matrix: [`docs/flutter-native-gap.md`](../../docs/flutter-native-gap.md)

## Run

```bash
cd apps/mobile_flutter
flutter pub get
flutter analyze
flutter test
```

iOS Simulator (macOS + Xcode):

```bash
flutter run -d ios
```

Android emulator / device (LAN HTTP is allowed via `usesCleartextTraffic`):

```bash
flutter run -d android
```

Linux VM (this cloud image): `flutter analyze` and `flutter test` only. `flutter build ios` needs Xcode.

## Feel press / spring / back on a device

WidgetTester can assert press scale and that Flutter does not own the iOS edge-pan. It cannot film UIKit springs.

On a **real iPhone** (or Simulator with I/O → Touch):

1. Projects: press a session row, the circular search, and `+`. The surface should scale to ~0.975 on finger-down and spring back on release. Drag off the row to cancel.
2. Dock: tab press is light `UIImpactFeedbackGenerator`. iOS selected chrome is `UITabBar`; Android uses the same 0.975 scale + selected spring (not a linear fade).
3. Open a session (pushed Chat, dock hidden). Interactive back is `UIScreenEdgePanGestureRecognizer` from the **physical left edge** — do not expect a Material swipe from mid-screen.
4. Composer: `+` attach and Send use **medium** impact. iOS buttons are UIKit-scaled; Android uses the same Flutter `Pressable` curve.
5. Schedule: 任务/历史记录 and 全部/已启用/已暂停 press-scale, then the selected pill springs (no instant snap).

Android uses the same timing/scale. Haptics are `performHapticFeedback` (CLOCK_TICK / KEYBOARD_TAP). No fake `UIGlassEffect`.

## Surfaces

1. Splash → live HTTP onboarding (`GET /health`, `GET/POST /auth/session`, pairing redeem on LAN or the official E2EE relay tunnel). **No local PIN / Face ID lock.**
2. Four-tab dock: Projects / Assistant / Scheduled / Settings. iOS uses a UIKit `UITabBar` (liquid glass on iOS 26).
3. Chat is pushed from the live session index (pinned/in-progress `项目 · 分支` subtitles). Send/Stop hit `prompt_async` / `abort`. Plus-menu creates `POST /api/session`. Live events are `GET /api/global/event` SSE.
4. Always-on native composer (UIKit glass on iOS; frosted Flutter pill + IME viewInsets on Android / WidgetTester)
5. Settings home: search + mobile Settings slugs (no Voice page)
6. iOS targets: Runner, WidgetKit+Live Activity+Control, NSE, Share Extension (same bundle IDs / App Group as Capacitor)

## CI

- Smoke (push to `work/flutter-native` only, plus `workflow_dispatch`): `.github/workflows/flutter-mobile-ci.yml`
  - `analyze-test` is the performance gate: `flutter test` includes `test/chat_transcript_perf_test.dart` (500-message fixture, rebuild-count + CI CPU budgets).
  - Android job uploads `openchamber-flutter-android-debug-apk-<shortsha>` (14-day retention). The file inside is `openchamber-v2-debug-<shortsha>.apk` (`com.yee94.openchamber.debug`). Latest sideload prerelease: [`flutter-v2-debug-5b8c479`](https://github.com/yee94/openchambery/releases/tag/flutter-v2-debug-5b8c479) (official launcher icon).
- Signed release (`workflow_dispatch`, existing Capacitor secrets): `.github/workflows/flutter-mobile-release.yml`
- No `integration_test` / `flutter drive` CI job. Linux has no phone GPU; macos-15 only compiles the simulator app. Local Timeline (not claimed 真机过):

```bash
cd apps/mobile_flutter
flutter test test/chat_transcript_perf_test.dart
flutter run --profile -d <device-or-sim>
# DevTools → Performance → record fling + text-only stream + reasoning toggle
```
