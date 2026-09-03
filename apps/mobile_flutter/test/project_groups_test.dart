import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/relative_time.dart';
import 'package:openchamber/features/projects/project_groups.dart';

void main() {
  test('groups catalog rows by project and linked branches', () {
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
    expect(groups.single.sessions.single.id, 'a');
    expect(groups.single.worktrees.single.name, 'feat/home');
    expect(groups.single.sessionCount, 2);
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
