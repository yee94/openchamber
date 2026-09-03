/// Official live-event transport from `packages/ui/src/sync/event-pipeline.ts`.
/// Prefer `/api/global/event/ws`, fall back to SSE. Do not invent frames.
library;

import 'dart:convert';

import 'openchamber_http.dart';
import 'sse.dart';

const eventWsFallbackWindow = Duration(seconds: 60);
const eventWsReadyTimeoutLan = Duration(seconds: 2);
const eventWsReadyTimeoutRelay = Duration(seconds: 8);

enum EventWsFrameKind { ready, event, error, backpressure, invalid }

class EventWsFrame {
  const EventWsFrame({
    required this.kind,
    this.eventId,
    this.directory,
    this.payload,
    this.message,
  });

  final EventWsFrameKind kind;
  final String? eventId;
  final String? directory;
  final Object? payload;
  final String? message;
}

Uri globalEventWebSocketUri(
  Uri httpBase, {
  String? urlToken,
  String? lastEventId,
}) {
  final scheme = httpBase.scheme == 'https' ? 'wss' : 'ws';
  return httpBase.replace(
    scheme: scheme,
    path: OpenChamberPaths.globalEventWs,
    queryParameters: {
      ...httpBase.queryParameters,
      if (lastEventId != null && lastEventId.isNotEmpty) 'lastEventId': lastEventId,
      if (urlToken != null && urlToken.isNotEmpty) 'oc_url_token': urlToken,
    },
  );
}

EventWsFrame parseEventWsFrame(String raw) {
  Map<String, Object?> message;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const EventWsFrame(kind: EventWsFrameKind.invalid);
    message = Map<String, Object?>.from(decoded);
  } catch (_) {
    return const EventWsFrame(kind: EventWsFrameKind.invalid);
  }
  final type = message['type']?.toString();
  switch (type) {
    case 'ready':
      return const EventWsFrame(kind: EventWsFrameKind.ready);
    case 'error':
      return EventWsFrame(kind: EventWsFrameKind.error, message: message['message']?.toString());
    case 'backpressure':
      return const EventWsFrame(kind: EventWsFrameKind.backpressure);
    case 'event':
      return EventWsFrame(
        kind: EventWsFrameKind.event,
        eventId: message['eventId']?.toString(),
        directory: message['directory']?.toString(),
        payload: message['payload'],
      );
    default:
      return const EventWsFrame(kind: EventWsFrameKind.invalid);
  }
}

SseEvent sseEventFromWsFrame(EventWsFrame frame) {
  final payload = frame.payload;
  return SseEvent(
    id: frame.eventId,
    event: eventTypeOf(payload),
    data: payload == null ? '' : jsonEncode(payload),
  );
}
