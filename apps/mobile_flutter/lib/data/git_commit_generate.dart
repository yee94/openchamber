import 'dart:convert';

/// Official Cap commit-generation prompts (`packages/ui/src/lib/magicPrompts.ts`).
const officialCommitVisiblePrompt =
    'You are generating a Conventional Commits subject line from the diffs of the selected files.';

const officialCommitInstructionsTemplate =
    'Return exactly one JSON object and nothing else. Do not include prose, markdown, explanations, or code fences.\n'
    '\n'
    'The JSON object must have exactly this shape:\n'
    '{"subject": string, "highlights": string[]}\n'
    '\n'
    'Rules:\n'
    '- subject format: <type>: <summary>\n'
    '- allowed types: feat, fix, refactor, perf, docs, test, build, ci, chore, style, revert\n'
    '- no scope in subject\n'
    '- keep subject concise and user-facing\n'
    '- highlights: 0-3 concise user-facing points\n'
    '- use double quotes for all JSON strings\n'
    '- do not include trailing commas or comments\n'
    '\n'
    'Selected files:\n'
    '{{selected_files}}';

const commitDiffFileLimit = 30;
const commitDiffTotalCharLimit = 120000;

String renderCommitInstructions(List<String> files) {
  final selected = files.map((file) => '- $file').join('\n');
  return officialCommitInstructionsTemplate.replaceAll('{{selected_files}}', selected);
}

class GeneratedCommitMessage {
  const GeneratedCommitMessage({required this.subject, this.highlights = const []});

  final String subject;
  final List<String> highlights;
}

GeneratedCommitMessage parseGeneratedCommitMessage(String text) {
  final decoded = _extractJsonObject(text);
  final subject = decoded['subject']?.toString().trim() ?? '';
  if (subject.isEmpty) {
    throw const FormatException('Structured output missing subject');
  }
  final raw = decoded['highlights'];
  final highlights = <String>[];
  if (raw is List) {
    for (final item in raw) {
      final value = item?.toString().trim() ?? '';
      if (value.isNotEmpty) highlights.add(value);
      if (highlights.length == 3) break;
    }
  }
  return GeneratedCommitMessage(subject: subject, highlights: highlights);
}

Map<String, Object?> _extractJsonObject(String text) {
  final trimmed = text.trim();
  final direct = _tryDecodeMap(trimmed);
  if (direct != null) return direct;
  final start = trimmed.indexOf('{');
  final end = trimmed.lastIndexOf('}');
  if (start >= 0 && end > start) {
    final nested = _tryDecodeMap(trimmed.substring(start, end + 1));
    if (nested != null) return nested;
  }
  throw const FormatException('Structured output missing subject');
}

Map<String, Object?>? _tryDecodeMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
  } catch (_) {}
  return null;
}
