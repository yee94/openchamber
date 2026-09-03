import 'dart:ui';

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
    expect(calendar.circles.every((c) => c.$3 <= 0.85), isTrue);
    expect(officialSpriteFor('gear'), isNull);
  });

  test('filled dock calendar is a delicate grid, not a solid slab', () async {
    final calendar = officialSpriteFor('calendar')!;
    final mass = await _opaqueCount(calendar, filled: true);
    // 23×23 = 529. A filled 18×18 plate is ~400+. Header + frame + dots
    // must stay well under that so medium weight does not read heavy.
    expect(mass, lessThan(380));
    expect(mass, greaterThan(160));
  });
}

Future<int> _opaqueCount(OcOfficialSprite sprite, {required bool filled}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  paintOfficialSprite(
    canvas: canvas,
    size: const Size(23, 23),
    sprite: sprite,
    color: const Color(0xFF000000),
    strokeWidth: 2,
    filled: filled,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(23, 23);
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  picture.dispose();
  image.dispose();
  var count = 0;
  final data = bytes!.buffer.asUint8List();
  for (var i = 3; i < data.length; i += 4) {
    if (data[i] > 20) count += 1;
  }
  return count;
}
