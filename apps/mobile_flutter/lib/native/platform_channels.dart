/// Method-channel names owned by the Flutter host. Native plugins register
/// the same strings. Never put secrets in channel arguments that get logged.
abstract final class OpenChamberChannels {
  static const secureStore = 'openchamber/secure_store';
  static const qrScanner = 'openchamber/qr_scanner';
  static const liveActivity = 'openchamber/live_activity';
  static const share = 'openchamber/share';
  static const deepLink = 'openchamber/deep_link';
  static const composer = 'openchamber/composer';
  static const tabBar = 'openchamber/tab_bar';
}

abstract final class OpenChamberPlatformViews {
  static const composer = 'openchamber/composer_view';
  static const tabBar = 'openchamber/tab_bar_view';
}
