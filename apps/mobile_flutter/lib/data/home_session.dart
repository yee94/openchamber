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
  });

  final String id;
  final String title;
  final String projectLabel;
  final String? branch;
  final HomeSessionKind kind;
  final bool unread;

  String get subtitle => formatHomeSessionSubtitle(projectLabel, branch);
}

/// First-slice demo rows so Projects home can push Chat and show the
/// 1.19.3-beta.4 subtitle + 1.19.2 unread-dot contract without a live server.
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
