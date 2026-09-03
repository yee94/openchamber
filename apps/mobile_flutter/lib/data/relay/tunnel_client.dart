import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../openchamber_http.dart';
import '../pairing_payload.dart';
import 'codec.dart';
import 'handshake.dart';
import 'protocol.dart';

/// Injectable WebSocket-like wire. Tests use [MemoryTunnelWire];
/// production uses [IoWebSocketWire].
///
/// Matches `packages/ui/src/lib/relay/tunnel-client.ts` `TunnelWireSocket`.
abstract class TunnelWire {
  Stream<Object> get messages;
  void sendText(String text);
  void sendBinary(Uint8List data);
  Future<void> close([int? code, String? reason]);
}

class MemoryTunnelWire implements TunnelWire {
  MemoryTunnelWire();

  final _incoming = StreamController<Object>.broadcast();
  final _outgoing = StreamController<Object>.broadcast();
  bool closed = false;

  Stream<Object> get outgoing => _outgoing.stream;

  void deliver(Object data) {
    if (!closed) _incoming.add(data);
  }

  @override
  Stream<Object> get messages => _incoming.stream;

  @override
  void sendText(String text) {
    if (!closed) _outgoing.add(text);
  }

  @override
  void sendBinary(Uint8List data) {
    if (!closed) _outgoing.add(data);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    await _incoming.close();
    await _outgoing.close();
  }
}

class MemoryTunnelPair {
  MemoryTunnelPair() {
    client.outgoing.listen(host.deliver);
    host.outgoing.listen(client.deliver);
  }

  final client = MemoryTunnelWire();
  final host = MemoryTunnelWire();
}

class IoWebSocketWire implements TunnelWire {
  IoWebSocketWire(this._socket) {
    _sub = _socket.listen(
      (data) {
        if (data is String) {
          _incoming.add(data);
        } else if (data is List<int>) {
          _incoming.add(Uint8List.fromList(data));
        }
      },
      onDone: () {
        if (!_incoming.isClosed) _incoming.close();
      },
    );
  }

  final WebSocket _socket;
  final _incoming = StreamController<Object>.broadcast();
  StreamSubscription<dynamic>? _sub;

  static Future<IoWebSocketWire> connect(Uri url) async {
    final socket = await WebSocket.connect(url.toString());
    return IoWebSocketWire(socket);
  }

  @override
  Stream<Object> get messages => _incoming.stream;

  @override
  void sendText(String text) => _socket.add(text);

  @override
  void sendBinary(Uint8List data) => _socket.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    await _sub?.cancel();
    await _socket.close(code, reason);
    if (!_incoming.isClosed) await _incoming.close();
  }
}

/// Host-side HTTP mux used only in Flutter tests.
///
/// Mirrors the HTTP half of `packages/ui/src/lib/relay/tunnel-client.ts`
/// so Dart client ↔ Dart host can prove health/redeem without a live relay.
class MemoryRelayHost {
  MemoryRelayHost({
    required this.handshake,
    required this.wire,
    required this.handler,
  }) {
    _listen();
  }

  final HostHandshake handshake;
  final MemoryTunnelWire wire;
  final Future<OpenChamberResponse> Function(OpenChamberRequest request) handler;

  StreamSubscription<Object>? _sub;
  EstablishedChannel? _channel;
  final _assembler = FragmentAssembler();
  final _requests = <int, _HostHttp>{};
  String? lastWsQuery;
  final _wsPaths = <int, String>{};

