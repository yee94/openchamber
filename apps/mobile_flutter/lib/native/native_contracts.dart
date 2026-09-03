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
    summary: 'Projects / Assistant / Scheduled / Settings. Chat is a pushed page. iOS Cupertino / Android Material 3.',
  ),
  NativeContract(
    id: 'settings-home',
    status: 'landed',
    summary: 'All MOBILE_SETTINGS_PAGE_SLUGS with search + drill-in. No iosNativeUi toggle.',
  ),
  NativeContract(
    id: 'qr-pairing',
    status: 'stub',
    summary: 'TODO: ML Kit barcode + Android Google scanner then CameraX; openchamber://connect?v=2&p=; persist relayUrl.',
  ),
  NativeContract(
    id: 'ios-composer',
    status: 'stub',
    summary: 'TODO: always-on UIKit liquid-glass composer (pill/card, IME, / @ autocomplete, attach, Send/Stop). Not optional.',
  ),
  NativeContract(
    id: 'android-composer',
    status: 'stub',
    summary: 'TODO: always-on Material composer + ImeSync analogue. No WebView composer path.',
  ),
  NativeContract(
    id: 'ios-liquid-glass-dock',
    status: 'stub',
    summary: 'TODO: iOS 26 UIGlassEffect UITabBar for the four homepage roots. Older iOS: system translucent Cupertino bar, not a fake glass clone.',
  ),
  NativeContract(
    id: 'live-activity',
    status: 'missing',
    summary: 'TODO: OpenChamberLiveActivity — one Activity for selected top-level session, 5s busy, Dynamic Island + Lock Screen.',
  ),
  NativeContract(
    id: 'share-in',
    status: 'missing',
    summary: 'TODO: iOS Share Extension + Android ShareReceiver / Direct Share. App Group group.com.yee94.openchamber.',
  ),
  NativeContract(
    id: 'push',
    status: 'missing',
    summary: 'TODO: APNs + FCM → openchamber-push-relay. Presence-aware skip. NSE mutable-content widget refresh.',
  ),
  NativeContract(
    id: 'widgetkit-nse-control',
    status: 'missing',
    summary: 'TODO: OpenChamberWidget, Control Center, OpenChamberNotificationService. Same App Group and bundle IDs as Capacitor.',
  ),
  NativeContract(
    id: 'haptics',
    status: 'missing',
    summary: 'TODO: light/medium/heavy impact (UIImpactFeedbackGenerator / performHapticFeedback).',
  ),
  NativeContract(
    id: 'native-back',
    status: 'missing',
    summary: 'TODO: iOS screen-edge pan + Android predictive back driving the pushed Chat / Settings stack.',
  ),
  NativeContract(
    id: 'secure-storage',
    status: 'stub',
    summary: 'In-memory SecureStore this slice. TODO: iOS Keychain + Android keystore-backed EncryptedSharedPreferences. Never log tokens.',
  ),
  NativeContract(
    id: 'ota-capgo',
    status: 'missing',
    summary: 'Do not port Capgo. Flutter ships full IPA/APK via signed-release. About still shows native vs instance versions.',
  ),
  NativeContract(
    id: 'virtual-assets-heic-picker',
    status: 'missing',
    summary: 'TODO: virtual image asset bridge, HEIC transcode, Android photo picker.',
  ),
];
