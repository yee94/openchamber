import '../../data/openchamber_api.dart';
import '../../data/project_id.dart';

bool isHiddenDirectoryName(String name) => name.startsWith('.');

bool hasTrailingPathSeparator(String query) => query.endsWith('/') || query.endsWith('\\');

String? browseParentPath(String path) {
  final normalized = normalizeProjectDirectory(path);
  if (normalized.isEmpty || normalized == '/' || normalized == '~' || normalized == '~/') {
    return null;
  }
  final last = normalized.lastIndexOf('/');
  if (last <= 0) return '/';
  return normalized.substring(0, last);
}

String? lastBrowseSegment(String path) {
  final normalized = normalizeProjectDirectory(path);
  if (normalized.isEmpty || normalized == '/') return null;
  final parts = normalized.split('/').where((part) => part.isNotEmpty).toList();
  return parts.isEmpty ? null : parts.last;
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

/// Official DirectoryExplorer `shouldCreateTarget`: typed path is not already
/// added and is not an exact listed entry (or a trailing-slash missing dir).
bool shouldCreateMissingDirectory({
  required String query,
  required String listedPath,
  required Iterable<FilesystemEntry> entries,
  required Iterable<Map<String, Object?>> addedProjects,
}) {
  final target = normalizeProjectDirectory(query);
  if (target.isEmpty || pathAlreadyAdded(addedProjects, target)) return false;
  if (target == normalizeProjectDirectory(listedPath)) return false;
  final segment = lastBrowseSegment(query);
  if (segment == null || segment.isEmpty) return false;
  if (hasTrailingPathSeparator(query)) return true;
  return !entries.any((entry) => entry.name == segment);
}

String joinBrowsePath(String current, String name) {
  final normalized = normalizeProjectDirectory(current);
  if (normalized.isEmpty || normalized == '/') return '/$name';
  return '$normalized/$name';
}
