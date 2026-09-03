import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/pairing_payload.dart';
import 'platform_channels.dart';

class IncomingDeepLink {
  const IncomingDeepLink({required this.raw, this.kind = DeepLinkKind.unknown});

  final String raw;
  final DeepLinkKind kind;
}

enum DeepLinkKind { pairing, shareInbox, session, settings, unknown }

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
  return IncomingDeepLink(raw: trimmed);
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
