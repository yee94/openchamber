/// Official composer STT protocol from
/// `packages/ui/src/lib/dictation/dictation-client.ts` and
/// `dictation-stream-sender.ts`. Do not invent a transcribe HTTP API.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

const pcmDictationFormat = 'audio/pcm;rate=16000;bits=16';
const dictationConnectTimeout = Duration(seconds: 10);
const dictationStartTimeout = Duration(seconds: 15);
const dictationFinishTimeout = Duration(seconds: 30);

abstract class DictationWire {
  Stream<String> get messages;
  void send(String json);
  Future<void> close();
}

class MemoryDictationWire implements DictationWire {
  MemoryDictationWire();

  // Non-broadcast so `ready` is buffered if tests deliver it before the client listens.
  final _incoming = StreamController<String>();
  final sent = <Map<String, Object?>>[];
  bool closed = false;

  void deliver(Map<String, Object?> message) {
    if (!closed) _incoming.add(jsonEncode(message));
  }

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String json) {
    if (closed) return;
    final decoded = jsonDecode(json);
    if (decoded is Map) {
      sent.add(Map<String, Object?>.from(decoded));
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    await _incoming.close();
  }
}

class OfficialDictationClient {
  OfficialDictationClient(this.wire) {
    _sub = wire.messages.listen(_onMessage);
  }

  final DictationWire wire;
  StreamSubscription<String>? _sub;
  final _ready = Completer<void>();
  final _starts = <String, Completer<void>>{};
  final _finishes = <String, Completer<String>>{};
  final _partials = <String, String>{};

  Future<void> waitUntilReady({Duration timeout = dictationConnectTimeout}) {
    return _ready.future.timeout(timeout);
  }

  String? partialFor(String dictationId) => _partials[dictationId];

  Future<void> startStream({
    required String dictationId,
    String format = pcmDictationFormat,
    Map<String, Object?> options = const {},
  }) {
    final pending = Completer<void>();
    _starts[dictationId] = pending;
    _send({
      'type': 'start',
      'dictationId': dictationId,
      'format': format,
      'options': options,
    });
    return pending.future.timeout(dictationStartTimeout);
  }

  void sendChunk({required String dictationId, required int seq, required String audio}) {
    _send({'type': 'chunk', 'dictationId': dictationId, 'seq': seq, 'audio': audio});
  }

  Future<String> finishStream({required String dictationId, required int finalSeq}) {
    final pending = Completer<String>();
    _finishes[dictationId] = pending;
    _send({'type': 'finish', 'dictationId': dictationId, 'finalSeq': finalSeq});
    return pending.future.timeout(dictationFinishTimeout);
  }

  void cancelStream(String dictationId) {
    _send({'type': 'cancel', 'dictationId': dictationId});
    _starts.remove(dictationId)?.completeError(StateError('Dictation cancelled'));
    _finishes.remove(dictationId)?.completeError(StateError('Dictation cancelled'));
  }

  Future<void> close() async {
    await _sub?.cancel();
    await wire.close();
  }

  void _send(Map<String, Object?> message) {
    wire.send(jsonEncode(message));
  }

  void _onMessage(String raw) {
    Map<String, Object?> message;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      message = Map<String, Object?>.from(decoded);
    } catch (_) {
      return;
    }
    final type = message['type']?.toString();
    if (type == 'ready' && !_ready.isCompleted) {
      _ready.complete();
      return;
    }
    final id = message['dictationId']?.toString();
    if (id == null || id.isEmpty) return;
    switch (type) {
      case 'ack':
        _starts.remove(id)?.complete();
      case 'partial':
        _partials[id] = message['text']?.toString() ?? '';
      case 'finish_accepted':
        break;
      case 'final':
        _finishes.remove(id)?.complete(message['text']?.toString() ?? '');
      case 'error':
        final error = StateError(message['error']?.toString() ?? 'Dictation failed');
        _starts.remove(id)?.completeError(error);
        _finishes.remove(id)?.completeError(error);
    }
  }
}

String createDictationId([DateTime? now]) {
  final stamp = (now ?? DateTime.now()).millisecondsSinceEpoch.toRadixString(16);
  final rand = Random().nextInt(0x7fffffff).toRadixString(36);
  return 'dic_$stamp$rand';
}

Uri dictationWebSocketUri(Uri httpBase, {String? urlToken}) {
  final scheme = httpBase.scheme == 'https' ? 'wss' : 'ws';
  return httpBase.replace(
    scheme: scheme,
    path: '/api/dictation/ws',
    queryParameters: {
      ...httpBase.queryParameters,
      if (urlToken != null && urlToken.isNotEmpty) 'oc_url_token': urlToken,
    },
  );
}
