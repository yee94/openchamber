import '../../data/home_session.dart';

class WorktreeHomeGroup {
  const WorktreeHomeGroup({required this.name, required this.sessions});

  final String name;
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
    final normalized = path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) return null;
    final parts = normalized.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.length <= 1) return normalized;
    if (parts.length == 2) return parts.first;
    return parts.sublist(parts.length - 3, parts.length - 1).join('/');
  }
}

/// Group catalog rows the way official `MobileProjectsHome` does:
/// one project card, main-workspace sessions, then linked branch worktrees.
List<ProjectHomeGroup> groupSessionsByProject(List<HomeSessionRow> rows) {
  final byProject = <String, List<HomeSessionRow>>{};
  for (final row in rows) {
    byProject.putIfAbsent(row.projectLabel, () => []).add(row);
  }
  return byProject.entries.map((entry) {
    final all = entry.value;
    final path = all.map((row) => row.directory).whereType<String>().firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );
    final main = <HomeSessionRow>[];
    final branches = <String, List<HomeSessionRow>>{};
    for (final row in all) {
      final branch = row.branch?.trim();
      if (branch == null || branch.isEmpty || branch == 'main') {
        main.add(row);
      } else {
        branches.putIfAbsent(branch, () => []).add(row);
      }
    }
    return ProjectHomeGroup(
      id: entry.key,
      name: entry.key,
      path: path,
      sessions: main,
      worktrees: [
        for (final branch in branches.entries)
          WorktreeHomeGroup(name: branch.key, sessions: branch.value),
      ],
    );
  }).toList();
}
