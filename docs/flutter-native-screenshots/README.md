# Flutter native screenshots (Yee visual review)

Real `apps/mobile_flutter` widgets, captured with `WidgetTester` + `RenderRepaintBoundary.toImage`.

- Device: **390×844** logical pixels, `devicePixelRatio` **3** (PNG 1170×2532)
- Locale: **zh-CN**
- Regenerator: `apps/mobile_flutter/test/flutter_native_screenshots_test.dart`
- Fonts: `test/review_fonts.dart` loads Roboto + DroidSansFallback so Latin digits and Chinese copy render. **Chrome icons are painted `OcGlyph` paths** — do not accept empty-square CupertinoIcons tofu.
- WidgetTester runs as Android. It **cannot** paint `UIGlassEffect`. Real iOS uses `UITabBarController` + `UITextView` overlays. This Linux VM cannot run an iOS Simulator.

No PIN / Face ID. No `iosNativeUi`. Chat is a pushed page.

| File | Screen |
|---|---|
| `01-connect.png` | QR primary, inset grouped fields (no floating-label overlap). |
| `02-projects.png` | Light: catalog sand/orange. Open title tracking, airy session/meta leading, small search/`+`/dock glyphs. Nested worktrees, 「更多」. |
| `02-projects-dark.png` | Same Projects surface after Appearance → Dark (hero dark overlay). |
| `03-assistant.png` | Contact cards (name / mode / summary). No 「启用助理」 toggle. |
| `04-scheduled.png` | Light: catalog tokens. Airy title/meta, small status glyphs, small ink `+`. Dock 计划 only. |
| `04-scheduled-dark.png` | Same Scheduled surface after Appearance → Dark. |
| `05-settings.png` | Large title, pill search, inset groups. |
| `06-settings-appearance.png` | Light: language + theme. Latin labels must render. No `iosNativeUi`. |
| `06-settings-appearance-dark.png` | Appearance after tapping Dark — tokens switch live. |
| `07-chat.png` | Isolated pushed Chat (light): no subtitle. Airy body leading. Small header/file/composer glyphs. Ring send. Not UIKit glass. |
| `07-chat-dark.png` | Same isolated Chat with `ThemeMode.dark`. |
| `08-permission.png` | Permission card only. |
