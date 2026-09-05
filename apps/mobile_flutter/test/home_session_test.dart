import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/home_session.dart';

void main() {
  test('formatHomeSessionSubtitle joins project · branch (1.19.3-beta.4)', () {
    expect(formatHomeSessionSubtitle('openchamber', 'feat/home'), 'openchamber · feat/home');
    expect(formatHomeSessionSubtitle('openchamber', '  '), 'openchamber');
    expect(formatHomeSessionSubtitle('openchamber', null), 'openchamber');
  });

  test('demo home rows keep unread dots on pinned sessions', () {
    final pinned = demoHomeSessions().firstWhere((row) => row.kind == HomeSessionKind.pinned);
    expect(pinned.unread, isTrue);
    expect(pinned.subtitle, contains(' · '));
  });
}
