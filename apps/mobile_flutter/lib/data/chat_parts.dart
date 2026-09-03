import 'dart:convert';

import 'chat_timeline.dart';
import 'context_tool_grouping.dart';

class PermissionRequestRecord {
  const PermissionRequestRecord({
    required this.id,
    required this.sessionId,
    required this.permission,
    this.patterns = const [],
    this.metadata = const {},
  });

  final String id;
  final String sessionId;
  final String permission;
  final List<String> patterns;
  final Map<String, Object?> metadata;
}

List<ChatMessage> parseTurnPageMessages(Object? payload, {List<PermissionRequestRecord> permissions = const []}) {
  if (payload is! Map) return const [];
  final records = payload['records'];
  if (records is! List) return const [];
  final messages = <ChatMessage>[];
  for (final record in records) {
    if (record is! Map) continue;
    final info = record['info'];
    if (info is! Map) continue;
    final id = info['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final role = info['role']?.toString() ?? '';
    final parts = parseChatParts(record['parts'], messageId: id);
    final body = parts.where((part) => part.kind == ChatPartKind.text).map((part) => part.body ?? '').where((text) => text.isNotEmpty).join('\n');
    final tps = formatAssistantTps(computeAssistantTps(
      createdAt: _num(info['time'] is Map ? (info['time'] as Map)['created'] : info['createdAt']),
      completedAt: _num(info['time'] is Map ? (info['time'] as Map)['completed'] : info['completedAt']),
      outputTokens: _num(info['tokens'] is Map ? (info['tokens'] as Map)['output'] : null),
      reasoningTokens: _num(info['tokens'] is Map ? (info['tokens'] as Map)['reasoning'] : null),
      parts: record['parts'],
    ));
    if (body.isEmpty && parts.isEmpty && role.isEmpty) continue;
    final model = info['model'];
    String? modelName;
    if (model is Map) {
      modelName = model['name']?.toString() ?? model['id']?.toString();
    } else {
      modelName = model?.toString() ?? info['modelID']?.toString();
    }
    if (modelName != null && modelName.isEmpty) modelName = null;
    final agentRole = info['agent']?.toString() ?? info['mode']?.toString();
    final created = _num(info['time'] is Map ? (info['time'] as Map)['created'] : info['createdAt']);
    final completed = _num(info['time'] is Map ? (info['time'] as Map)['completed'] : info['completedAt']);
    String? processed;
    String? clock;
    if (created != null && completed != null && completed > created) {
      final seconds = ((completed - created) / 1000).round();
      final minutes = seconds ~/ 60;
      final remain = seconds % 60;
      processed = minutes > 0 ? '${minutes}m ${remain}s' : '${remain}s';
    }
    if (completed != null && completed > 1e11) {
      final time = DateTime.fromMillisecondsSinceEpoch(completed.round());
      clock = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    final agentCount = parts.where((part) => part.kind == ChatPartKind.task).length;
    messages.add(ChatMessage(
      id: id,
      body: body,
      isUser: role == 'user',
      parts: parts,
      tokensPerSecond: tps,
      modelName: modelName,
      agentRole: agentRole == null || agentRole.isEmpty ? null : agentRole,
      processedLabel: processed,
      completedClock: clock,
      agentCount: agentCount,
    ));
  }
  if (permissions.isEmpty || messages.isEmpty) return messages;
  final already = messages.expand((message) => message.parts).map((part) => part.permissionId).whereType<String>().toSet();
  final extras = permissions.where((item) => !already.contains(item.id)).map(_permissionPart).toList();
  if (extras.isEmpty) return messages;
  final target = messages.lastIndexWhere((message) => !message.isUser);
  final index = target >= 0 ? target : messages.length - 1;
  final next = [...messages];
  next[index] = next[index].copyWith(parts: [...next[index].parts, ...extras]);
  return next;
}

List<ChatPart> parseChatParts(Object? parts, {required String messageId}) {
  if (parts is! List) return const [];
  final out = <ChatPart>[];
  var index = 0;
  for (final raw in parts) {
    if (raw is! Map) continue;
    final part = Map<String, Object?>.from(raw);
    final type = part['type']?.toString() ?? '';
    final id = part['id']?.toString() ?? '$messageId-$index';
    index += 1;
    if (type == 'text') {
      out.addAll(splitTextAndMermaid(part['text']?.toString() ?? '', id: id));
      continue;
    }
    if (type == 'file') {
      final path = part['filename']?.toString() ?? part['url']?.toString() ?? '';
      final mime = part['mime']?.toString() ?? '';
      final image = mime.startsWith('image/');
      out.add(ChatPart(
        id: id,
        kind: ChatPartKind.fileOp,
        title: path.isEmpty ? (image ? 'Image' : 'File') : path,
        subtitle: mime,
        path: path,
        status: image ? 'image' : 'file',
        toolName: image ? 'image-preview' : 'file',
        metadata: {'mime': mime, if (part['url'] != null) 'url': part['url']},
      ));
      continue;
    }
    if (type != 'tool') continue;
    final tool = (part['tool'] ?? part['name'] ?? '').toString();
    final state = part['state'] is Map ? Map<String, Object?>.from(part['state'] as Map) : const <String, Object?>{};
    final input = state['input'] is Map
        ? Map<String, Object?>.from(state['input'] as Map)
        : part['input'] is Map
            ? Map<String, Object?>.from(part['input'] as Map)
            : const <String, Object?>{};
    final output = state['output']?.toString() ?? part['output']?.toString() ?? '';
    final status = state['status']?.toString() ?? part['status']?.toString();
    final path = _toolPath(input, output);
    final lower = tool.toLowerCase();
    if (_isDiffTool(lower)) {
      final diff = parseUnifiedDiff(output.isNotEmpty ? output : input['patch']?.toString() ?? '');
      out.add(ChatPart(
        id: id,
        kind: ChatPartKind.diff,
        title: path ?? tool,
        subtitle: status,
        status: status,
        toolName: tool,
        path: path,
        added: diff.added,
        removed: diff.removed,
        diffLines: diff.lines,
        body: diff.preview,
      ));
      continue;
    }
    if (_isFileOpTool(lower)) {
      out.add(ChatPart(
        id: id,
        kind: ChatPartKind.fileOp,
        title: _fileOpTitle(lower, path),
        subtitle: path ?? status,
        status: status,
        toolName: tool,
        path: path,
        body: _short(output),
      ));
      continue;
    }
    if (lower == 'task') {
      final tps = formatAssistantTps(_taskTps(state, input, output));
      out.add(ChatPart(
        id: id,
        kind: ChatPartKind.task,
        title: input['description']?.toString() ?? input['prompt']?.toString() ?? 'Task',
        subtitle: status,
        status: status,
        toolName: tool,
        tokensPerSecond: tps,
        body: _taskSummary(state, output),
      ));
      continue;
    }
    if (normalizeContextToolName(tool) == 'skill') {
      final name = _skillName(state, input, output) ?? 'skill';
      out.add(ChatPart(
        id: id,
        kind: ChatPartKind.tool,
        title: name,
        subtitle: status,
        status: status,
        toolName: tool,
        metadata: _metadataMap(state['metadata']),
        body: _short(output),
      ));
      continue;
    }
    if (lower == 'permission' || state['permission'] != null) {
      out.add(_permissionPart(PermissionRequestRecord(
        id: state['id']?.toString() ?? part['id']?.toString() ?? id,
        sessionId: '',
        permission: state['permission']?.toString() ?? tool,
        patterns: _stringList(state['patterns'] ?? part['patterns']),
        metadata: _metadataMap(state['metadata'] ?? part['metadata'] ?? input),
      )));
      continue;
    }
    out.add(ChatPart(
      id: id,
      kind: ChatPartKind.tool,
      title: _toolTitle(lower, input, path),
      subtitle: status,
      status: status,
      toolName: tool,
      path: path,
      body: _short(output.isNotEmpty ? output : input['command']?.toString() ?? input['query']?.toString()),
    ));
  }
  return out;
}

ChatPart _permissionPart(PermissionRequestRecord request) {
  return ChatPart(
    id: request.id,
    kind: ChatPartKind.permission,
    title: request.permission,
    subtitle: request.patterns.join(', '),
    permissionId: request.id,
    status: 'pending',
    toolName: request.permission,
    patterns: request.patterns,
    metadata: request.metadata,
  );
}

List<PermissionRequestRecord> parsePermissionList(Object? payload, {String? sessionId}) {
  final list = payload is List
      ? payload
      : payload is Map && payload['permissions'] is List
          ? payload['permissions'] as List
          : const [];
  return list.whereType<Map>().map((item) {
    return PermissionRequestRecord(
      id: item['id']?.toString() ?? '',
      sessionId: item['sessionID']?.toString() ?? item['sessionId']?.toString() ?? '',
      permission: item['permission']?.toString() ?? '',
      patterns: _stringList(item['patterns']),
      metadata: _metadataMap(item['metadata']),
    );
  }).where((item) => item.id.isNotEmpty && (sessionId == null || item.sessionId.isEmpty || item.sessionId == sessionId)).toList();
}

class ParsedDiff {
  const ParsedDiff({this.added = const [], this.removed = const [], this.lines = const [], this.preview});
  final List<String> added;
  final List<String> removed;
  final List<DiffLine> lines;
  final String? preview;
}

final _mermaidFence = RegExp(r'```mermaid[ \t]*\n([\s\S]*?)```', multiLine: true);

List<ChatPart> splitTextAndMermaid(String text, {required String id}) {
  if (text.isEmpty) return const [];
  final out = <ChatPart>[];
  var cursor = 0;
  var mermaidIndex = 0;
  for (final match in _mermaidFence.allMatches(text)) {
    final before = text.substring(cursor, match.start);
    if (before.trim().isNotEmpty) {
      out.add(ChatPart(
        id: mermaidIndex == 0 ? id : '$id-text-$mermaidIndex',
        kind: ChatPartKind.text,
        title: 'text',
        body: before.trim(),
      ));
    }
    final source = (match.group(1) ?? '').trim();
    if (source.isNotEmpty) {
      out.add(ChatPart(
        id: '$id-mermaid-$mermaidIndex',
        kind: ChatPartKind.mermaid,
        title: 'Mermaid',
        body: source,
      ));
    }
    mermaidIndex += 1;
    cursor = match.end;
  }
  final rest = text.substring(cursor);
  if (rest.trim().isNotEmpty || out.isEmpty) {
    if (rest.trim().isNotEmpty || mermaidIndex == 0) {
      out.add(ChatPart(
        id: mermaidIndex == 0 ? id : '$id-text-tail',
        kind: ChatPartKind.text,
        title: 'text',
        body: mermaidIndex == 0 ? text : rest.trim(),
      ));
    }
  }
  return out;
}

ParsedDiff parseUnifiedDiff(String raw) {
  if (raw.trim().isEmpty) return const ParsedDiff();
  final added = <String>[];
  final removed = <String>[];
  final lines = <DiffLine>[];
  for (final line in raw.replaceAll('\r\n', '\n').split('\n')) {
    if (line.startsWith('+++') || line.startsWith('---') || line.startsWith('diff ') || line.startsWith('@@')) {
      continue;
    }
    if (line.startsWith('+')) {
      final text = line.substring(1);
      added.add(text);
      lines.add(DiffLine(kind: 'add', text: text));
    } else if (line.startsWith('-')) {
      final text = line.substring(1);
      removed.add(text);
      lines.add(DiffLine(kind: 'remove', text: text));
    } else if (line.startsWith(' ')) {
      lines.add(DiffLine(kind: 'context', text: line.substring(1)));
    }
  }
  final previewLines = [
    ...removed.take(4).map((line) => '- $line'),
    ...added.take(4).map((line) => '+ $line'),
  ];
  return ParsedDiff(
    added: added,
    removed: removed,
    lines: lines,
    preview: previewLines.isEmpty ? null : previewLines.join('\n'),
  );
}

double? computeAssistantTps({
  num? createdAt,
  num? completedAt,
  num? outputTokens,
  num? reasoningTokens,
  Object? parts,
}) {
  final generated = (outputTokens ?? 0) + (reasoningTokens ?? 0);
  if (generated <= 0 || createdAt == null || completedAt == null) return null;
  var durationMs = completedAt.toDouble() - createdAt.toDouble();
  if (durationMs <= 0) return null;
  durationMs -= _toolDurationMs(parts);
  if (durationMs <= 0) return null;
  return generated / (durationMs / 1000);
}

String? formatAssistantTps(double? tps) {
  if (tps == null || tps <= 0 || tps.isNaN) return null;
  if (tps >= 1000) return '${(tps / 1000).toStringAsFixed(1)}k tok/s';
  if (tps >= 100) return '${tps.round()} tok/s';
  if (tps >= 10) return '${tps.toStringAsFixed(1)} tok/s';
  return '${tps.toStringAsFixed(2)} tok/s';
}

double _toolDurationMs(Object? parts) {
  if (parts is! List) return 0;
  var total = 0.0;
  for (final part in parts) {
    if (part is! Map || part['type'] != 'tool') continue;
    final state = part['state'] is Map ? part['state'] as Map : null;
    final time = state?['time'] is Map ? state!['time'] as Map : null;
    final start = _num(time?['start']);
    final end = _num(time?['end']);
    if (start == null || end == null || end < start) continue;
    total += end - start;
  }
  return total;
}

double? _taskTps(Map<String, Object?> state, Map<String, Object?> input, String output) {
  final tokens = _num(state['tokens']) ?? _num(input['tokens']);
  final time = state['time'] is Map ? Map<String, Object?>.from(state['time'] as Map) : const <String, Object?>{};
  return computeAssistantTps(
    createdAt: _num(time['start']),
    completedAt: _num(time['end']),
    outputTokens: tokens,
    parts: const [],
  );
}

String? _taskSummary(Map<String, Object?> state, String output) {
  final title = state['title']?.toString();
  if (title != null && title.isNotEmpty) return title;
  return _short(output);
}

bool _isDiffTool(String tool) =>
    tool == 'edit' || tool == 'multiedit' || tool == 'apply_patch' || tool == 'str_replace' || tool == 'str_replace_based_edit_tool';

bool _isFileOpTool(String tool) =>
    tool == 'write' || tool == 'create' || tool == 'file_write' || tool == 'read' || tool == 'view' || tool == 'file_read' || tool == 'cat';

String _fileOpTitle(String tool, String? path) {
  final action = tool == 'write' || tool == 'create' || tool == 'file_write' ? 'Write' : 'Read';
  return path == null || path.isEmpty ? action : '$action $path';
}

String _toolTitle(String tool, Map<String, Object?> input, String? path) {
  if (tool == 'bash' || tool == 'shell' || tool == 'cmd' || tool == 'terminal' || tool == 'shell_command') {
    return input['command']?.toString() ?? input['cmd']?.toString() ?? 'Terminal';
  }
  if (tool == 'webfetch' || tool == 'fetch' || tool == 'curl' || tool == 'wget') {
    return input['url']?.toString() ?? input['URL']?.toString() ?? input['uri']?.toString() ?? tool;
  }
  if (tool == 'websearch' ||
      tool == 'web-search' ||
      tool == 'search_web' ||
      tool == 'codesearch' ||
      tool == 'perplexity' ||
      tool == 'google' ||
      tool == 'bing' ||
      tool == 'duckduckgo') {
    return input['query']?.toString() ?? input['q']?.toString() ?? tool;
  }
  if (tool == 'grep' || tool == 'search' || tool == 'glob') {
    return input['pattern']?.toString() ?? input['query']?.toString() ?? tool;
  }
  return path ?? tool;
}

String? _skillName(Map<String, Object?> state, Map<String, Object?> input, String output) {
  final metadata = state['metadata'] is Map ? Map<String, Object?>.from(state['metadata'] as Map) : const <String, Object?>{};
  for (final source in [metadata, input]) {
    for (final key in const ['name', 'id']) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
  }
  try {
    final decoded = jsonDecode(output);
    if (decoded is Map) {
      final name = decoded['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
  } catch (_) {}
  return null;
}

String? _toolPath(Map<String, Object?> input, String output) {
  for (final key in const ['path', 'file', 'filePath', 'file_path', 'target']) {
    final value = input[key]?.toString();
    if (value != null && value.isNotEmpty) return value;
  }
  final match = RegExp(r'^(?:\+\+\+|---)\s+[ab]/(.+)$', multiLine: true).firstMatch(output);
  return match?.group(1);
}

String? _short(String? value) {
  if (value == null || value.isEmpty) return null;
  final trimmed = value.trim();
  if (trimmed.length <= 240) return trimmed;
  return '${trimmed.substring(0, 237)}…';
}

num? _num(Object? value) => value is num ? value : null;

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((entry) => entry.toString()).where((entry) => entry.isNotEmpty).toList();
}

Map<String, Object?> _metadataMap(Object? value) {
  if (value is! Map) return const {};
  return Map<String, Object?>.from(value);
}
