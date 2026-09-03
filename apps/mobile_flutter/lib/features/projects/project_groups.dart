import '../../data/home_session.dart';

class WorktreeHomeGroup {
  const WorktreeHomeGroup({
    required this.name,
    required this.path,
    required this.sessions,
  });

  final String name;
  final String path;
  final List<HomeSessionRow> sessions;

  int get sessionCount => sessions.length;
}

class ProjectHomeGroup {
  const ProjectHomeGroup({
    required this.id,
    required this.name,
    required this.path,
    required this.sessions,
    required this.worktrees,
  });

  final String id;
  final String name;
  final String path;
  final List<HomeSessionRow> sessions;
  final List<WorktreeHomeGroup> worktrees;

  int get sessionCount =>
      sessions.length + worktrees.fold<int>(0, (sum, tree) => sum + tree.sessionCount);

  num get latestUpdated {
    num latest = 0;
    for (final row in [...sessions, ...worktrees.expand((tree) => tree.sessions)]) {
      if (row.updated > latest) latest = row.updated;
    }
    return latest;
  }

  String? get pathHint {
    final normalized = normalizeProjectPath(path);
    if (normalized.isEmpty) return null;
    final parts = normalized.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.length <= 1) return normalized;
    if (parts.length == 2) return parts.first;
    return parts.sublist(parts.length - 3, parts.length - 1).join('/');
  }
}

String normalizeProjectPath(String path) {
  return path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
}

String projectPathLabel(String path) {
  final normalized = normalizeProjectPath(path);
  if (normalized.isEmpty) return path;
  final parts = normalized.split('/').where((part) => part.isNotEmpty).toList();
  return parts.isEmpty ? normalized : parts.last;
}

void _sortByActivity(List<HomeSessionRow> rows) {
  rows.sort((a, b) {
    final byUpdated = b.updated.compareTo(a.updated);
    if (byUpdated != 0) return byUpdated;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
}

/// Official `useMobileProjectsHomeModel` buckets by **worktree directory**,
/// not git branch (`packages/ui/src/mobile/projects/useMobileProjectsHomeModel.ts`).
///
/// Root path (no linked worktree) is the project's main workspace — sessions
/// list flat under the project `MobileFloatingSurface`. Linked worktrees are
/// other directories on the same project and render as their own floating
/// cards. Branch names never become their own cards.
List<ProjectHomeGroup> groupSessionsByProject(List<HomeSessionRow> rows) {
  final byProject = <String, List<HomeSessionRow>>{};
  for (final row in rows) {
    byProject.putIfAbsent(row.projectLabel, () => []).add(row);
  }
  return byProject.entries.map((entry) {
    final all = List<HomeSessionRow>.from(entry.value);
    final directoryCounts = <String, int>{};
    for (final row in all) {
      final path = normalizeProjectPath(row.directory ?? '');
      if (path.isEmpty) continue;
      directoryCounts[path] = (directoryCounts[path] ?? 0) + 1;
    }
    String mainPath = '';
    var mainCount = -1;
    for (final item in directoryCounts.entries) {
      if (item.value > mainCount) {
        mainPath = item.key;
        mainCount = item.value;
      }
    }
    if (mainPath.isEmpty) {
      mainPath = all
          .map((row) => normalizeProjectPath(row.directory ?? ''))
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    }

    final main = <HomeSessionRow>[];
    final linked = <String, List<HomeSessionRow>>{};
    for (final row in all) {
      final path = normalizeProjectPath(row.directory ?? '');
      if (path.isEmpty || path == mainPath) {
        main.add(row);
      } else {
        linked.putIfAbsent(path, () => []).add(row);
      }
    }
    _sortByActivity(main);
    for (final bucket in linked.values) {
      _sortByActivity(bucket);
    }

    return ProjectHomeGroup(
      id: entry.key,
      name: entry.key,
      path: mainPath,
      sessions: main,
      worktrees: [
        for (final item in linked.entries)
          WorktreeHomeGroup(
            name: projectPathLabel(item.key),
            path: item.key,
            sessions: item.value,
          ),
      ],
    );
  }).toList();
}
