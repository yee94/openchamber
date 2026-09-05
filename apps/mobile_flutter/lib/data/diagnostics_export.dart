import 'dart:convert';

import 'app_version.dart';
import 'chat_timeline.dart';
import 'openchamber_http.dart';

/// Official Cap `openchamber.client-diagnostics.v1` keys and ring size.
const transcriptDiagnosticsPreferenceKey = 'openchamber.client-diagnostics.enabled';
const transcriptDiagnosticsLimit = 500;
const transcriptDiagnosticsTailIds = 4;
const transcriptDiagnosticsUserTextLimit = 400;
const _sensitiveError = r'bearer|token|authorization|password|secret|cookie';

String diagnosticsExportFileName([DateTime? now]) {
  final stamp = (now ?? DateTime.now()).toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
  return 'openchamber-diagnostics-$stamp.json';
}

int diagnosticsExportEventCount(String content) {
  try {
    final parsed = jsonDecode(content);
    if (parsed is Map && parsed['eventCount'] is num) {
      return (parsed['eventCount'] as num).toInt();
    }
  } catch (_) {}
  return 0;
}

bool isPrereleaseClientVersion(String? version) => version != null && version.contains('-');

bool? parseTranscriptDiagnosticsPreference(String? raw) {
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  return null;
}

bool resolveTranscriptDiagnosticsEnabled({String? version, bool? preference}) {
  if (preference == true) return true;
  if (preference == false) return false;
  return isPrereleaseClientVersion(version);
}

String? sanitizeDiagnosticsError(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final clipped = text.length <= 240 ? text : text.substring(0, 240);
  if (RegExp(_sensitiveError, caseSensitive: false).hasMatch(clipped)) return 'redacted-error';
  return clipped;
}

int? diagnosticsHttpStatus(Object? error) {
  if (error is OpenChamberHttpException && error.status >= 100 && error.status <= 599) {
    return error.status;
  }
  return null;
}

List<String> lastTranscriptMessageIDs(List<ChatMessage> messages, {int limit = transcriptDiagnosticsTailIds}) {
  if (messages.length <= limit) return [for (final message in messages) message.id];
  return [for (final message in messages.sublist(messages.length - limit)) message.id];
}

int countIdentityMissingMessages(List<ChatMessage> messages) {
  var missing = 0;
  for (final message in messages) {
    if (message.isUser) continue;
    final agent = message.agentRole?.trim() ?? '';
    final model = message.modelName?.trim() ?? '';
    if (agent.isEmpty || model.isEmpty) missing += 1;
  }
  return missing;
}

String? extractDiagnosticsUserText(ChatMessage message) {
  if (!message.isUser) return null;
  final joined = message.body.trim();
  if (joined.isEmpty) return null;
  if (RegExp(_sensitiveError, caseSensitive: false).hasMatch(joined)) return 'redacted-text';
  if (joined.length <= transcriptDiagnosticsUserTextLimit) return joined;
  return '${joined.substring(0, transcriptDiagnosticsUserTextLimit)}…';
}

Map<String, Object?> captureTranscriptCanonicalSnapshot(
  List<ChatMessage> messages, {
  Set<String> optimisticIds = const {},
}) {
  return {
    'messageIDs': [for (final message in messages) message.id],
    'messages': [
      for (final message in messages)
        {
          'id': message.id,
          'partCount': message.parts.length,
          'slimCount': 0,
          'fullCount': message.parts.length,
          'optimistic': optimisticIds.contains(message.id),
          'completed': message.completedClock != null && message.completedClock!.isNotEmpty,
          'role': message.isUser ? 'user' : 'assistant',
          if (extractDiagnosticsUserText(message) != null) 'text': extractDiagnosticsUserText(message),
          if (!message.isUser &&
              ((message.agentRole?.trim().isEmpty ?? true) || (message.modelName?.trim().isEmpty ?? true)))
            'identityMissing': true,
        },
    ],
  };
}

