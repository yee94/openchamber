/// Official composer STT: WebSocket `/api/dictation/ws` + 16 kHz PCM.
/// (`packages/ui/src/lib/dictation/dictation-client.ts`).
library;

import 'dart:async';
import 'dart:io';

import 'dictation_protocol.dart';
import 'openchamber_api.dart';
import 'openchamber_http.dart';
import 'pcm_capture.dart';
import 'relay/codec.dart';
import 'relay/tunnel_client.dart';

enum DictationStatus { idle, recording, uploading, failed }

class DictationResult {
  const DictationResult({required this.text});
  final String text;
}

abstract class DictationSession {
  DictationStatus get status;
  String get partialTranscript;
  Future<void> start();
  Future<DictationResult?> confirm();
  Future<void> cancel();
}

class UnavailableDictation implements DictationSession {
  DictationStatus _status = DictationStatus.idle;

  @override
  DictationStatus get status => _status;

  @override
  String get partialTranscript => '';

  @override
  Future<void> start() async {
    _status = DictationStatus.failed;
  }

  @override
  Future<DictationResult?> confirm() async {
    _status = DictationStatus.idle;
    return null;
  }

  @override
  Future<void> cancel() async {
    _status = DictationStatus.idle;
  }
}

class MemoryDictation implements DictationSession {
  MemoryDictation({this.transcript = 'hello from dictation'});

  final String transcript;
  DictationStatus _status = DictationStatus.idle;
  String _partial = '';

  @override
  DictationStatus get status => _status;

  @override
  String get partialTranscript => _partial;

  @override
  Future<void> start() async {
    _status = DictationStatus.recording;
    _partial = transcript;
  }

  @override
  Future<DictationResult?> confirm() async {
    if (_status == DictationStatus.idle) return null;
    _status = DictationStatus.idle;
    return DictationResult(text: _partial);
  }

  @override
  Future<void> cancel() async {
    _status = DictationStatus.idle;
    _partial = '';
  }
}

class TunnelDictationWire implements DictationWire {
  TunnelDictationWire(this.socket);
  final TunnelWebSocket socket;

  @override
  Stream<String> get messages => socket.messages;

  @override
  void send(String json) => socket.sendText(json);

  @override
  Future<void> close() => socket.close();
}

class IoDictationWire implements DictationWire {
  IoDictationWire(this._socket) {
    _sub = _socket.listen((data) {
      if (data is String) _incoming.add(data);
    });
  }

  final WebSocket _socket;
  // Non-broadcast so `ready` is buffered if it arrives before the client listens.
  final _incoming = StreamController<String>();
  StreamSubscription<dynamic>? _sub;

  static Future<IoDictationWire> connect(Uri url) async {
    final socket = await WebSocket.connect(url.toString());
    return IoDictationWire(socket);
  }

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String json) => _socket.add(json);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _socket.close();
    if (!_incoming.isClosed) await _incoming.close();
  }
}

/// Production composer dictation. Streams 16 kHz PCM over `/api/dictation/ws`.
/// Relay uses tunneled WebSockets + `oc_url_token`. Failure stays visible.
class OfficialDictation implements DictationSession {
  OfficialDictation({
    required this.resolveBase,
    required this.resolveBearer,
    required this.resolveTransport,
    required this.api,
    PcmCapture? capture,
    Future<DictationWire> Function(Uri httpBase, String? urlToken)? openWire,
  })  : _capture = capture ?? NativePcmCapture(),
        _openWire = openWire;

  final Uri? Function() resolveBase;
  final String? Function() resolveBearer;
  final OpenChamberTransport Function() resolveTransport;
  final OpenChamberApi api;
  final PcmCapture _capture;
  final Future<DictationWire> Function(Uri httpBase, String? urlToken)? _openWire;

  DictationStatus _status = DictationStatus.idle;
  String _partial = '';
  String? _dictationId;
  OfficialDictationClient? _client;
  StreamSubscription<String>? _chunks;
  final _segments = <String>[];

  @override
  DictationStatus get status => _status;

  @override
  String get partialTranscript {
    final id = _dictationId;
    if (id != null) {
      final live = _client?.partialFor(id);
      if (live != null && live.isNotEmpty) return live;
    }
    return _partial;
  }

  @override
  Future<void> start() async {
    await cancel();
    final base = resolveBase();
    if (base == null) {
      _status = DictationStatus.failed;
      return;
    }
    _status = DictationStatus.recording;
    _segments.clear();
    _dictationId = createDictationId();
    try {
      String? token;
      try {
        token = await api.mintUrlToken(base: base, bearer: resolveBearer());
      } on OpenChamberHttpException {
        token = null;
      }
      final wire = await (_openWire ?? _defaultOpenWire)(base, token);
      final client = OfficialDictationClient(wire);
      _client = client;
      await client.waitUntilReady();
      await client.startStream(dictationId: _dictationId!);
      _chunks = _capture.chunks.listen((audio) {
        final seq = _segments.length;
        _segments.add(audio);
        client.sendChunk(dictationId: _dictationId!, seq: seq, audio: audio);
      });
      await _capture.start();
    } catch (_) {
      _status = DictationStatus.failed;
      await _teardown();
    }
  }

  @override
  Future<DictationResult?> confirm() async {
    final client = _client;
    final id = _dictationId;
    if (client == null || id == null) {
      _status = DictationStatus.idle;
      return null;
    }
    _status = DictationStatus.uploading;
    try {
      await _capture.stop();
      await _chunks?.cancel();
      _chunks = null;
      final text = await client.finishStream(
        dictationId: id,
        finalSeq: _segments.isEmpty ? -1 : _segments.length - 1,
      );
      _partial = text;
      _status = DictationStatus.idle;
      await _teardown();
      return text.trim().isEmpty ? null : DictationResult(text: text);
    } catch (_) {
      _status = DictationStatus.failed;
      await _teardown();
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    final id = _dictationId;
    if (id != null) {
      try {
        _client?.cancelStream(id);
      } catch (_) {}
    }
    await _capture.stop();
    await _teardown();
    _status = DictationStatus.idle;
    _partial = '';
  }

  Future<void> _teardown() async {
    await _chunks?.cancel();
    _chunks = null;
    await _client?.close();
    _client = null;
    _dictationId = null;
    _segments.clear();
  }

  Future<DictationWire> _defaultOpenWire(Uri httpBase, String? urlToken) async {
    final transport = resolveTransport();
    if (transport is RelayTunnelTransport) {
      final query = <String, String>{
        if (urlToken != null && urlToken.isNotEmpty) 'oc_url_token': urlToken,
      };
      final socket = await transport.openWebSocket(
        path: OpenChamberPaths.dictationWs,
        query: encodeTunnelQuery(query),
      );
      return TunnelDictationWire(socket);
    }
    return IoDictationWire.connect(dictationWebSocketUri(httpBase, urlToken: urlToken));
  }
}
