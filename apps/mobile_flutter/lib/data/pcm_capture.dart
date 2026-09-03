/// 16 kHz PCM16LE capture for official dictation chunks.
/// Native path matches `use-dictation-audio-source.ts` (~1s base64 segments).
library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../native/platform_channels.dart';

abstract class PcmCapture {
  Stream<String> get chunks;
  Future<void> start();
  Future<void> stop();
}

class MemoryPcmCapture implements PcmCapture {
  MemoryPcmCapture({this.segments = const ['AAAA']});

  final List<String> segments;
  final _chunks = StreamController<String>.broadcast();
  var started = false;

  @override
  Stream<String> get chunks => _chunks.stream;

  @override
  Future<void> start() async {
    started = true;
    for (final segment in segments) {
      _chunks.add(segment);
    }
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  Future<void> close() => _chunks.close();
}

class NativePcmCapture implements PcmCapture {
  NativePcmCapture({
    MethodChannel? methods,
    EventChannel? events,
  })  : _methods = methods ?? const MethodChannel(OpenChamberChannels.dictation),
        _events = events ?? const EventChannel(OpenChamberChannels.dictationPcm);

  final MethodChannel _methods;
  final EventChannel _events;
  StreamSubscription<dynamic>? _sub;
  final _chunks = StreamController<String>.broadcast();

  @override
  Stream<String> get chunks => _chunks.stream;

  @override
  Future<void> start() async {
    _sub ??= _events.receiveBroadcastStream().listen((event) {
      if (event is Map && event['audio'] is String) {
        final audio = (event['audio'] as String).trim();
        if (audio.isNotEmpty) _chunks.add(audio);
      }
    });
    await _methods.invokeMethod<void>('start');
  }

  @override
  Future<void> stop() async {
    try {
      await _methods.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Linux widget tests / missing native plugin stay visible as capture failure.
    }
    await _sub?.cancel();
    _sub = null;
  }
}
