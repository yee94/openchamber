import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/relative_time.dart';
import 'package:openchamber/features/projects/project_groups.dart';

void main() {
  test('same-directory branches stay in one project card, not split worktrees', () {
    final groups = groupSessionsByProject([
      const HomeSessionRow(
        id: 'a',
        title: 'Main session',
        projectLabel: 'openchamber',
        kind: HomeSessionKind.catalog,
        branch: 'main',
        directory: '/workspace/openchamber',
        updated: 1756900740000,
      ),
      const HomeSessionRow(
        id: 'b',
        title: 'Branch session',
        projectLabel: 'openchamber',
        kind: HomeSessionKind.catalog,
        branch: 'feat/home',
        directory: '/workspace/openchamber',
        updated: 1756899000000,
      ),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.name, 'openchamber');
    expect(groups.single.worktrees, isEmpty);
    expect(groups.single.sessions.map((row) => row.id), ['a', 'b']);
    expect(groups.single.sessionCount, 2);
  });

  test('linked worktrees are other directories on the same project', () {
    final groups = groupSessionsByProject([
      const HomeSessionRow(
        id: 'main-1',
        title: 'Root session',
        projectLabel: 'openchamber',
        kind: HomeSessionKind.catalog,
        directory: '/workspace/openchamber',
        updated: 2,
      ),
      const HomeSessionRow(
        id: 'wt-1',
        title: 'Worktree session',
        projectLabel: 'openchamber',
        kind: HomeSessionKind.catalog,
        directory: '/workspace/openchamber-wt/ios-native',
        updated: 1,
      ),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.sessions.single.id, 'main-1');
    expect(groups.single.worktrees, hasLength(1));
    expect(groups.single.worktrees.single.name, 'ios-native');
    expect(groups.single.worktrees.single.path, '/workspace/openchamber-wt/ios-native');
    expect(groups.single.worktrees.single.sessions.single.id, 'wt-1');
  });

  test('relative time ignores small counters and formats minutes', () {
    expect(formatRelativeTime(3), isNull);
    final now = DateTime.fromMillisecondsSinceEpoch(1756900800000);
    expect(formatRelativeTime(1756900740000, now: now), '1m');
    expect(
      formatRelativeCountdown(1756985460000, now: now, inFuture: (value) => 'In $value'),
      'In 23h 31m',
    );
  });
}
