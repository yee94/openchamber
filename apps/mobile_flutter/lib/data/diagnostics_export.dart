import 'dart:convert';

import 'app_version.dart';
import 'chat_timeline.dart';
import 'openchamber_http.dart';

/// Official Cap `openchamber.client-diagnostics.v1` keys and ring size.
const transcriptDiagnosticsPreferenceKey = 'openchamber.client-diagnostics.enabled';
const transcriptDiagnosticsLimit = 500;
const transcriptDiagnosticsTailIds = 4;
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
