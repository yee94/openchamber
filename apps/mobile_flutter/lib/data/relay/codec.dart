import 'dart:convert';
import 'dart:typed_data';

import 'protocol.dart';

class TunnelCodecError implements Exception {
  TunnelCodecError(this.message);
  final String message;
  @override
  String toString() => 'TunnelCodecError($message)';
}

class TunnelFrame {
  const TunnelFrame({
    required this.frameType,
    required this.streamId,
    required this.payload,
    this.hasMoreFragments = false,
  });

  final int frameType;
  final int streamId;
  final Uint8List payload;
  final bool hasMoreFragments;
}

Uint8List encodeTunnelFrame(int frameType, int streamId, Uint8List payload, {bool hasMoreFragments = false}) {
  if (streamId < 0 || streamId > 0xffffffff) {
    throw TunnelCodecError('invalid stream id');
  }
  if (payload.length > maxTunnelPayloadBytes) {
    throw TunnelCodecError('tunnel payload exceeds maximum size');
  }
  final frame = Uint8List(tunnelFrameHeaderBytes + payload.length);
  frame[0] = hasMoreFragments ? frameType | tunnelFragmentFlag : frameType;
  frame[1] = (streamId >> 24) & 0xff;
  frame[2] = (streamId >> 16) & 0xff;
  frame[3] = (streamId >> 8) & 0xff;
  frame[4] = streamId & 0xff;
  frame.setAll(tunnelFrameHeaderBytes, payload);
  return frame;
}

TunnelFrame decodeTunnelFrame(Uint8List frame) {
  if (frame.length < tunnelFrameHeaderBytes) {
    throw TunnelCodecError('tunnel frame too short');
  }
  final rawType = frame[0];
  final hasMoreFragments = (rawType & tunnelFragmentFlag) != 0;
  final frameType = rawType & ~tunnelFragmentFlag;
  if (!TunnelFrameType.isKnown(frameType)) {
    throw TunnelCodecError('unknown tunnel frame type $frameType');
  }
  final streamId = ((frame[1] << 24) | (frame[2] << 16) | (frame[3] << 8) | frame[4]) & 0xffffffff;
  return TunnelFrame(
    frameType: frameType,
    streamId: streamId,
    payload: frame.sublist(tunnelFrameHeaderBytes),
    hasMoreFragments: hasMoreFragments,
  );
}

Uint8List encodeJsonPayload(Object? value) => Uint8List.fromList(utf8.encode(jsonEncode(value)));

Object? decodeJsonPayload(Uint8List payload) {
  try {
    return jsonDecode(utf8.decode(payload));
  } catch (_) {
    throw TunnelCodecError('malformed JSON tunnel payload');
  }
}

List<Uint8List> chunkPayload(Uint8List bytes, {int chunkSize = maxTunnelPayloadBytes}) {
  if (chunkSize <= 0 || chunkSize > maxTunnelPayloadBytes) {
    throw TunnelCodecError('invalid chunk size');
  }
  if (bytes.isEmpty) return [Uint8List(0)];
  final chunks = <Uint8List>[];
  for (var offset = 0; offset < bytes.length; offset += chunkSize) {
    final end = offset + chunkSize > bytes.length ? bytes.length : offset + chunkSize;
    chunks.add(bytes.sublist(offset, end));
  }
  return chunks;
}

Uint8List encodeFrameBatch(List<Uint8List> frames) {
  if (frames.isEmpty) throw TunnelCodecError('cannot encode an empty frame batch');
  if (frames.length == 1) {
    final frame = frames.first;
    final out = Uint8List(1 + frame.length);
    out[0] = batchContainerTagSingle;
    out.setAll(1, frame);
    if (out.length > maxPlaintextFrameBytes) {
      throw TunnelCodecError('frame batch exceeds maximum plaintext size');
    }
    return out;
  }
  var total = 1;
  for (final frame in frames) {
    total += batchFrameLengthBytes + frame.length;
  }
  if (total > maxPlaintextFrameBytes) {
    throw TunnelCodecError('frame batch exceeds maximum plaintext size');
  }
  final out = Uint8List(total);
  out[0] = batchContainerTagBatch;
  var offset = 1;
  for (final frame in frames) {
    out[offset] = (frame.length >> 24) & 0xff;
    out[offset + 1] = (frame.length >> 16) & 0xff;
    out[offset + 2] = (frame.length >> 8) & 0xff;
    out[offset + 3] = frame.length & 0xff;
    offset += batchFrameLengthBytes;
    out.setAll(offset, frame);
    offset += frame.length;
  }
  return out;
}

