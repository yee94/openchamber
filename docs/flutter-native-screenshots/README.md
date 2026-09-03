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
| `02-projects.png` | 「项目」, circular search + filled +, project/worktree cards, 「N 个会话」 · time · Code/github, nested sessions, 「更多」. Dock 项目 selected. |
| `03-assistant.png` | Contact cards (name / mode / summary). No 「启用助理」 toggle. |
| `04-scheduled.png` | 「计划」, segmented 任务/历史记录, chips 全部/已启用/已暂停 with selected fill, filled green check / soft-blue pause, 「每天 23:30 · 23h 30m 后」. Dock 计划 only. |
| `05-settings.png` | Large title, pill search, inset groups. |
| `06-settings-appearance.png` | Language + theme. Latin labels must render. No `iosNativeUi`. |
| `07-chat.png` | Isolated pushed Chat: back, truncated title, busy spinner, overflow, 「Grok 4.6」 + Orchestrator pill, purple agent-count, file card, copy/share/feedback + tok/s, scroll-to-bottom FAB, solid Flutter pill (not UIKit glass). |
| `08-permission.png` | Permission card only. |
