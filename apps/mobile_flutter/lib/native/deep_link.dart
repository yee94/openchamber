import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/oauth.dart';
import '../data/pairing_payload.dart';
import 'live_activity_controller.dart';
import 'platform_channels.dart';

class IncomingDeepLink {
  const IncomingDeepLink({required this.raw, this.kind = DeepLinkKind.unknown});

  final String raw;
  final DeepLinkKind kind;
}

enum DeepLinkKind { pairing, shareInbox, session, settings, oauth, unknown }

IncomingDeepLink classifyDeepLink(String raw) {
  final trimmed = raw.trim();
  if (parsePairingConnectionPayload(trimmed) != null ||
      (trimmed.startsWith('openchamber://connect') && trimmed.contains('p='))) {
    return IncomingDeepLink(raw: trimmed, kind: DeepLinkKind.pairing);
  }
  if (trimmed.startsWith('openchamber://share-inbox')) {
    return IncomingDeepLink(raw: trimmed, kind: DeepLinkKind.shareInbox);
  }
  if (trimmed.startsWith('openchamber://session/')) {
    return IncomingDeepLink(raw: trimmed, kind: DeepLinkKind.session);
  }
  if (trimmed.startsWith('openchamber://settings') || trimmed.startsWith('openchamber://view/')) {
    return IncomingDeepLink(raw: trimmed, kind: DeepLinkKind.settings);
  }
  if (isOAuthCallbackLink(trimmed)) {
    return IncomingDeepLink(raw: trimmed, kind: DeepLinkKind.oauth);
  }
  return IncomingDeepLink(raw: trimmed);
}

/// Live Activity row / widget tap → that session. `live` is the catalog
/// activity id, not a real session.
String? parseSessionDeepLinkId(String raw) {
  final link = classifyDeepLink(raw);
  if (link.kind != DeepLinkKind.session) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  String? id;
  if (uri.host.toLowerCase() == 'session') {
    id = uri.pathSegments.isEmpty ? uri.queryParameters['id'] : uri.pathSegments.first;
  } else {
    final segments = [...uri.pathSegments];
    final sessionAt = segments.indexWhere((part) => part.toLowerCase() == 'session');
    if (sessionAt >= 0 && sessionAt + 1 < segments.length) {
      id = segments[sessionAt + 1];
    }
  }
  if (id == null || id.isEmpty) return null;
  final decoded = Uri.decodeComponent(id);
  if (decoded == liveActivityCatalogId) return null;
  return decoded;
}

class DeepLinkListener {
  DeepLinkListener({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(OpenChamberChannels.deepLink);

  final MethodChannel _channel;

  void listen(void Function(String uri) onUri) {
    if (BindingBase.debugBindingType() == null) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'opened') {
        final uri = call.arguments is String ? call.arguments as String : '';
        if (uri.isNotEmpty) onUri(uri);
      }
      return null;
    });
  }

  Future<String?> takeInitial() async {
    if (BindingBase.debugBindingType() == null) return null;
    try {
      return await _channel.invokeMethod<String>('takeInitial').timeout(const Duration(milliseconds: 80));
    } on MissingPluginException {
      return null;
    } on TimeoutException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