List<Uint8List> decodeFrameBatch(Uint8List plaintext) {
  if (plaintext.isEmpty) throw TunnelCodecError('empty batch plaintext');
  final tag = plaintext[0];
  if (tag == batchContainerTagSingle) return [plaintext.sublist(1)];
  if (tag != batchContainerTagBatch) {
    throw TunnelCodecError('unknown batch container tag $tag');
  }
  final frames = <Uint8List>[];
  var offset = 1;
  while (offset < plaintext.length) {
    if (offset + batchFrameLengthBytes > plaintext.length) {
      throw TunnelCodecError('truncated batch frame length');
    }
    final length =
        ((plaintext[offset] << 24) | (plaintext[offset + 1] << 16) | (plaintext[offset + 2] << 8) | plaintext[offset + 3]) &
            0xffffffff;
    offset += batchFrameLengthBytes;
    if (offset + length > plaintext.length) {
      throw TunnelCodecError('truncated batch frame body');
    }
    frames.add(plaintext.sublist(offset, offset + length));
    offset += length;
  }
  if (frames.isEmpty) throw TunnelCodecError('empty frame batch');
  return frames;
}

class StreamIdAllocator {
  int _next = 1;
  int next() {
    final id = _next;
    _next += 2;
    return id;
  }
}

/// Reassemble fragmented tunnel frames (`TUNNEL_FRAGMENT_FLAG`).
class FragmentAssembler {
  final _buffers = <int, BytesBuilder>{};

  TunnelFrame? push(TunnelFrame frame) {
    if (!frame.hasMoreFragments && !_buffers.containsKey(frame.streamId)) {
      return frame;
    }
    final buffer = _buffers.putIfAbsent(frame.streamId, BytesBuilder.new);
    buffer.add(frame.payload);
    if (frame.hasMoreFragments) return null;
    _buffers.remove(frame.streamId);
    return TunnelFrame(
      frameType: frame.frameType,
      streamId: frame.streamId,
      payload: Uint8List.fromList(buffer.takeBytes()),
    );
  }

  void drop(int streamId) => _buffers.remove(streamId);
}

String encodeTunnelQuery(Map<String, String> query) {
  if (query.isEmpty) return '';
  return query.entries
      .map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
      .join('&');
}

Uint8List encodeHttpRequestHead({
  required String method,
  required String path,
  required String query,
  required Map<String, String> headers,
}) {
  return encodeJsonPayload({
    'method': method,
    'path': path,
    'query': query,
    'headers': headers,
  });
}

Uint8List encodeHttpResponseHead(int status, Map<String, String> headers) {
  return encodeJsonPayload({'status': status, 'headers': headers});
}

({String method, String path, String query, Map<String, String> headers}) decodeHttpRequestHead(Uint8List payload) {
  final parsed = decodeJsonPayload(payload);
  if (parsed is! Map) throw TunnelCodecError('malformed HTTP request head');
  final record = parsed.map((key, value) => MapEntry(key.toString(), value));
  return (
    method: record['method']?.toString() ?? 'GET',
    path: record['path']?.toString() ?? '/',
    query: record['query']?.toString() ?? '',
    headers: _stringMap(record['headers']),
  );
}

({int status, Map<String, String> headers}) decodeHttpResponseHead(Uint8List payload) {
  final parsed = decodeJsonPayload(payload);
  if (parsed is! Map) throw TunnelCodecError('malformed HTTP response head');
  final record = parsed.map((key, value) => MapEntry(key.toString(), value));
  final status = record['status'];
  return (
    status: status is num ? status.toInt() : 502,
    headers: _stringMap(record['headers']),
  );
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item.toString()));
}