Map<String, Object?> diffTranscriptCanonicalSnapshots(
  Map<String, Object?> before,
  Map<String, Object?> after,
) {
  final beforeMessages = [
    for (final item in (before['messages'] as List? ?? const []))
      if (item is Map) item.map((key, value) => MapEntry(key.toString(), value)),
  ];
  final afterMessages = [
    for (final item in (after['messages'] as List? ?? const []))
      if (item is Map) item.map((key, value) => MapEntry(key.toString(), value)),
  ];
  final beforeById = {for (final message in beforeMessages) message['id']?.toString() ?? '': message};
  final afterById = {for (final message in afterMessages) message['id']?.toString() ?? '': message};
  final beforeIds = [for (final id in (before['messageIDs'] as List? ?? const [])) id.toString()];
  final afterIds = [for (final id in (after['messageIDs'] as List? ?? const [])) id.toString()];
  final beforeSet = beforeIds.toSet();
  final afterSet = afterIds.toSet();
  final partsChanged = <Map<String, Object?>>[];
  final downgraded = <String>[];
  final optimisticLost = <String>[];
  final identityLost = <String>[];
  for (final id in beforeIds) {
    final previous = beforeById[id];
    if (previous == null) continue;
    final next = afterById[id];
    if (next == null) {
      if (previous['optimistic'] == true) optimisticLost.add(id);
      continue;
    }
    if (previous['partCount'] != next['partCount'] ||
        previous['slimCount'] != next['slimCount'] ||
        previous['fullCount'] != next['fullCount'] ||
        previous['optimistic'] != next['optimistic']) {
      partsChanged.add({
        'id': id,
        'before': {
          'partCount': previous['partCount'],
          'slimCount': previous['slimCount'],
          'fullCount': previous['fullCount'],
          'optimistic': previous['optimistic'],
        },
        'after': {
          'partCount': next['partCount'],
          'slimCount': next['slimCount'],
          'fullCount': next['fullCount'],
          'optimistic': next['optimistic'],
        },
      });
    }
    if ((previous['fullCount'] as num? ?? 0) > 0 &&
        (next['fullCount'] as num? ?? 0) == 0 &&
        (next['slimCount'] as num? ?? 0) > 0) {
      downgraded.add(id);
    }
    if (previous['optimistic'] == true && next['optimistic'] != true && next['completed'] != true) {
      optimisticLost.add(id);
    }
    if (previous['identityMissing'] != true && next['identityMissing'] == true) {
      identityLost.add(id);
    }
  }
  return {
    'addedMessageIDs': [for (final id in afterIds) if (!beforeSet.contains(id)) id],
    'removedMessageIDs': [for (final id in beforeIds) if (!afterSet.contains(id)) id],
    'partsChanged': partsChanged,
    'downgraded': downgraded,
    'optimisticLost': optimisticLost,
    'identityLost': identityLost,
  };
}

int countFullParts(List<ChatMessage> messages) {
  var count = 0;
  for (final message in messages) {
    count += message.parts.length;
  }
  return count;
}

class ClientDiagnosticsEvent {
  const ClientDiagnosticsEvent({
    required this.at,
    required this.feat,
    required this.kind,
    required this.sessionID,
    this.directory,
    this.transport,
    this.source,
    this.requestStatus,
    this.httpStatus,
    this.messageCount,
    this.lastMessageIDs,
    this.slimPartCount,
    this.fullPartCount,
    this.identityMissingCount,
    this.purpose,
    this.error,
    this.trigger,
    this.before,
    this.after,
    this.diff,
  });

  final int at;
  final String feat;
  final String kind;
  final String sessionID;
  final String? directory;
  final String? transport;
  final String? source;
  final String? requestStatus;
  final int? httpStatus;
  final int? messageCount;
  final List<String>? lastMessageIDs;
  final int? slimPartCount;
  final int? fullPartCount;
  final int? identityMissingCount;
  final String? purpose;
  final String? error;
  final String? trigger;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;
  final Map<String, Object?>? diff;

  Map<String, Object?> toJson() {
    return {
      'at': at,
      'feat': feat,
      'kind': kind,
      'sessionID': sessionID,
      if (directory != null && directory!.isNotEmpty) 'directory': directory,
      if (transport != null && transport!.isNotEmpty) 'transport': transport,
      if (source != null) 'source': source,
      if (requestStatus != null) 'requestStatus': requestStatus,
      if (httpStatus != null) 'httpStatus': httpStatus,
      if (messageCount != null) 'messageCount': messageCount,
      if (lastMessageIDs != null) 'lastMessageIDs': lastMessageIDs,
      if (slimPartCount != null) 'slimPartCount': slimPartCount,
      if (fullPartCount != null) 'fullPartCount': fullPartCount,
      if (identityMissingCount != null) 'identityMissingCount': identityMissingCount,
      if (purpose != null) 'purpose': purpose,
      if (error != null) 'error': error,
      if (trigger != null) 'trigger': trigger,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
      if (diff != null) 'diff': diff,
    };
  }
}

