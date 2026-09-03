import 'dart:convert';

import 'package:flutter/services.dart';

import 'platform_channels.dart';

class TtsPlayback {
  TtsPlayback({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(OpenChamberChannels.tts);

  final MethodChannel _channel;

  Future<void> play(List<int> bytes) {
    return _channel.invokeMethod<void>('play', {'audio': base64Encode(bytes)});
  }

  Future<void> stop() {
    return _channel.invokeMethod<void>('stop');
  }
}
