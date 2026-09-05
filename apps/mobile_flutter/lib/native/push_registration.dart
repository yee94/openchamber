import 'package:flutter/services.dart';

import 'platform_channels.dart';

class PushDevice {
  const PushDevice({required this.token, required this.platform});

  final String token;
  final String platform;
}

class NativePush {
  NativePush({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(OpenChamberChannels.push);

  final MethodChannel _channel;

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
