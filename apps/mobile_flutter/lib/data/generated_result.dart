/// Port of `packages/ui/src/components/chat/message/parts/generatedJsonResult.ts`.
library;

import 'dart:convert';

class GeneratedResult {
  const GeneratedResult({
    required this.kind,
    required this.title,
    this.body,
    this.highlights = const [],
    required this.raw,
  });

  /// `commit` or `pr`.
  final String kind;
  final String title;
  final String? body;
  final List<String> highlights;
  final String raw;
}

GeneratedResult? parseGeneratedJsonResult(String value) {
  for (final item in _parseJsonObjects(value)) {
    final subject = (item['subject'] is String) ? (item['subject'] as String).trim() : '';
    final highlights = item['highlights'] is List
        ? (item['highlights'] as List)
            .whereType<String>()
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .take(3)
            .toList()
        : const <String>[];
    if (subject.isNotEmpty) {
      return GeneratedResult(
        kind: 'commit',
        title: subject,
        highlights: highlights,
        raw: value.trim(),
      );
    }
    final title = (item['title'] is String) ? (item['title'] as String).trim() : '';
    final body = (item['body'] is String) ? (item['body'] as String).trim() : '';
    if (title.isNotEmpty || body.isNotEmpty) {
      return GeneratedResult(
        kind: 'pr',
        title: title,
        body: body.isEmpty ? null : body,
        raw: value.trim(),
      );
    }
  }
  return null;
}

List<Map<String, Object?>> _parseJsonObjects(String value) {
  final text = value.trim();
  final candidates = <String>[];
  final fenced = RegExp(r'^```(?:json)?\s*([\s\S]*?)```$', caseSensitive: false).firstMatch(text);
  if (fenced != null && (fenced.group(1) ?? '').trim().isNotEmpty) {
    candidates.add(fenced.group(1)!.trim());
  }
  if (text.startsWith('{') && text.endsWith('}')) {
    candidates.add(text);
  }
  final parsed = <Map<String, Object?>>[];
  for (final candidate in candidates) {
    try {
      final item = jsonDecode(candidate);
      if (item is Map) parsed.add(Map<String, Object?>.from(item));
    } catch (_) {}
  }
  return parsed;
}