  void _listen() {
    _sub = wire.messages.listen((raw) async {
      if (_channel == null) {
        if (raw is! String) return;
        final action = handshake.handleText(raw);
        if (action.kind == 'send-text' && action.replyText != null) {
          wire.sendText(action.replyText!);
          return;
        }
        if (action.kind == 'established' && action.channel != null) {
          _channel = action.channel;
          if (action.replyText != null) wire.sendText(action.replyText!);
        }
        return;
      }
      if (raw is! List<int>) return;
      final plaintext = _channel!.decryptor.decrypt(Uint8List.fromList(raw));
      final packed = _channel!.batch ? decodeFrameBatch(plaintext) : [plaintext];
      for (final encoded in packed) {
        final assembled = _assembler.push(decodeTunnelFrame(encoded));
        if (assembled == null) continue;
        if (assembled.frameType == TunnelFrameType.httpRequest) {
          _requests[assembled.streamId] = _HostHttp(assembled);
        } else if (assembled.frameType == TunnelFrameType.httpBody) {
          _requests[assembled.streamId]?.body.add(assembled.payload);
        } else if (assembled.frameType == TunnelFrameType.streamEnd) {
          final pending = _requests.remove(assembled.streamId);
          if (pending != null) unawaited(_handleRequest(pending));
        } else if (assembled.frameType == TunnelFrameType.wsOpen) {
          unawaited(_handleWsOpen(assembled));
        } else if (assembled.frameType == TunnelFrameType.wsText) {
          unawaited(_handleWsText(assembled));
        } else if (assembled.frameType == TunnelFrameType.wsClose) {
          _wsPaths.remove(assembled.streamId);
        }
      }
    });
  }

  Future<void> _handleWsOpen(TunnelFrame frame) async {
    final payload = decodeJsonPayload(frame.payload);
    final path = payload is Map ? payload['path']?.toString() ?? '' : '';
    lastWsQuery = payload is Map ? payload['query']?.toString() : null;
    _wsPaths[frame.streamId] = path;
    _sendFrame(encodeTunnelFrame(TunnelFrameType.wsOpened, frame.streamId, encodeJsonPayload({})));
    if (path == OpenChamberPaths.dictationWs) {
      _sendFrame(
        encodeTunnelFrame(
          TunnelFrameType.wsText,
          frame.streamId,
          Uint8List.fromList(utf8.encode(jsonEncode({'type': 'ready'}))),
        ),
      );
    }
  }

  Future<void> _handleWsText(TunnelFrame frame) async {
    final path = _wsPaths[frame.streamId];
    final text = utf8.decode(frame.payload);
    if (path != OpenChamberPaths.dictationWs) {
      _sendFrame(
        encodeTunnelFrame(
          TunnelFrameType.wsText,
          frame.streamId,
          Uint8List.fromList(utf8.encode('echo:$text')),
        ),
      );
      return;
    }
    Map<String, Object?> message;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;
      message = Map<String, Object?>.from(decoded);
    } catch (_) {
      return;
    }
    final type = message['type']?.toString();
    final id = message['dictationId']?.toString() ?? '';
    if (type == 'start') {
      _sendFrame(
        encodeTunnelFrame(
          TunnelFrameType.wsText,
          frame.streamId,
          Uint8List.fromList(utf8.encode(jsonEncode({'type': 'ack', 'dictationId': id}))),
        ),
      );
    } else if (type == 'finish') {
      _sendFrame(
        encodeTunnelFrame(
          TunnelFrameType.wsText,
          frame.streamId,
          Uint8List.fromList(utf8.encode(jsonEncode({
            'type': 'final',
            'dictationId': id,
            'text': 'tunneled transcript',
          }))),
        ),
      );
    }
  }

  Future<void> _handleRequest(_HostHttp pending) async {
    final requestFrame = pending.head;
    final head = decodeHttpRequestHead(requestFrame.payload);
    final query = <String, String>{};
    if (head.query.isNotEmpty) {
      query.addAll(Uri.splitQueryString(head.query));
    }
    final bearer = _bearerOf(head.headers);
    Map<String, Object?>? body;
    final rawBody = pending.body.takeBytes();
    if (rawBody.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(rawBody));
        if (decoded is Map) {
          body = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
    }
    late final OpenChamberResponse response;
    try {
      response = await handler(
        OpenChamberRequest(
          method: head.method,
          path: head.path,
          query: query,
          body: body,
          bearer: bearer,
          extraHeaders: head.headers,
        ),
      );
    } catch (error) {
      _sendFrame(
        encodeTunnelFrame(
          TunnelFrameType.streamAbort,
          requestFrame.streamId,
          encodeJsonPayload({'reason': '$error'}),
        ),
      );
      return;
    }
    _sendFrame(
      encodeTunnelFrame(
        TunnelFrameType.httpResponse,
        requestFrame.streamId,
        encodeHttpResponseHead(response.status, const {'content-type': 'application/json'}),
      ),
    );
    final bodyBytes = response.body == null ? Uint8List(0) : Uint8List.fromList(utf8.encode(jsonEncode(response.body)));
    if (bodyBytes.isNotEmpty) {
      for (final chunk in chunkPayload(bodyBytes)) {
        _sendFrame(encodeTunnelFrame(TunnelFrameType.httpBody, requestFrame.streamId, chunk));
      }
    }
    _sendFrame(encodeTunnelFrame(TunnelFrameType.streamEnd, requestFrame.streamId, Uint8List(0)));
  }

  void _sendFrame(Uint8List frame) {
    final channel = _channel;
    if (channel == null) return;
    final plaintext = channel.batch ? encodeFrameBatch([frame]) : frame;
    wire.sendBinary(channel.encryptor.encrypt(plaintext));
  }

  static String? _bearerOf(Map<String, String> headers) {
    final raw = headers['authorization'] ?? headers['Authorization'];
    if (raw == null) return null;
    const prefix = 'Bearer ';
    if (raw.startsWith(prefix)) return raw.substring(prefix.length);
    return raw;
  }

  Future<void> close() async {
    await _sub?.cancel();
    await wire.close();
  }
}

