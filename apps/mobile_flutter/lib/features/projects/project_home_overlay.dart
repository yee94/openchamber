import '../../data/home_session.dart';
import '../../data/project_id.dart';
import 'project_groups.dart';

/// Overlay settings `projects[]` onto session-index groups so a newly added
/// empty project appears, and official labels win when the path matches.
List<ProjectHomeGroup> overlaySettingsProjects({
  required List<ProjectHomeGroup> sessionGroups,
  required List<Map<String, Object?>> settingsProjects,
}) {
  if (settingsProjects.isEmpty) return sessionGroups;
  final byPath = <String, int>{};
  for (var i = 0; i < sessionGroups.length; i += 1) {
    final path = normalizeProjectDirectory(sessionGroups[i].path);
    if (path.isNotEmpty) byPath[path] = i;
  }
  final next = [...sessionGroups];
  for (final project in settingsProjects) {
    final path = normalizeProjectDirectory(project['path']?.toString() ?? '');
    if (path.isEmpty) continue;
    final id = project['id']?.toString() ?? createProjectIdFromPath(path);
    final label = (project['label']?.toString().trim().isNotEmpty ?? false)
        ? project['label'].toString().trim()
        : deriveProjectLabel(path);
    final existing = byPath[path];
    if (existing != null) {
      final group = next[existing];
      next[existing] = ProjectHomeGroup(
        id: group.id,
        name: label,
        path: group.path,
        sessions: group.sessions,
        worktrees: group.worktrees,
      );
      continue;
    }
    next.add(ProjectHomeGroup(
      id: id.isEmpty ? path : id,
      name: label,
      path: path,
      sessions: const <HomeSessionRow>[],
      worktrees: const [],
    ));
  }
  return next;
}
