import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/features/projects/highlighted_text.dart';
import 'package:openchamber/mobile/mobile_surface.dart';
import 'package:openchamber/theme/app_theme.dart';
import 'package:openchamber/theme/ios_chrome.dart';

import 'review_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadReviewFonts);

  testWidgets('session titles keep L<120 cores above floating frost', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 160 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const key = ValueKey<String>('title-ink-surface');
    await tester.pumpWidget(
      MaterialApp(
        theme: materialTheme(Brightness.light).copyWith(
          textTheme: materialTheme(Brightness.light).textTheme.apply(
            fontFamily: 'ReviewSans',
            fontFamilyFallback: const ['ReviewCjk'],
          ),
        ),
        home: ColoredBox(
          color: OcTokens.light.pageBackground,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: MobileFloatingSurface(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: HighlightedText(
                    '发布说明 修复输入法',
                    query: '',
                    stem: OcOptical.sessionTitleStem,
                    style: TextStyle(
                      fontSize: OcOptical.rowTitle,
                      fontWeight: FontWeight.w500,
                      letterSpacing: OcOptical.rowTitleTracking,
                      height: OcOptical.rowTitleHeight,
                      color: OcTokens.light.foreground,
                    ),
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
    final ink = <double>[];
    for (var i = 0; i < data.length; i += 4) {
      final lum = 0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2];
      if (lum < 200) ink.add(lum);
    }
    ink.sort();
    expect(ink, isNotEmpty);
    final p5 = ink[(0.05 * (ink.length - 1)).round()];
    expect(p5, lessThan(50));
    expect(ink.first, lessThan(40));
    expect(ink.where((lum) => lum < 50).length, greaterThan(ink.length ~/ 4));
  });

  testWidgets('collapsing header frost does not wash session title cores', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 320 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const key = ValueKey<String>('title-ink-under-header');
    await tester.pumpWidget(
      MaterialApp(
        theme: materialTheme(Brightness.light).copyWith(
          textTheme: materialTheme(Brightness.light).textTheme.apply(
            fontFamily: 'ReviewSans',
            fontFamilyFallback: const ['ReviewCjk'],
          ),
        ),
        home: ColoredBox(
          color: OcTokens.light.pageBackground,
          child: RepaintBoundary(
            key: key,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 96,
                  left: 16,
                  right: 16,
                  child: HighlightedText(
                    '发布说明 修复输入法',
                    query: '',
                    stem: OcOptical.sessionTitleStem,
                    style: TextStyle(
                      fontSize: OcOptical.rowTitle,
                      fontWeight: FontWeight.w500,
                      height: OcOptical.rowTitleHeight,
                      color: OcTokens.light.foreground,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 80,
                  child: OcFrosted(
                    fill: OcTokens.light.glassFill.withValues(alpha: 0.26),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
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
    final w = image!.width;
    // Title sits below the 80px header (240 device px).
    final ink = <double>[];
    for (var y = 250; y < image.height; y += 1) {
      for (var x = 0; x < w; x += 1) {
        final i = (y * w + x) * 4;
        final lum = 0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2];
        if (lum < 200) ink.add(lum);
      }
    }
    ink.sort();
    expect(ink, isNotEmpty);
    final p5 = ink[(0.05 * (ink.length - 1)).round()];
    expect(p5, lessThan(120));
    expect(ink.where((lum) => lum < 120), isNotEmpty);
  });
}