class _HostHttp {
  _HostHttp(this.head);
  final TunnelFrame head;
  final body = BytesBuilder(copy: false);
}

class _PendingHttp {
  _PendingHttp({required this.streaming, this.rawResponse = false});

  final bool streaming;
  final bool rawResponse;
  final completer = Completer<OpenChamberResponse>();
  final bodyController = StreamController<List<int>>.broadcast();
  int? status;
  Map<String, String> headers = const {};
  final body = BytesBuilder(copy: false);
}

class TunnelWebSocket {
  TunnelWebSocket(this._sendText, this._close);

  final void Function(String text) _sendText;
  final Future<void> Function() _close;
  // Non-broadcast so dictation `ready` is not dropped before OfficialDictationClient listens.
  final _incoming = StreamController<String>();
  final opened = Completer<void>();

  Stream<String> get messages => _incoming.stream;

  void deliverText(String text) {
    if (!_incoming.isClosed) _incoming.add(text);
  }

  void markOpened() {
    if (!opened.isCompleted) opened.complete();
  }

  void fail(Object error) {
    if (!opened.isCompleted) opened.completeError(error);
    if (!_incoming.isClosed) _incoming.addError(error);
  }

  void sendText(String text) => _sendText(text);

  Future<void> close() async {
    await _close();
    if (!_incoming.isClosed) await _incoming.close();
  }
}

/// Official relay HTTP mux client.
///
/// Layer 1 = [wire]. Layer 2 = [ClientHandshake]. Layer 3 = HTTP frames.
/// Implements [OpenChamberTransport] so the same API client talks LAN or tunnel.
/// Dummy parse base is `http://tunnel.invalid` (`tunnel-payloads.ts`).
class RelayTunnelTransport implements OpenChamberTransport {
  RelayTunnelTransport({
    required this.wire,
    required this.handshake,
    this.relayUrl,
    this.serverId,
  });

  final TunnelWire wire;
  final ClientHandshake handshake;
  final String? relayUrl;
  final String? serverId;

  StreamSubscription<Object>? _sub;
  EstablishedChannel? _channel;
  final _assembler = FragmentAssembler();
  final _streams = StreamIdAllocator();
  final _pending = <int, _PendingHttp>{};
  final _sockets = <int, TunnelWebSocket>{};
  Future<void> _sendLock = Future<void>.value();

