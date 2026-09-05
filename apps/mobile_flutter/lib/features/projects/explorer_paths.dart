import '../../data/project_id.dart';

bool isHiddenDirectoryName(String name) => name.startsWith('.');

String? browseParentPath(String path) {
  final normalized = normalizeProjectDirectory(path);
  if (normalized.isEmpty || normalized == '/' || normalized == '~' || normalized == '~/') {
    return null;
  }
  final last = normalized.lastIndexOf('/');
  if (last <= 0) return '/';
  return normalized.substring(0, last);
}

bool pathAlreadyAdded(Iterable<Map<String, Object?>> projects, String path) {
  final normalized = normalizeProjectDirectory(path);
  if (normalized.isEmpty) return false;
  for (final project in projects) {
    if (normalizeProjectDirectory(project['path']?.toString() ?? '') == normalized) {
      return true;
    }
  }
  return false;
}

String joinBrowsePath(String current, String name) {
  final normalized = normalizeProjectDirectory(current);
  if (normalized.isEmpty || normalized == '/') return '/$name';
  return '$normalized/$name';
}
