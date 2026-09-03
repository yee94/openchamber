import 'package:flutter/services.dart';

import 'platform_channels.dart';

enum HapticStrength { light, medium, heavy }

class NativeHaptics {
  NativeHaptics({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(OpenChamberChannels.haptics);

  final MethodChannel _channel;

  Future<void> impact(HapticStrength strength) async {
    try {
      await _channel.invokeMethod<void>('impact', {'strength': strength.name});
    } catch (_) {
      // Haptics are best-effort.
    }
  }
}
