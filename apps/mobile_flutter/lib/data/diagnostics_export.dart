import 'dart:convert';

/// Official Cap `openchamber.client-diagnostics.v1` export. No message bodies or tokens.
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

String exportClientDiagnosticsReport({int exportedAt = 0, List<Map<String, Object?>> events = const []}) {
  final feats = <String>{};
  for (final event in events) {
    final feat = event['feat']?.toString();
    if (feat != null && feat.isNotEmpty) feats.add(feat);
  }
  return const JsonEncoder.withIndent('  ').convert({
    'schema': 'openchamber.client-diagnostics.v1',
    'exportedAt': exportedAt == 0 ? DateTime.now().millisecondsSinceEpoch : exportedAt,
    'eventCount': events.length,
    'feats': feats.toList(),
    'events': events,
  });
}
