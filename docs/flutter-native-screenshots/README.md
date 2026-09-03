# Flutter native screenshots (Yee visual review)

Real `apps/mobile_flutter` widgets, captured with `WidgetTester` + `RenderRepaintBoundary.toImage`.

- Device: **390×844** logical pixels, `devicePixelRatio` **3** (PNG 1170×2532)
- Locale: **zh-CN**
- Regenerator: `apps/mobile_flutter/test/flutter_native_screenshots_test.dart`
- Fonts: `test/review_fonts.dart` loads Roboto + DroidSansFallback so Latin digits and Chinese copy render. **Chrome icons are painted `OcGlyph` paths** — do not accept empty-square CupertinoIcons tofu.
- WidgetTester runs as Android. Header / dock / composer use `BackdropFilter` + official `--oc-mobile-glass-fill` (0.68). That is **not** a `UIGlassEffect` clone. Real iOS still keeps live glass on UIKit overlays. Mid-scroll proof: `02-projects-scrolled.png`. This Linux VM cannot run an iOS Simulator.

No PIN / Face ID. No `iosNativeUi`. Chat is a pushed page.

Recapture after restoring Yee-open type (tracking + line-height) on top of the small-glyph / soft-shadow chrome. Catalog orange/sand stays — these PNGs are **not** a README photo recolor.

| File | Screen |
|---|---|
| `01-connect.png` | QR primary, inset grouped fields (no floating-label overlap). |
| `02-projects.png` | Light: catalog sand/orange. Overlay collapsing header. Official 40px search/`+`. Medium filled dock glyphs. Floating 68px frosted dock pill. |
| `02-projects-scrolled.png` | Same Projects list jumped to mid-scroll so session rows peek through the frosted header **and** dock. |
| `02-projects-dark.png` | Same Projects surface after Appearance → Dark (catalog `OcTokens`, not a photo recolor). |
| `03-assistant.png` | Contact cards (name / mode / summary). No 「启用助理」 toggle. |
| `04-scheduled.png` | Light: catalog tokens. Equal-width 全部/已启用/已暂停. 44px white status badge. Dock 计划 only. |
| `04-scheduled-dark.png` | Same Scheduled surface after Appearance → Dark. |
| `05-settings.png` | Large title, pill search, inset groups. |
| `06-settings-appearance.png` | Light: language + theme. Latin labels must render. No `iosNativeUi`. |
| `06-settings-appearance-dark.png` | Appearance after tapping Dark — tokens switch live. |
| `07-chat.png` | Isolated pushed Chat (light): 44px glass chips, left semibold title, filled stop disc, frosted composer over the transcript. Not UIKit glass. |
| `07-chat-dark.png` | Same isolated Chat with `ThemeMode.dark`. |
| `08-permission.png` | Permission card only. |
