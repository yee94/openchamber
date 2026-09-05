import 'package:flutter/services.dart';

import 'platform_channels.dart';

enum HapticStrength { light, medium, heavy }

class NativeHaptics {
  NativeHaptics({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(OpenChamberChannels.haptics);

  /// Shared fire-and-forget client. Tests inject [channel] on a new instance.
  static final NativeHaptics instance = NativeHaptics();

  final MethodChannel _channel;

  Future<void> impact(HapticStrength strength) async {
    try {
      await _channel.invokeMethod<void>('impact', {'strength': strength.name});
    } catch (_) {
      // Haptics are best-effort.
    }
  }
}