  static final dummyBase = Uri.parse(tunnelParseBase);

  Future<void> establish({
    Duration helloRetry = const Duration(seconds: 1),
    Duration helloTimeout = const Duration(seconds: 12),
  }) async {
    final ready = Completer<void>();
    _sub = wire.messages.listen((raw) {
      if (_channel == null) {
        if (raw is! String) return;
        final action = handshake.handleText(raw);
        if (action.kind == 'established' && action.channel != null) {
          _channel = action.channel;
          if (!ready.isCompleted) ready.complete();
        } else if (action.kind == 'fail' && !ready.isCompleted) {
          ready.completeError(OpenChamberHttpException(0, 'relay-handshake', code: action.reason));
        }
        return;
      }
      if (raw is List<int>) _onCipher(Uint8List.fromList(raw));
    });
    wire.sendText(handshake.helloText);
    final retry = Timer.periodic(helloRetry, (_) {
      if (_channel == null) wire.sendText(handshake.helloText);
    });
    try {
      await ready.future.timeout(helloTimeout);
    } finally {
      retry.cancel();
    }
  }

  void _onCipher(Uint8List raw) {
    final channel = _channel;
    if (channel == null) return;
    final plaintext = channel.decryptor.decrypt(raw);
    final packed = channel.batch ? decodeFrameBatch(plaintext) : [plaintext];
    for (final encoded in packed) {
      final assembled = _assembler.push(decodeTunnelFrame(encoded));
      if (assembled == null) continue;
      if (assembled.frameType == TunnelFrameType.pong) continue;
      if (assembled.frameType == TunnelFrameType.ping) {
        unawaited(
          _sendPlain(
            encodeTunnelFrame(TunnelFrameType.pong, assembled.streamId, assembled.payload),
          ),
        );
        continue;
      }
      final pending = _pending[assembled.streamId];
      final socket = _sockets[assembled.streamId];
      if (socket != null) {
        _onWsFrame(socket, assembled);
        continue;
      }
      if (pending == null) continue;
      switch (assembled.frameType) {
        case TunnelFrameType.httpResponse:
          final head = decodeHttpResponseHead(assembled.payload);
          pending.status = head.status;
          pending.headers = head.headers;
          if (pending.streaming && !pending.completer.isCompleted) {
            pending.completer.complete(
              OpenChamberResponse(status: head.status, body: null),
            );
          }
        case TunnelFrameType.httpBody:
          if (pending.streaming) {
            if (!pending.bodyController.isClosed) {
              pending.bodyController.add(assembled.payload);
            }
          } else {
            pending.body.add(assembled.payload);
          }
        case TunnelFrameType.streamEnd:
          _pending.remove(assembled.streamId);
          if (pending.streaming) {
            if (!pending.bodyController.isClosed) pending.bodyController.close();
            if (!pending.completer.isCompleted) {
              pending.completer.complete(
                OpenChamberResponse(status: pending.status ?? 502, body: null),
              );
            }
          } else if (!pending.completer.isCompleted) {
            pending.completer.complete(_bufferedResponse(pending));
          }
        case TunnelFrameType.streamAbort:
          _pending.remove(assembled.streamId);
          final reason = _abortReason(assembled.payload);
          if (!pending.completer.isCompleted) {
            pending.completer.completeError(
              OpenChamberHttpException(0, 'relay-stream', code: reason),
            );
          }
          if (pending.streaming && !pending.bodyController.isClosed) {
            pending.bodyController.addError(OpenChamberHttpException(0, 'relay-stream', code: reason));
            pending.bodyController.close();
          }
      }
    }
  }

