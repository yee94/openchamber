import 'dart:convert';

/// Minimal SSE parser for `GET /api/global/event`.
/// Same wire as `sdk.global.event` / `packages/ui/src/sync/event-pipeline.ts`.
class SseEvent {
  const SseEvent({this.id, this.event, required this.data});

  final String? id;
  final String? event;
  final String data;
}

Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  final buffer = StringBuffer();
  await for (final chunk in bytes) {
    buffer.write(String.fromCharCodes(chunk));
    final raw = buffer.toString();
    final parts = raw.split('\n\n');
    buffer
      ..clear()
      ..write(parts.last);
    for (var i = 0; i < parts.length - 1; i++) {
      final parsed = parseSseBlock(parts[i]);
      if (parsed != null) yield parsed;
    }
  }
  final trailing = parseSseBlock(buffer.toString());
  if (trailing != null) yield trailing;
}

SseEvent? parseSseBlock(String block) {
  if (block.trim().isEmpty) return null;
  String? id;
  String? event;
  final data = <String>[];
  for (final line in block.split('\n')) {
    final trimmed = line.replaceAll('\r', '');
    if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
    final colon = trimmed.indexOf(':');
    final field = colon == -1 ? trimmed : trimmed.substring(0, colon);
    var value = colon == -1 ? '' : trimmed.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'id':
        id = value;
      case 'event':
        event = value;
      case 'data':
        data.add(value);
    }
  }
  if (data.isEmpty && id == null && event == null) return null;
  return SseEvent(id: id, event: event, data: data.join('\n'));
}

Object? decodeSseJson(String data) {
  if (data.isEmpty) return null;
  try {
    return jsonDecode(data);
  } catch (_) {
    return data;
  }
}

String? eventTypeOf(Object? payload) {
  if (payload is Map && payload['type'] != null) return payload['type'].toString();
  return null;
}
