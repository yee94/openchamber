import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'deep_link.dart';
import 'live_activity_controller.dart';
import 'platform_channels.dart';

class PushDevice {
  const PushDevice({required this.token, required this.platform});

  final String token;
  final String platform;
}

/// Official `pushNotificationActionPerformed`: prefer `url` / `deeplink`,
/// else `data.sessionId` → `openchamber://session/{id}`.
String? sessionDeepLinkFromPushData(Map<String, Object?> data) {
  final url = data['url']?.toString().trim();
  if (url != null && url.isNotEmpty) {
    if (url.startsWith('openchamber://')) return url;
    final classified = classifyDeepLink(url);
    if (classified.kind != DeepLinkKind.unknown) return classified.raw;
  }
  final deeplink = data['deeplink']?.toString().trim();
  if (deeplink != null && deeplink.isNotEmpty) {
    if (deeplink.startsWith('openchamber://')) return deeplink;
    final classified = classifyDeepLink(deeplink);
    if (classified.kind != DeepLinkKind.unknown) return classified.raw;
  }
  final sessionId = data['sessionId']?.toString().trim() ?? data['sessionID']?.toString().trim();
  if (sessionId == null || sessionId.isEmpty || sessionId == liveActivityCatalogId) {
    return null;
  }
  return liveActivityRowUri(sessionId).toString();
}

String? sessionDeepLinkFromPushArguments(Object? arguments) {
  if (arguments is String && arguments.trim().isNotEmpty) {
    return sessionDeepLinkFromPushData({'url': arguments.trim()});
  }
  if (arguments is Map) {
    return sessionDeepLinkFromPushData(arguments.map((key, value) => MapEntry(key.toString(), value)));
  }
  return null;
}

class NativePush {
  NativePush({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(OpenChamberChannels.push);

  final MethodChannel _channel;

  void listenOpened(void Function(String uri) onUri) {
    if (BindingBase.debugBindingType() == null) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'opened') {
        final uri = sessionDeepLinkFromPushArguments(call.arguments);
        if (uri != null && uri.isNotEmpty) onUri(uri);
      }
      return null;
    });
  }

  Future<String?> takeInitialOpen() async {
    if (BindingBase.debugBindingType() == null) return null;
    try {
      final value = await _channel.invokeMethod<dynamic>('takeInitialOpen').timeout(const Duration(milliseconds: 80));
      return sessionDeepLinkFromPushArguments(value);
    } catch (_) {
      return null;
    }
  }

  Future<PushDevice?> requestToken() async {
    try {
      final value = await _channel.invokeMethod<dynamic>('requestToken');
      if (value is Map) {
        final token = value['token']?.toString() ?? '';
        final platform = value['platform']?.toString() ?? '';
        if (token.isEmpty) return null;
        return PushDevice(token: token, platform: platform.isEmpty ? 'ios' : platform);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