ClientDiagnosticsEvent snapshotTranscriptDiagnostics({
  required String kind,
  required String sessionID,
  String feat = 'transcript',
  String? directory,
  String? transport,
  String? source,
  String? requestStatus,
  String? purpose,
  Object? error,
  List<ChatMessage>? messages,
  int? now,
}) {
  return ClientDiagnosticsEvent(
    at: now ?? DateTime.now().millisecondsSinceEpoch,
    feat: feat,
    kind: kind,
    sessionID: sessionID,
    directory: directory,
    transport: transport,
    source: source,
    requestStatus: requestStatus,
    httpStatus: diagnosticsHttpStatus(error),
    messageCount: messages?.length,
    lastMessageIDs: messages == null ? null : lastTranscriptMessageIDs(messages),
    slimPartCount: messages == null ? null : 0,
    fullPartCount: messages == null ? null : countFullParts(messages),
    identityMissingCount: messages == null ? null : countIdentityMissingMessages(messages),
    purpose: purpose,
    error: sanitizeDiagnosticsError(error),
  );
}

/// Official memory ring. Flutter has no IndexedDB; this is Cap's documented fallback.
class ClientDiagnosticsRecorder {
  ClientDiagnosticsRecorder({this.limit = transcriptDiagnosticsLimit, bool? enabled})
      : _enabled = enabled ?? resolveTranscriptDiagnosticsEnabled(version: AppVersion.display);

  final int limit;
  bool _enabled;
  final List<ClientDiagnosticsEvent> _events = [];

  bool get isEnabled => _enabled;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  List<ClientDiagnosticsEvent> get events => List.unmodifiable(_events);

  void record(ClientDiagnosticsEvent event) {
    if (!_enabled) return;
    _events.add(event);
    if (_events.length > limit) {
      _events.removeRange(0, _events.length - limit);
    }
  }

  void recordSafely(ClientDiagnosticsEvent event) {
    try {
      record(event);
    } catch (_) {}
  }

  void clear() => _events.clear();

  String exportReport({int exportedAt = 0}) {
    final feats = <String>{for (final event in _events) event.feat};
    return const JsonEncoder.withIndent('  ').convert({
      'schema': 'openchamber.client-diagnostics.v1',
      'exportedAt': exportedAt == 0 ? DateTime.now().millisecondsSinceEpoch : exportedAt,
      'eventCount': _events.length,
      'feats': feats.toList(),
      'events': [for (final event in _events) event.toJson()],
    });
  }
}

ClientDiagnosticsRecorder? _runtimeRecorder;

ClientDiagnosticsRecorder get clientDiagnosticsRecorder {
  return _runtimeRecorder ??= ClientDiagnosticsRecorder();
}

void debugResetClientDiagnosticsRecorder([ClientDiagnosticsRecorder? next]) {
  _runtimeRecorder = next;
}

String exportClientDiagnosticsReport({int exportedAt = 0, List<Map<String, Object?>> events = const []}) {
  if (events.isNotEmpty) {
    return const JsonEncoder.withIndent('  ').convert({
      'schema': 'openchamber.client-diagnostics.v1',
      'exportedAt': exportedAt == 0 ? DateTime.now().millisecondsSinceEpoch : exportedAt,
      'eventCount': events.length,
      'feats': {
        for (final event in events)
          if (event['feat']?.toString().isNotEmpty == true) event['feat'].toString(),
      }.toList(),
      'events': events,
    });
  }
  return clientDiagnosticsRecorder.exportReport(exportedAt: exportedAt);
}

void recordChatTranscriptDiagnostics({
  required String kind,
  required String sessionID,
  String? directory,
  String? transport,
  String? source,
  String? requestStatus,
  String? purpose,
  Object? error,
  List<ChatMessage>? messages,
}) {
  clientDiagnosticsRecorder.recordSafely(
    snapshotTranscriptDiagnostics(
      kind: kind,
      sessionID: sessionID,
      directory: directory,
      transport: transport,
      source: source,
      requestStatus: requestStatus,
      purpose: purpose,
      error: error,
      messages: messages,
    ),
  );
}

void recordTranscriptDiff({
  required String trigger,
  required String sessionID,
  required List<ChatMessage> before,
  required List<ChatMessage> after,
  String? directory,
  String? transport,
  String? purpose,
  Set<String> optimisticAfterIds = const {},
  int? now,
}) {
  try {
    final beforeSnap = captureTranscriptCanonicalSnapshot(before);
    final afterSnap = captureTranscriptCanonicalSnapshot(after, optimisticIds: optimisticAfterIds);
    clientDiagnosticsRecorder.record(
      ClientDiagnosticsEvent(
        at: now ?? DateTime.now().millisecondsSinceEpoch,
        feat: 'transcript',
        kind: 'transcript-diff',
        sessionID: sessionID,
        directory: directory,
        transport: transport,
        purpose: purpose,
        trigger: trigger,
        before: beforeSnap,
        after: afterSnap,
        diff: diffTranscriptCanonicalSnapshots(beforeSnap, afterSnap),
      ),
    );
  } catch (_) {}
}
