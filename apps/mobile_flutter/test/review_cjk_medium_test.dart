import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/theme/ios_chrome.dart';

import 'review_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadReviewFonts);

  testWidgets('ReviewCjk Medium is a real cut, not Regular or a stem', (tester) async {
    final hasNotoMedium = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc').existsSync() ||
        File('/usr/share/fonts/noto-cjk/NotoSansCJKsc-Medium.otf').existsSync();
    if (!hasNotoMedium) {
      // Recapture hosts install fonts-noto-cjk-extra. Without it this
      // host cannot prove the Medium cut; do not fail CI on Regular-only.
      return;
    }

    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(280 * 3, 80 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<List<int>> paint(FontWeight weight) async {
      const key = ValueKey<String>('cjk-weight');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            textTheme: const TextTheme().apply(
              fontFamily: 'ReviewSans',
              fontFamilyFallback: const ['ReviewCjk'],
            ),
          ),
          home: ColoredBox(
            color: OcTokens.light.pageBackground,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: Text(
                  '发布说明',
                  style: TextStyle(
                    fontFamily: 'ReviewSans',
                    fontFamilyFallback: const ['ReviewCjk'],
                    fontSize: OcOptical.rowTitle,
                    fontWeight: weight,
                    height: OcOptical.rowTitleHeight,
                    color: OcTokens.light.foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary = tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 3));
      final encoded = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      return encoded!.buffer.asUint8List();
    }

    final regular = await paint(FontWeight.w400);
    final medium = await paint(FontWeight.w500);
    expect(regular.length, medium.length);
    var diff = 0;
    for (var i = 0; i < regular.length; i++) {
      diff += (regular[i] - medium[i]).abs();
    }
    expect(diff, greaterThan(800), reason: 'w500 must select Noto SC Medium, not Regular');
  });
}
