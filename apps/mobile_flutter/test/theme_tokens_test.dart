import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/theme/app_theme.dart';
import 'package:openchamber/theme/ios_hero.dart';
import 'package:openchamber/theme/oc_elevation.dart';
import 'package:openchamber/theme/oklch.dart';

void main() {
  test('oklch conversion matches Ottosson sRGB for documented dark samples', () {
    expectNear(oklchColor(0.16, 0.01, 30), const Color(0xFF110C0B));
    expectNear(oklchColor(0.77, 0.17, 85), const Color(0xFFE5A900));
    expectNear(oklchColor(0.85, 0.02, 90), const Color(0xFFD3CDBF));
    expectNear(oklchColor(0.19, 0.01, 40), const Color(0xFF181210));
  });

  test('OcTokens light and dark follow design-system.css OKLCH, not iOS greys', () {
    expect(OcTokens.light.primary, isNot(const Color(0xFF2F6FED)));
    expect(OcTokens.dark.primary, isNot(const Color(0xFF2F6FED)));
    expectNear(OcTokens.light.background, oklchColor(0.97, 0.02, 85));
    expectNear(OcTokens.light.primary, oklchColor(0.65, 0.2, 55));
    expectNear(OcTokens.dark.background, oklchColor(0.16, 0.01, 30));
    expectNear(OcTokens.dark.primary, oklchColor(0.77, 0.17, 85));
    expectNear(OcTokens.dark.destructive, oklchColor(0.65, 0.15, 30));
    expect(OcTokens.light.surfaceElevated, OcTokens.light.card);
    expect(OcTokens.light.surfaceBackground, OcTokens.light.background);
    expect(OcTokens.light.surfaceMuted, OcTokens.light.muted);
    expect(OcTokens.dark.pageBackground, isNot(OcTokens.light.pageBackground));
  });

  test('mobile geometry rides official rem tokens', () {
    expect(OcTokens.radius, 10);
    expect(OcTokens.surfaceRadius, 24);
    expect(OcTokens.insetRadius, 16);
    expect(OcTokens.controlRadius, 20);
    expect(OcTokens.formControlHeight, 36);
    expect(OcTokens.dockHeight, 68);
    expect(OcTokens.dockRadius, 34);
    expect(OcTokens.rootTitleSize, 32);
    expect(OcTokens.textMarkdown, 15);
    expect(OcTokens.textUiHeader, 14);
    expect(OcTokens.textUiLabel, 13);
    expect(OcTokens.textMeta, 13);
    expect(OcTokens.pageInlineInset, 18);
    expect(OcTokens.detailNavigationHeight, 56);
    expect(OcTokens.detailActionEdgeInset, 16);
    expect(OcTokens.detailActionColumn, 44);
    expect(OcTokens.headerFadeExtra, 28);
    expect(OcTokens.pageScrollBottomExtra, 40);
    expect(OcTokens.dockInnerInset, 5);
    expect(OcTokens.dockGap, 3);
    expect(OcTokens.dockMaxWidth, 416);
    expect(OcTokens.tabHeight, 58);
    expect(OcTokens.tabRadius, 29);
    expect(OcTokens.detailTitleSize, 15);
    expect(OcTokens.detailSubtitleSize, 10);
  });

  test('materialTheme attaches OcTokens for both brightnesses', () {
    final light = materialTheme(Brightness.light);
    final dark = materialTheme(Brightness.dark);
    expect(light.extension<OcTokens>(), OcTokens.light);
    expect(dark.extension<OcTokens>(), OcTokens.dark);
    expect(light.colorScheme.primary, OcTokens.light.primary);
    expect(dark.colorScheme.primary, OcTokens.dark.primary);
    expect(light.scaffoldBackgroundColor, OcTokens.light.pageBackground);
    expect(dark.scaffoldBackgroundColor, OcTokens.dark.pageBackground);
  });

  test('OcOptical sizes are smaller/airier than the previous crude chrome', () {
    expect(OcOptical.largeTitle, 32);
    expect(OcOptical.largeTitleTracking, closeTo(-1.28, 0.01));
    expect(OcOptical.largeTitleHeight, 1.2);
    expect(OcOptical.rowTitle, 12);
    expect(OcOptical.rowTitleTracking, closeTo(-0.14, 0.01));
    expect(OcOptical.projectTitleTracking, closeTo(-0.34, 0.01));
    expect(OcOptical.rowTitleHeight, greaterThanOrEqualTo(1.33));
    expect(OcOptical.rowTitleHeight, lessThan(1.42));
    expect(OcOptical.sessionRowHeight, OcTokens.sessionRowHeight);
    expect(OcOptical.sessionRowVisualHeight, 40);
    expect(OcOptical.sessionRowVisualHeight, lessThan(OcOptical.sessionRowHeight));
    expect(OcOptical.sessionRowVisualHeight, greaterThanOrEqualTo(36));
    expect(OcOptical.sessionRowPadV, 5);
    expect(OcOptical.metaHeight, 1.25);
    expect(OcOptical.entityTitleHeight, 1.25);
    expect(OcOptical.scheduleTitleMetaGap, 3);
    expect(OcOptical.chatBodyHeight, lessThan(1.50));
    expect(OcOptical.chatTitle, 15);
    expect(OcOptical.chatBodyTracking, 0);
    expect(OcOptical.chatTitleHeight, 1.4);
    expect(OcOptical.detailSubtitle, 10);
    expect(OcOptical.detailSubtitleHeight, 1.4);
    expect(OcOptical.detailNavigationHeight, 56);
    expect(OcOptical.detailActionEdgeInset, 16);
    expect(OcOptical.searchButton, 40);
    expect(OcOptical.addButton, 40);
    expect(OcOptical.headerDisc, OcOptical.searchButton);
    expect(OcOptical.headerGlyph, 20);
    expect(OcOptical.headerGlyphStroke, 1.5);
    expect(OcOptical.collapsingActionSize, 40);
    expect(OcOptical.collapsingTitleCompactSize, 20);
    expect(OcOptical.collapsingTopPad, 12);
    expect(OcOptical.collapsingExpandShift, 10);
    expect(OcOptical.collapsingInnerGap, 16);
    expect(OcOptical.collapsingTrailingGap, 14);
    expect(OcOptical.collapsingInlineExtra, 4);
    expect(OcOptical.titleCollapseDistance, 48);
    expect(OcOptical.titleCollapseScaleReduce, 0.375);
    expect(OcOptical.titleCollapseScaleEnd, 0.625);
    expect(OcOptical.rootTitleTracking(0), closeTo(-1.28, 0.01));
    expect(OcOptical.rootTitleTracking(1), closeTo(-0.64, 0.01));
    expect(OcOptical.dockGlyph, 23);
    expect(OcOptical.dockTabHeight, 58);
    expect(OcOptical.dockTabRadius, 29);
    expect(OcOptical.dockLabel, 12);
    expect(OcOptical.dockLabelHeight, 1.0);
    expect(OcOptical.dockGap, 3);
    expect(OcOptical.dockSelectedFullSlot, isTrue);
    expect(OcOptical.dockIconWashAlpha, 0.55);
    expect(OcOptical.dockGlyphStroke, 2);
    expect(OcOptical.listGlyphStroke, OcOptical.headerGlyphStroke);
    expect(OcOptical.searchFieldGlyph, 16);
    expect(OcOptical.leadingCircle, 38);
    expect(OcOptical.leadingGlyph, 18);
    expect(OcOptical.leadingGlyphCompact, 14);
    expect(OcOptical.worktreeIconBox, 18);
    expect(OcOptical.worktreeGlyph, 14);
    expect(OcOptical.sessionMore, 14);
    expect(OcOptical.chevron, 14);
    expect(OcOptical.footerGlyph, 14);
    expect(OcOptical.scheduleStatus, 38);
    expect(OcOptical.overflow, 16);
    expect(OcOptical.chatChip, 40);
    expect(OcOptical.chatChip, OcOptical.headerDisc);
    expect(OcOptical.sessionBullet, 5);
    expect(OcOptical.fileTypeSize, 12);
    expect(OcOptical.fileRowPadV, 4);
    expect(OcOptical.composerRadius, 24);
    expect(OcOptical.composerPlus, 20);
    expect(OcOptical.composerPlusStroke, 1.5);
    expect(OcOptical.footerGlyphStroke, 2);
    expect(OcOptical.footerMeta, 11);
    expect(OcOptical.sendRing, 32);
    expect(OcOptical.sendStop, 12);
    expect(OcOptical.scrollFab, 36);
    expect(OcOptical.glassBlur, 20);
    expect(OcOptical.dockCapsuleHeight, OcTokens.dockHeight);
    expect(OcOptical.dockCapsuleRadius, OcTokens.dockRadius);
    expect(OcOptical.dockBottomPad, OcTokens.pageGap);
    expect(OcOptical.searchButton, greaterThan(OcTokens.headerButtonSize));
    expect(OcTokens.light.primary, isNot(const Color(0xFF007AFF)));
  });

  test('OcElevation is layered in light and empty in dark', () {
    expect(OcElevation.cardFor(OcTokens.light), hasLength(3));
    expect(OcElevation.cardFor(OcTokens.light).first.blurRadius, greaterThanOrEqualTo(2));
    expect(OcElevation.cardFor(OcTokens.light).last.blurRadius, lessThanOrEqualTo(16));
    expect(OcElevation.cardFor(OcTokens.light).last.offset.dy, lessThanOrEqualTo(3));
    expect(
      (OcElevation.cardFor(OcTokens.light).last.color.a * 255).round(),
      lessThan(0x0C),
    );
    expect(
      OcElevation.cardFor(OcTokens.light, tight: true),
      OcElevation.cardFor(OcTokens.light),
    );
    expect(OcElevation.groupedFor(OcTokens.light), OcElevation.cardFor(OcTokens.light));
    expect(OcElevation.composerFor(OcTokens.light), OcElevation.cardFor(OcTokens.light));
    expect(OcElevation.controlFor(OcTokens.light), isNotEmpty);
    expect(OcElevation.cardFor(OcTokens.dark), isEmpty);
    expect(OcElevation.dockFor(OcTokens.dark), isEmpty);
    expect(OcElevation.controlFor(OcTokens.dark), isEmpty);
  });

  test('resolveOcBrightness honors Light / Dark / System', () {
    expect(resolveOcBrightness(ThemeMode.light, Brightness.dark), Brightness.light);
    expect(resolveOcBrightness(ThemeMode.dark, Brightness.light), Brightness.dark);
    expect(resolveOcBrightness(ThemeMode.system, Brightness.dark), Brightness.dark);
    expect(resolveOcBrightness(ThemeMode.system, Brightness.light), Brightness.light);
  });
}

void expectNear(Color actual, Color expected, {int slop = 1}) {
  int channel(Color color, double Function(Color c) read) => (read(color) * 255).round();
  expect((channel(actual, (c) => c.r) - channel(expected, (c) => c.r)).abs(), lessThanOrEqualTo(slop), reason: 'red $actual vs $expected');
  expect((channel(actual, (c) => c.g) - channel(expected, (c) => c.g)).abs(), lessThanOrEqualTo(slop), reason: 'green $actual vs $expected');
  expect((channel(actual, (c) => c.b) - channel(expected, (c) => c.b)).abs(), lessThanOrEqualTo(slop), reason: 'blue $actual vs $expected');
}
