import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_channels.dart';

/// Official Capacitor `OpenChamberExternalBrowser.open({ url })`.
/// Only http(s) URLs. Never logs the URL query (may contain OAuth codes).
class ExternalBrowser {
  ExternalBrowser({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(OpenChamberChannels.externalBrowser);

  final MethodChannel _channel;

  Future<void> open(String url) async {
    final trimmed = url.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null ||
        parsed.host.isEmpty ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      throw ExternalBrowserException('invalid_url');
    }
    if (BindingBase.debugBindingType() == null) {
      throw ExternalBrowserException('unavailable');
    }
    try {
      await _channel.invokeMethod<void>('open', {'url': trimmed});
    } on MissingPluginException {
      throw ExternalBrowserException('unavailable');
    } on PlatformException catch (error) {
      throw ExternalBrowserException(error.code);
    }
  }
}

class ExternalBrowserException implements Exception {
  const ExternalBrowserException(this.code);
  final String code;
}

class MemoryExternalBrowser extends ExternalBrowser {
  MemoryExternalBrowser() : super(channel: const MethodChannel('openchamber/external_browser/memory'));

  final List<String> opened = [];

  @override
  Future<void> open(String url) async {
    final trimmed = url.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null ||
        parsed.host.isEmpty ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      throw const ExternalBrowserException('invalid_url');
    }
    opened.add(trimmed);
  }
}
