# Flutter native screenshots (Yee visual review)

Real `apps/mobile_flutter` widgets, captured with `WidgetTester` + `RenderRepaintBoundary.toImage` (not GenerateImage, not mocks).

- Device: **390×844** logical pixels, `devicePixelRatio` **3** (PNG 1170×2532)
- Locale: **zh-CN** (`MemorySecureStore` `openchamber.locale=zh-CN`)
- Data: `MemoryOpenChamberTransport` seed (sessions, assistants, scheduled, chat + diff + permission)
- Regenerator: `apps/mobile_flutter/test/flutter_native_screenshots_test.dart`

No PIN / Face ID lock. No `iosNativeUi`. Chat is a **pushed** page, not a dock tab.

| File | Screen |
|---|---|
| `01-connect.png` | Connection onboarding: server URL, QR scan + hint, client-token / password helper. Not a local lock. |
| `02-projects.png` | Projects tab: session rows with `项目 · 分支` subtitles, unread dot, plus menu open. |
| `03-assistant.png` | Assistant tab: snapshot rows (enabled toggle + named assistants). |
| `04-scheduled.png` | Scheduled tab: status + next-run subtitle, not name-only. |
| `05-settings.png` | Settings home: grouped list + search field. |
| `06-settings-appearance.png` | Appearance: language + theme. No `iosNativeUi`. |
| `07-chat.png` | Pushed Chat: reverse list, composer, expanded Activity with a diff card. |
| `08-permission.png` | Same Chat: permission card with 允许一次 / 始终同意 / 拒绝. |
