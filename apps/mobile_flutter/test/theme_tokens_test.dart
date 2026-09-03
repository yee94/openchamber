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
    expect(OcTokens.light.floatSurface.a, closeTo(0.45, 0.01));
    expect(OcTokens.dark.floatSurface.a, closeTo(0.45, 0.01));
    expect(OcTokens.light.dockPlate.a, closeTo(0.45, 0.01));
    expect(OcTokens.light.glassFill.a, closeTo(0.68, 0.01));
    expect(OcTokens.dark.glassFill.a, closeTo(0.66, 0.01));
    expect(OcTokens.light.glassFill.r, closeTo(1.0, 0.01));
    expect(OcTokens.light.glassFill.g, closeTo(1.0, 0.01));
    expect(OcTokens.light.glassFill.b, closeTo(1.0, 0.01));
    expect(OcTokens.light.glassFill, isNot(OcTokens.light.surfaceElevated));
    expect(OcTokens.light.glassChipFill.a, closeTo(0.18, 0.01));
    expect(OcTokens.light.glassChipFill.a, lessThan(OcTokens.light.glassFill.a));
    expect(OcTokens.light.glassChipFill.a, greaterThan(0.12));
    expect(OcTokens.light.glassChipFill.r, closeTo(1.0, 0.01));
    expect(OcTokens.light.glassHighlight.a, closeTo(0.60, 0.01));
    expect(OcTokens.dark.glassHighlight.a, closeTo(0.18, 0.01));
    expect(OcTokens.light.glassHighlight.a, lessThan(OcTokens.light.floatHighlight.a));
    expect(OcTokens.light.dockPlate.a, lessThan(OcTokens.light.glassFill.a));
    expect(
      OcTokens.light.selectedTabWash.a,
      closeTo(OcTokens.light.interactiveSelection.a * OcOptical.dockIconWashAlpha, 0.005),
    );
    expect(OcTokens.light.selectedTabWash.a, lessThan(OcTokens.light.interactiveSelection.a));
    expect(OcTokens.light.selectedTabWash.a, greaterThan(0.03));
    expect(
      (OcTokens.light.selectedTabWash.r - OcTokens.light.primary.r).abs(),
      greaterThan(0.15),
    );
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
    expect(OcOptical.rowTitleTracking, 0);
    expect(OcOptical.projectTitleTracking, closeTo(-0.34, 0.01));
    expect(OcOptical.rowTitleHeight, greaterThanOrEqualTo(1.33));
    expect(OcOptical.rowTitleHeight, lessThan(1.42));
    expect(OcOptical.sessionRowHeight, OcTokens.sessionRowHeight);
    expect(OcOptical.sessionRowVisualHeight, 40);
    expect(OcOptical.sessionRowVisualHeight, lessThan(OcOptical.sessionRowHeight));
    expect(OcOptical.sessionRowVisualHeight, greaterThanOrEqualTo(36));
    expect(OcOptical.sessionRowPadV, 4.5);
    expect(OcOptical.metaHeight, 1.25);
    expect(OcOptical.entityTitleHeight, 1.25);
    expect(OcOptical.groupTitleMetaGap, 4);
    expect(OcOptical.projectTriggerPad, 10);
    expect(OcOptical.projectTriggerGap, 7);
    expect(OcOptical.sessionRowPadH, 16);
    expect(OcOptical.sessionRowPadRight, 2);
    expect(OcOptical.sessionTitleSubtitleGap, 3);
    expect(OcOptical.sessionLineLeading, closeTo(0.395, 0.001));
    expect(OcOptical.sessionLineLeading, greaterThan(0.35));
    expect(OcOptical.sessionLineLeading, lessThan(0.40));
    for (final box in [OcOptical.rowTitleHeight, OcOptical.sessionSubtitleHeight]) {
      final height = (box - OcOptical.sessionLineLeading).clamp(0.5, box);
      expect(height + OcOptical.sessionLineLeading, closeTo(box, 0.001));
      expect(height, lessThan(1.0));
    }
    expect(
      OcOptical.sessionRowPadV * 2 +
          OcOptical.rowTitle * OcOptical.rowTitleHeight +
          OcOptical.sessionTitleSubtitleGap +
          OcOptical.sessionSubtitle * OcOptical.sessionSubtitleHeight,
      OcOptical.sessionRowVisualHeight,
    );
    expect(OcOptical.sessionStatus, 12);
    expect(OcOptical.sessionRowMainGap, 8);
    expect(OcOptical.projectHeaderHeight, 74);
    expect(OcOptical.projectGroupsPadTop, 2);
    expect(OcOptical.projectGroupsPadInline, 12);
    expect(OcOptical.projectGroupsPadBottom, 14);
    expect(OcOptical.projectGroupGap, 10);
    expect(OcOptical.pageProjectGap, 20);
    expect(OcOptical.entityMetaGap, 5);
    expect(OcOptical.worktreeLabelMinHeight, 42);
    expect(OcOptical.worktreeLabelPadV, 6);
    expect(OcOptical.worktreeLabelPadLeft, 10);
    expect(OcOptical.worktreeLabelPadRight, 2);
    expect(OcOptical.scheduleTitleMetaGap, 4);
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
    expect(OcOptical.headerDiscVisual, 36);
    expect(OcOptical.headerDiscVisual, lessThan(OcOptical.headerDisc));
    expect(OcOptical.headerGlyphStrokeVisual, 1.25);
    expect(OcOptical.headerGlyphStrokeVisual, lessThan(OcOptical.headerGlyphStroke));
    expect(OcOptical.detailSubtitleGap, 2);
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
    expect(OcOptical.dockGlyphVisual, OcOptical.dockGlyph);
    expect(OcOptical.dockGlyphStrokeVisual, lessThan(OcOptical.dockGlyphStroke));
    expect(OcOptical.dockGlyphStrokeVisual, closeTo(1.55, 0.01));
    expect(OcOptical.dockGlyphStrokeVisual, greaterThan(1.4));
    expect(OcOptical.dockGlyphFillBodies, isTrue);
    expect(OcOptical.dockWashBlur, 5);
    expect(OcOptical.dockWashBlur, lessThan(OcOptical.glassBlur));
    expect(OcOptical.chipBlur, OcOptical.glassBlur);
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
    expect(OcOptical.scheduleStatus, OcOptical.leadingCircle);
    expect(OcOptical.scheduleStatusVisual, 32);
    expect(OcOptical.scheduleStatusVisual, lessThan(OcOptical.scheduleStatus));
    expect(OcOptical.scheduleStatusGlyph, 14);
    expect(OcOptical.overflow, 16);
    expect(OcOptical.chatChip, 40);
    expect(OcOptical.chatChip, OcOptical.headerDisc);
    expect(OcOptical.sessionBullet, 5);
    expect(OcOptical.fileTypeSize, 12);
    expect(OcOptical.fileTypeMark, 7);
    expect(OcOptical.fileRowPadV, 3);
    expect(OcOptical.fileRowHeight, 24);
    expect(OcOptical.fileChrome, 11);
    expect(OcOptical.composerRadius, 24);
    expect(OcOptical.composerPlus, 20);
    expect(OcOptical.composerPlusStroke, 1.5);
    expect(OcOptical.footerGlyphStroke, 2);
    expect(OcOptical.footerMeta, 11);
    expect(OcOptical.sendRing, 32);
    expect(OcOptical.sendRingDisc, 24);
    expect(OcOptical.sendRingDisc, lessThan(OcOptical.sendRing));
    expect(OcOptical.sendPlane, 16);
    expect(OcOptical.sendStop, 9);
    expect(OcOptical.sendArrow, 13);
    expect(OcOptical.headerRestPeek, 20);
    expect(OcOptical.sessionMoreHit, 36);
    expect(OcOptical.sessionMoreEdge, 4);
    expect(OcOptical.sessionTimeGap, 6);
    expect(OcOptical.dockSelectedFullSlot, isTrue);
    expect(OcOptical.scrollFab, 36);
    expect(OcOptical.glassBlur, 20);
    expect(OcOptical.dockCapsuleHeight, OcTokens.dockHeight);
    expect(OcOptical.dockCapsuleRadius, OcTokens.dockRadius);
    expect(OcOptical.dockBottomPad, OcTokens.pageGap);
    expect(OcOptical.searchButton, greaterThan(OcTokens.headerButtonSize));
    expect(OcTokens.light.primary, isNot(const Color(0xFF007AFF)));
  });

  test('OcElevation is layered in light and empty in dark', () {
    expect(OcElevation.cardFor(OcTokens.light), hasLength(2));
    expect(OcElevation.cardFor(OcTokens.light).first.blurRadius, greaterThanOrEqualTo(2));
    expect(OcElevation.cardFor(OcTokens.light).last.blurRadius, lessThanOrEqualTo(8));
    expect(OcElevation.cardFor(OcTokens.light).last.offset.dy, 0);
    expect(
      (OcElevation.cardFor(OcTokens.light).last.color.a * 255).round(),
      lessThanOrEqualTo(0x06),
    );
    expect(
      OcElevation.cardFor(OcTokens.light, tight: true),
      OcElevation.cardFor(OcTokens.light),
    );
    expect(OcElevation.groupedFor(OcTokens.light), OcElevation.cardFor(OcTokens.light));
    expect(OcElevation.composerFor(OcTokens.light), OcElevation.cardFor(OcTokens.light));
    expect(OcElevation.dockFor(OcTokens.light).length, 2);
    expect(OcElevation.dockFor(OcTokens.light).last.blurRadius, lessThanOrEqualTo(12));
    expect(OcElevation.controlFor(OcTokens.light), hasLength(3));
    expect(OcElevation.controlFor(OcTokens.light).last.blurRadius, 20);
    expect(OcElevation.controlFor(OcTokens.light).last.offset.dy, 8);
    expect(OcElevation.controlFor(OcTokens.light).last.spreadRadius, -6);
    expect(OcElevation.chipFor(OcTokens.light), hasLength(1));
    expect(OcElevation.chipFor(OcTokens.light).single.blurRadius, 2);
    expect(OcElevation.chipFor(OcTokens.light).single.offset, Offset.zero);
    expect(OcElevation.chipFor(OcTokens.dark), isEmpty);
    expect(
      (OcElevation.controlFor(OcTokens.light).last.color.a * 255).round(),
      lessThanOrEqualTo(0x1F),
    );
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
