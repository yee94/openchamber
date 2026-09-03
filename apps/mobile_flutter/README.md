# OpenChamber Flutter mobile

Independent **native-first** Flutter rewrite of OpenChamber mobile.

- Track: `work/flutter-native` (do **not** merge to `main`)
- Product baseline: `main` @ `3a164b6` / `1.19.3-beta.5`
- Capacitor shell (`packages/mobile`) stays on this branch; this app sits beside it
- Chat list analogue: reverse `ListView` (LegendList behavior). No TanStack Virtual / StickToBottom / Virtua
- Native is the product: no Appearance `openchamber.iosNativeUi` toggle, no WebView fallback
- Capgo OTA is **not** ported. Ship full IPA/APK via `.github/workflows/flutter-mobile-release.yml`

App id: `com.yee94.openchamber`. App name: **OpenChamber**.

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

## Surfaces

1. Splash → live HTTP onboarding (`GET /health`, `GET/POST /auth/session`, pairing redeem on LAN or the official E2EE relay tunnel). **No local PIN / Face ID lock.**
2. Four-tab dock: Projects / Assistant / Scheduled / Settings. iOS uses a UIKit `UITabBar` (liquid glass on iOS 26).
3. Chat is pushed from the live session index (pinned/in-progress `项目 · 分支` subtitles). Send/Stop hit `prompt_async` / `abort`. Plus-menu creates `POST /api/session`. Live events are `GET /api/global/event` SSE.
4. Always-on native composer (UIKit glass on iOS, Material + solid IME insets on Android)
5. Settings home: search + every `MOBILE_SETTINGS_PAGE_SLUGS` page
6. iOS targets: Runner, WidgetKit+Live Activity+Control, NSE, Share Extension (same bundle IDs / App Group as Capacitor)

## CI

- Smoke (push to `work/flutter-native` only): `.github/workflows/flutter-mobile-ci.yml`
- Signed release (`workflow_dispatch`, existing Capacitor secrets): `.github/workflows/flutter-mobile-release.yml`
