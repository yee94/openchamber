import 'project_id.dart';

class GitHubWorktreeItem {
  const GitHubWorktreeItem({
    required this.kind,
    required this.number,
    required this.title,
    this.head,
  });

  final String kind;
  final int number;
  final String title;
  final String? head;

  bool get isIssue => kind == 'issue';
}

String slugifyWorktreeName(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'worktree' : slug;
}

String githubIssueBranchName({required int number, required String title}) {
  return 'issue-$number-${slugifyWorktreeName(title)}';
}

String githubPrBranchName(String head) {
  final trimmed = head.trim();
  return trimmed.isEmpty ? 'pr-branch' : trimmed;
}

String githubItemKey(GitHubWorktreeItem item) => '${item.kind}-${item.number}';

List<GitHubWorktreeItem> parseGitHubIssues(Object? payload) {
  final root = payload is Map ? payload : const {};
  final raw = root['issues'];
  if (raw is! List) return const [];
  return raw.map((item) {
    if (item is! Map) return null;
    final number = item['number'];
    final parsed = number is num ? number.toInt() : int.tryParse(number?.toString() ?? '');
    if (parsed == null) return null;
    return GitHubWorktreeItem(
      kind: 'issue',
      number: parsed,
      title: item['title']?.toString() ?? '#$parsed',
    );
  }).whereType<GitHubWorktreeItem>().toList();
}

List<GitHubWorktreeItem> parseGitHubPulls(Object? payload) {
  final root = payload is Map ? payload : const {};
  final raw = root['prs'] ?? root['pulls'] ?? root['items'];
  if (raw is! List) return const [];
  return raw.map((item) {
    if (item is! Map) return null;
    final number = item['number'];
    final parsed = number is num ? number.toInt() : int.tryParse(number?.toString() ?? '');
    if (parsed == null) return null;
    return GitHubWorktreeItem(
      kind: 'pr',
      number: parsed,
      title: item['title']?.toString() ?? 'PR #$parsed',
      head: item['head']?.toString() ?? item['headRefName']?.toString(),
    );
  }).whereType<GitHubWorktreeItem>().toList();
}

({String providerId, String modelId}) splitDefaultModel(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return (providerId: 'anthropic', modelId: 'claude-sonnet-4');
  final slash = value.indexOf('/');
  if (slash <= 0 || slash == value.length - 1) {
    return (providerId: value, modelId: value);
  }
  return (providerId: value.substring(0, slash), modelId: value.substring(slash + 1));
}

String normalizeWorktreePath(String path) => normalizeProjectDirectory(path);
