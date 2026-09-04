# Flutter native screenshots (Yee visual review)

Real `apps/mobile_flutter` widgets, captured with `WidgetTester` + `RenderRepaintBoundary.toImage`.

- Device: **390×844** logical pixels, `devicePixelRatio` **3** (PNG 1170×2532)
- Locale: **zh-CN**
- Regenerator: `apps/mobile_flutter/test/flutter_native_screenshots_test.dart`
- Fonts: `test/review_fonts.dart` loads Roboto + DroidSansFallback so Latin digits and Chinese copy render. **Chrome icons are painted `OcGlyph` paths** — do not accept empty-square CupertinoIcons tofu.
- WidgetTester runs as Android. Header / dock use `BackdropFilter` + official saturate. Search uses `OcGlassChip` mobileGlass frost (`glassChipFill` 0.34, σ14, official saturate, 32 plate — no 8/20 umbra, no 0.68/36 coin). Solid `+` is official 40 primary. Project and schedule shells keep official `--oc-mobile-float-shadow` (2 / 12 / 10-24/-6). Schedule status discs are 38 project-shell glass. Dock selected is mix-only `interactive-selection/55` (no hairline pill, no RGB@0.55, no nested frost). Session rows stay in the official ~40 class with a tiny CJK half-lead (0.5 → 42). Folder / sparkles stay official 23px at a lighter visual stroke; calendar/gear paint slimmer filled-medium. Composer is official `--surface-subtle` with no elevation / no frost; idle send is in-pill `send-plane` (no filled disc). These PNGs cannot prove live iOS glass or 精致. Real iOS still keeps live glass on UIKit overlays. Mid-scroll proof: `02-projects-scrolled.png`. This Linux VM cannot run an iOS Simulator. Goldens reserve `viewPadding.top = 47` for the status area; they do **not** paint a fake UIKit status bar.
- Projects golden expands linked worktree groups after connect so one project shell shows main sessions plus inset worktree groups (official model still starts worktrees collapsed). `.oc-mobile-project-groups` padding (2 / 12 / 14) sits between the project header and the session body.

No PIN / Face ID. No `iosNativeUi`. Chat is a pushed page.

No PIN / Face ID. No `iosNativeUi`. Chat is a pushed page.

Recapture after restoring Yee-open type (tracking + line-height) on top of the small-glyph / soft-shadow chrome. Catalog orange/sand stays — these PNGs are **not** a README photo recolor.

| File | Screen |
|---|---|
| `01-connect.png` | QR primary, inset grouped fields (no floating-label overlap). |
| `02-projects.png` | Light: catalog sand/orange. Overlay collapsing header. One project shell: header + padded session/worktree groups. |
| `02-projects-scrolled.png` | Same Projects list jumped just past the official 48px collapse. Title is compact; cards stay visible under the translucent header (not an emptied mid-scroll). |
| `02-projects-dark.png` | Same Projects surface after Appearance → Dark (catalog `OcTokens`, not a photo recolor). |
| `03-assistant.png` | Contact cards (name / mode / summary). No 「启用助理」 toggle. |
| `04-scheduled.png` | Light: catalog tokens. Quiet schedule status discs. Soft float cards. Dock 计划 uses the official calendar grid (filled plate + date holes, not calendar-clock). |
| `04-scheduled-dark.png` | Same Scheduled surface after Appearance → Dark. |
| `05-settings.png` | Large title, pill search, inset groups. |
| `06-settings-appearance.png` | Light: language + theme. Latin labels must render. No `iosNativeUi`. |
| `06-settings-appearance-dark.png` | Appearance after tapping Dark — tokens switch live. |
| `07-chat.png` | Isolated pushed Chat (light): 40px glass chips, centered title, official attach `size-5`, last-turn footer meta (copy / fork / tok/s / duration / clock), one “已处理”, file `+N/-M`. Not UIKit glass. |
| `07-chat-dark.png` | Same isolated Chat with `ThemeMode.dark`. |
| `07-chat-activity.png` | Expanded 「已处理」 activity: gap under header, skill + terminal rows, foreground ink, OcGlyph folder/`>_`/chevron. |
| `08-permission.png` | Permission card only. |
