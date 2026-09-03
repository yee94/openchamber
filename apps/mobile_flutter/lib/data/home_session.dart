/// Shared "Project · branch" line for mixed pinned / in-progress home rows.
/// Mirrors `formatHomeSessionSubtitle` in
/// `packages/ui/src/mobile/projects/useMobileProjectsHomeModel.ts`
/// (required 1.19.3-beta.4 / `ee9532c`).
String formatHomeSessionSubtitle(String projectLabel, String? branch) {
  final trimmedBranch = branch?.trim();
  if (trimmedBranch == null || trimmedBranch.isEmpty) {
    return projectLabel;
  }
  return '$projectLabel · $trimmedBranch';
}

enum HomeSessionKind { pinned, inProgress, catalog }

class HomeSessionRow {
  const HomeSessionRow({
    required this.id,
    required this.title,
    required this.projectLabel,
    required this.kind,
    this.branch,
    this.unread = false,
    this.directory,
  });

  final String id;
  final String title;
  final String projectLabel;
  final String? branch;
  final HomeSessionKind kind;
  final bool unread;
  final String? directory;

  String get subtitle => formatHomeSessionSubtitle(projectLabel, branch);
}

/// Fixture rows for unit tests. Production home reads `AppController.sessions`.
List<HomeSessionRow> demoHomeSessions() => const [
      HomeSessionRow(
        id: 'sess-pinned',
        title: 'Release notes',
        projectLabel: 'openchamber',
        branch: 'work/flutter-native',
        kind: HomeSessionKind.pinned,
        unread: true,
      ),
      HomeSessionRow(
        id: 'sess-busy',
        title: 'Fix composer IME',
        projectLabel: 'openchamber',
        branch: 'feat/home',
        kind: HomeSessionKind.inProgress,
      ),
      HomeSessionRow(
        id: 'sess-catalog',
        title: 'New Session',
        projectLabel: 'openchamber',
        branch: 'main',
        kind: HomeSessionKind.catalog,
      ),
    ];