  void _onWsFrame(TunnelWebSocket socket, TunnelFrame assembled) {
    switch (assembled.frameType) {
      case TunnelFrameType.wsOpened:
        socket.markOpened();
      case TunnelFrameType.wsText:
        socket.deliverText(utf8.decode(assembled.payload));
      case TunnelFrameType.wsClose:
      case TunnelFrameType.streamAbort:
        _sockets.remove(assembled.streamId);
        socket.fail(OpenChamberHttpException(0, 'relay-ws', code: _abortReason(assembled.payload)));
        unawaited(socket.close());
    }
  }

  OpenChamberResponse _bufferedResponse(_PendingHttp pending) {
    final bytes = pending.body.takeBytes();
    if (pending.rawResponse) {
      return OpenChamberResponse(status: pending.status ?? 502, body: bytes);
    }
    Object? decoded;
    if (bytes.isNotEmpty) {
      final raw = utf8.decode(bytes);
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = raw;
      }
    }
    return OpenChamberResponse(status: pending.status ?? 502, body: decoded);
  }

  static String _abortReason(Uint8List payload) {
    try {
      final parsed = decodeJsonPayload(payload);
      if (parsed is Map && parsed['reason'] != null) return parsed['reason'].toString();
    } catch (_) {}
    return utf8.decode(payload);
  }

  Future<void> _sendPlain(Uint8List frame) {
    final previous = _sendLock;
    final next = Completer<void>();
    _sendLock = next.future;
    return previous.then((_) {
      final channel = _channel;
      if (channel == null) {
        throw const OpenChamberHttpException(0, 'relay-tunnel', code: 'not_ready');
      }
      final plaintext = channel.batch ? encodeFrameBatch([frame]) : frame;
      wire.sendBinary(channel.encryptor.encrypt(plaintext));
    }).whenComplete(next.complete);
  }

  Map<String, String> _requestHeaders(OpenChamberRequest request) {
    return {
      'accept': request.extraHeaders['accept'] ?? (request.stream ? 'text/event-stream' : 'application/json'),
      if (request.bearer != null && request.bearer!.isNotEmpty) 'authorization': 'Bearer ${request.bearer}',
      if (request.body != null) 'content-type': 'application/json',
      ...request.extraHeaders,
    };
  }

  Future<_PendingHttp> _startHttp(OpenChamberRequest request, {required bool streaming}) async {
    if (_channel == null) {
      throw const OpenChamberHttpException(0, 'relay-tunnel', code: 'not_ready');
    }
    final streamId = _streams.next();
    final pending = _PendingHttp(streaming: streaming, rawResponse: request.rawResponse);
    _pending[streamId] = pending;
    await _sendPlain(
      encodeTunnelFrame(
        TunnelFrameType.httpRequest,
        streamId,
        encodeHttpRequestHead(
          method: request.method,
          path: request.path,
          query: encodeTunnelQuery(request.query),
          headers: _requestHeaders(request),
        ),
      ),
    );
    if (request.body != null) {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(request.body)));
      for (final chunk in chunkPayload(bytes)) {
        await _sendPlain(encodeTunnelFrame(TunnelFrameType.httpBody, streamId, chunk));
      }
    }
    await _sendPlain(encodeTunnelFrame(TunnelFrameType.streamEnd, streamId, Uint8List(0)));
    return pending;
  }

  @override
  Future<OpenChamberResponse> send(Uri base, OpenChamberRequest request) async {
    final pending = await _startHttp(request, streaming: false);
    return pending.completer.future.timeout(request.timeout);
  }

  @override
  Stream<List<int>> openByteStream(Uri base, OpenChamberRequest request) {
    final out = StreamController<List<int>>();
    unawaited(() async {
      try {
        if (_channel == null) {
          throw const OpenChamberHttpException(0, 'relay-tunnel', code: 'not_ready');
        }
        final streamId = _streams.next();
        final pending = _PendingHttp(streaming: true);
        _pending[streamId] = pending;
        final sub = pending.bodyController.stream.listen(out.add, onError: out.addError, onDone: out.close);
        out.onCancel = sub.cancel;
        await _sendPlain(
          encodeTunnelFrame(
            TunnelFrameType.httpRequest,
            streamId,
            encodeHttpRequestHead(
              method: request.method,
              path: request.path,
              query: encodeTunnelQuery(request.query),
              headers: _requestHeaders(request),
            ),
          ),
        );
        if (request.body != null) {
          final bytes = Uint8List.fromList(utf8.encode(jsonEncode(request.body)));
          for (final chunk in chunkPayload(bytes)) {
            await _sendPlain(encodeTunnelFrame(TunnelFrameType.httpBody, streamId, chunk));
          }
        }
        await _sendPlain(encodeTunnelFrame(TunnelFrameType.streamEnd, streamId, Uint8List(0)));
        final head = await pending.completer.future;
        if (head.status < 200 || head.status >= 300) {
          if (!out.isClosed) {
            out.addError(OpenChamberHttpException(head.status, request.path));
            await out.close();
          }
        }
      } catch (error, stack) {
        if (!out.isClosed) {
          out.addError(error, stack);
          await out.close();
        }
      }
    }());
    return out.stream;
  }

  Future<TunnelWebSocket> openWebSocket({required String path, String query = ''}) async {
    if (_channel == null) {
      throw const OpenChamberHttpException(0, 'relay-tunnel', code: 'not_ready');
    }
    final streamId = _streams.next();
    late final TunnelWebSocket socket;
    socket = TunnelWebSocket(
      (text) {
        unawaited(
          _sendPlain(
            encodeTunnelFrame(TunnelFrameType.wsText, streamId, Uint8List.fromList(utf8.encode(text))),
          ),
        );
      },
      () async {
        _sockets.remove(streamId);
        await _sendPlain(
          encodeTunnelFrame(
            TunnelFrameType.wsClose,
            streamId,
            encodeJsonPayload({'code': 1000, 'reason': 'client'}),
          ),
        );
      },
    );
    _sockets[streamId] = socket;
    await _sendPlain(
      encodeTunnelFrame(
        TunnelFrameType.wsOpen,
        streamId,
        encodeJsonPayload({
          'path': path,
          'query': query,
        }),
      ),
    );
    await socket.opened.future.timeout(const Duration(seconds: 10));
    return socket;
  }

  @override
  Future<void> close() async {
    for (final socket in _sockets.values) {
      socket.fail(const OpenChamberHttpException(0, 'relay-tunnel', code: 'closed'));
    }
    _sockets.clear();
    for (final pending in _pending.values) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(const OpenChamberHttpException(0, 'relay-tunnel', code: 'closed'));
      }
      if (!pending.bodyController.isClosed) {
        pending.bodyController.addError(const OpenChamberHttpException(0, 'relay-tunnel', code: 'closed'));
        await pending.bodyController.close();
      }
    }
    _pending.clear();
    await _sub?.cancel();
    await wire.close();
  }
}

/// Layer-1 WebSocket URL from `buildRelayWsUrl` in tunnel-client.ts.
Uri buildRelayWsUrl({
  required String relayUrl,
  required String serverId,
  String? grant,
}) {
  final uri = Uri.parse(relayUrl.trim());
  if (uri.scheme != 'ws' && uri.scheme != 'wss') {
    throw FormatException('Relay URL must be ws/wss, got ${uri.scheme}');
  }
  return uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      'v': '$relayProtocolVersion',
      'role': 'client',
      'serverId': serverId,
      if (grant != null && grant.isNotEmpty) 'grant': grant,
    },
  );
}

Future<RelayTunnelTransport> openRelayTunnel(PairingRelayCandidate relay) async {
  final uri = buildRelayWsUrl(relayUrl: relay.relayUrl, serverId: relay.serverId, grant: relay.grant);
  final wire = await IoWebSocketWire.connect(uri);
  final transport = RelayTunnelTransport(
    wire: wire,
    handshake: ClientHandshake.create(relay.hostEncPubJwk),
    relayUrl: relay.relayUrl,
    serverId: relay.serverId,
  );
  await transport.establish();
  return transport;
}
