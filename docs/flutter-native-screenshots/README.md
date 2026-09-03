# Flutter native screenshots (Yee visual review)

Real `apps/mobile_flutter` widgets, captured with `WidgetTester` + `RenderRepaintBoundary.toImage` (not GenerateImage, not mocks).

- Device: **390×844** logical pixels, `devicePixelRatio` **3** (PNG 1170×2532)
- Locale: **zh-CN** (`MemorySecureStore` `openchamber.locale=zh-CN`)
- Data: `MemoryOpenChamberTransport` seed (sessions, assistants, scheduled, chat + diff + permission)
- Regenerator: `apps/mobile_flutter/test/flutter_native_screenshots_test.dart`
- Chrome: official IA (large titles, inset grouped cards, circular header actions, floating capsule dock, pill composer). WidgetTester runs as Android, so the dock is the Flutter capsule (same four roots). Real iOS uses `UITabBarController` + `UITextView` overlays.

No PIN / Face ID lock. No `iosNativeUi`. Chat is a **pushed** page, not a dock tab.

| File | Screen |
|---|---|
| `01-connect.png` | Connection onboarding: QR primary, inset grouped fields (no floating-label overlap), saved list. |
| `02-projects.png` | Projects: large title 「项目」, circular search + filled +, grouped project cards with session count / relative time / nested rows. |
| `03-assistant.png` | Assistant tab: contact cards, dock highlight on 助理. |
| `04-scheduled.png` | Scheduled: 「计划」, 任务/历史记录 segments, 全部/已启用/已暂停 filters, status-glyph task cards. |
| `05-settings.png` | Settings: large title, pill search, inset grouped slugs. |
| `06-settings-appearance.png` | Appearance: language + theme. No `iosNativeUi`. |
| `07-chat.png` | Pushed Chat: back / truncated title / busy, assistant chrome + file-change card, floating pill composer. |
| `08-permission.png` | Permission card: 允许一次 / 始终同意 / 拒绝. |
