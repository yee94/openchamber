import 'dart:convert';

/// Official `packages/ui/src/lib/projectId.ts` `createProjectIdFromPath`.
String createProjectIdFromPath(String projectPath) {
  final normalized = projectPath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '').trim();
  if (normalized.isEmpty) return '';
  final encoded = base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
  return 'path_$encoded';
}

String deriveProjectLabel(String path) {
  final normalized = path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  final parts = normalized.split('/').where((part) => part.isNotEmpty).toList();
  return parts.isEmpty ? normalized : parts.last;
}

String normalizeProjectDirectory(String path) {
  final replaced = path.replaceAll('\\', '/').trim();
  if (replaced == '/') return '/';
  return replaced.replaceAll(RegExp(r'/+$'), '');
}

Map<String, Object?> buildProjectEntry({
  required String path,
  String? label,
  String? id,
  int? addedAt,
}) {
  final normalized = normalizeProjectDirectory(path);
  final now = addedAt ?? DateTime.now().millisecondsSinceEpoch;
  return {
    'id': (id != null && id.isNotEmpty) ? id : createProjectIdFromPath(normalized),
    'path': normalized,
    'label': (label != null && label.trim().isNotEmpty) ? label.trim() : deriveProjectLabel(normalized),
    'addedAt': now,
    'lastOpenedAt': now,
  };
}

List<Map<String, Object?>> mergeProjectEntry(
  List<Map<String, Object?>> current,
  Map<String, Object?> entry,
) {
  final path = normalizeProjectDirectory(entry['path']?.toString() ?? '');
  if (path.isEmpty) return current;
  final existingIndex = current.indexWhere(
    (item) => normalizeProjectDirectory(item['path']?.toString() ?? '') == path,
  );
  if (existingIndex >= 0) {
    final next = [...current];
    next[existingIndex] = {...current[existingIndex], ...entry, 'path': path};
    return next;
  }
  return [entry, ...current];
}

List<Map<String, Object?>> removeProjectEntry(
  List<Map<String, Object?>> current,
  String projectId,
) {
  final id = projectId.trim();
  if (id.isEmpty) return current;
  return current.where((item) => item['id']?.toString() != id).toList();
}
