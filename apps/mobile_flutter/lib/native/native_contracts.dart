/// Native Flutter parity inventory. Native is the product — these are always
/// on, not gated by Appearance `openchamber.iosNativeUi` (that WebView-era
/// switch is deleted). Status values: missing | stub | landed.
class NativeContract {
  const NativeContract({
    required this.id,
    required this.status,
    required this.summary,
  });

  final String id;
  final String status;
  final String summary;
}

const List<NativeContract> flutterNativeContracts = [
  NativeContract(
    id: 'connection-onboarding',
    status: 'landed',
    summary: 'Server URL, password unlock, client token, saved connections, auto-connect, delete-active → connect.',
  ),
  NativeContract(
    id: 'four-tab-dock',
    status: 'landed',
    summary: 'Projects / Assistant / Scheduled / Settings. Chat is a pushed page. iOS UIKit UITabBar / Android Material 3.',
  ),
  NativeContract(
    id: 'settings-home',
    status: 'landed',
    summary: 'All MOBILE_SETTINGS_PAGE_SLUGS with search + drill-in. No iosNativeUi toggle.',
  ),
  NativeContract(
    id: 'qr-pairing',
    status: 'landed',
    summary: 'Parse+persist v2 payload and relayUrl. iOS VisionKit DataScanner; Android Google Code Scanner then CameraX+ML Kit. No fake redeem HTTP.',
  ),
  NativeContract(
    id: 'ios-composer',
    status: 'landed',
    summary: 'Always-on UIKit liquid-glass composer (pill/card, IME, / @ autocomplete stub, attach, Send/Stop, warm-on-home).',
  ),
  NativeContract(
    id: 'android-composer',
    status: 'landed',
    summary: 'Material composer + solid IME viewInsets. No WebView composer path.',
  ),
  NativeContract(
    id: 'ios-liquid-glass-dock',
    status: 'landed',
    summary: 'iOS 26 UIGlassEffect UITabBar for the four homepage roots. Older iOS: system translucent UITabBar, not a fake glass clone.',
  ),
  NativeContract(
    id: 'live-activity',
    status: 'landed',
    summary: 'iOS 17+ local Activity, 5s busy, no pushType, no rebuild after user dismiss. Android channel is a no-op.',
  ),
  NativeContract(
    id: 'share-in',
    status: 'landed',
    summary: 'iOS Share Extension + Android ShareReceiver / Direct Share. Exact instance+assistant only. App Group group.com.yee94.openchamber.',
  ),
  NativeContract(
    id: 'push',
    status: 'missing',
    summary: 'TODO: APNs + FCM → openchamber-push-relay. NSE target exists and refreshes the widget snapshot.',
  ),
  NativeContract(
    id: 'widgetkit-nse-control',
    status: 'landed',
    summary: 'OpenChamberWidget, Control Center, OpenChamberNotificationService targets in the Flutter Xcode project. Same App Group and bundle IDs as Capacitor.',
  ),
  NativeContract(
    id: 'haptics',
    status: 'missing',
    summary: 'light/medium/heavy impact (UIImpactFeedbackGenerator / performHapticFeedback). Always on.',
  ),
  NativeContract(
    id: 'native-back',
    status: 'missing',
    summary: 'TODO: iOS screen-edge pan + Android predictive back driving the pushed Chat / Settings stack.',
  ),
  NativeContract(
    id: 'secure-storage',
    status: 'landed',
    summary: 'iOS Keychain + Android Keystore AES-GCM. Tests still inject MemorySecureStore. Never log tokens.',
  ),
  NativeContract(
    id: 'ota-capgo',
    status: 'missing',
    summary: 'Do not port Capgo. Flutter ships full IPA/APK via signed-release. About still shows native vs instance versions.',
  ),
  NativeContract(
    id: 'virtual-assets-heic-picker',
    status: 'landed',
    summary: 'Android ACTION_PICK_IMAGES + iOS PHPicker, HEIC→JPEG transcode, virtual-asset create/append/finish. Composer uploads PUT /api/fs/prompt-attachments then file:// parts.',
  ),
  NativeContract(
    id: 'external-browser',
    status: 'landed',
    summary: 'OpenChamberExternalBrowser analogue: http(s) system browser via openchamber/external_browser. Provider/MCP OAuth uses official authorize + callback + mcp/auth/pending.',
  ),
  NativeContract(
    id: 'app-icon-badge',
    status: 'landed',
    summary: 'iOS applicationIconBadgeNumber from session-index attentionCount when writing the widget snapshot. Android stays unset: official Push Relay has no FCM send / aps.badge analogue.',
  ),
];
