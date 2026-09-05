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

  testWidgets('ReviewCjk title medium is a real cut, not Regular or a stem', (tester) async {
    final hasTitleCut = File('/usr/share/fonts/opentype/noto/NotoSansCJK-DemiLight.ttc').existsSync() ||
        File('/usr/share/fonts/noto-cjk/NotoSansCJKsc-DemiLight.otf').existsSync() ||
        File('/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc').existsSync() ||
        File('/usr/share/fonts/noto-cjk/NotoSansCJKsc-Medium.otf').existsSync();
    if (!hasTitleCut) {
      // Recapture hosts install fonts-noto-cjk-extra. Without it this
      // host cannot prove the title cut; do not fail CI on Regular-only.
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
                child: SizedBox(
                  width: 160,
                  height: 24,
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
    expect(diff, greaterThan(800), reason: 'w500 must select the title cut (DemiLight@500), not Regular');
  });

  testWidgets('title medium is DemiLight optical, not a Noto Medium brick', (tester) async {
    final demi = File('/usr/share/fonts/opentype/noto/NotoSansCJK-DemiLight.ttc');
    final medium = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc');
    if (!demi.existsSync() || !medium.existsSync()) return;

    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(280 * 3, 80 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<int> darkCount(FontWeight weight) async {
      const key = ValueKey<String>('cjk-optical');
      await tester.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: OcTokens.light.pageBackground,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 160,
                  height: 24,
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
        ),
      );
      await tester.pump();
      final boundary = tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 3));
      final encoded = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final data = encoded!.buffer.asUint8List();
      var dark = 0;
      for (var i = 0; i < data.length; i += 4) {
        final lum = 0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2];
        if (lum < 50) dark += 1;
      }
      return dark;
    }

    final titleDark = await darkCount(FontWeight.w500);
    final regularDark = await darkCount(FontWeight.w400);
    // DemiLight@500 must open vs Regular Micro Hei, and stay a fill cut
    // (not vanish). Noto Medium bricks past this band.
    expect(titleDark, greaterThan(80));
    expect(titleDark, lessThan(regularDark * 2));
  });
}
