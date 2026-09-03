import 'package:flutter/services.dart';

import 'platform_channels.dart';

/// Native QR scan. iOS uses Vision; Android tries Google Code Scanner,
/// then CameraX + ML Kit. Returns the raw payload string or null.
class QrScanner {
  QrScanner({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(OpenChamberChannels.qrScanner);

  final MethodChannel _channel;

  Future<String?> scan() async {
    final value = await _channel.invokeMethod<String>('scan');
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
