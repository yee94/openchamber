import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/theme/oc_official_sprites.dart';

void main() {
  test('parses official homepage sprite paths without throwing', () {
    for (final name in [
      'search',
      'plus',
      'folder',
      'sparkles',
      'calendar',
      'code',
      'branch',
      'ellipsis',
      'sendPlane',
      'chevronDown',
      'chevronRight',
      'chevronBack',
      'xmark',
      'bolt',
      'clock',
      'layers',
      'share',
    ]) {
      final sprite = officialSpriteFor(name);
      expect(sprite, isNotNull, reason: name);
      for (final d in sprite!.paths) {
        expect(() => parseSvgPath(d), returnsNormally, reason: '$name $d');
      }
    }
  });

  test('code-box path has the official slash plus chevrons', () {
    final path = parseSvgPath('m14.5 4-5 16');
    expect(path.getBounds().height, greaterThan(10));
  });

  test('dock calendar is the official grid sprite, not calendar-schedule', () {
    final calendar = officialSpriteFor('calendar')!;
    expect(calendar.rects, isNotEmpty);
    expect(calendar.circles.every((c) => c.$3 <= 1.2), isTrue);
    expect(officialSpriteFor('gear'), isNull);
  });
}
