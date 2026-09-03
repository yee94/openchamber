/// README-measured optical sizes for type and glyphs.
///
/// Colors stay on [OcTokens] (design-system orange / sand). These numbers
/// are from the README mobile photos' tracking, leading, and icon scale —
/// not a theme recolor. WidgetTester cannot paint `UIGlassEffect`.
class OcOptical {
  const OcOptical._();

  /// `--oc-mobile-root-title-size` is 32. README large titles are that size
  /// with open CJK tracking (not the previous negative letter-spacing).
  static const double largeTitle = 32;
  static const double largeTitleTracking = 1.6;
  static const double largeTitleHeight = 1.28;

  /// Large titles stay open. Nested session / file rows pack toward README.
  /// Glyph sizes stay small; colors stay on [OcTokens].
  static const double rowTitle = 15;
  static const double rowTitleTracking = 0.4;
  static const double rowTitleHeight = 1.32;
  static const double sessionRowPadV = 6;
  static const double moreLinkPadV = 5;
  static const double groupHeaderPadV = 11;
  static const double groupHeaderPadVCompact = 9;
  static const double groupTitleMetaGap = 8;

  static const double entityTitle = 16;
  static const double entityTitleTracking = 0.8;
  static const double entityTitleHeight = 1.48;

  static const double meta = 13;
  static const double metaTracking = 0.65;
  static const double metaHeight = 1.75;

  static const double scheduleCardPadV = 13;
  static const double scheduleTitleMetaGap = 11;

  static const double chatTitle = 15;
  static const double chatTitleTracking = 0.4;
  static const double chatTitleHeight = 1.32;
  static const double chatHeaderButton = 24;
  static const double chatBodyHeight = 1.42;
  static const double chatBodyTracking = 0.28;

  static const double dockLabel = 10;
  static const double dockLabelTracking = 0.55;
  static const double dockLabelGap = 2;
  static const double dockCapsuleHeight = 52;
  static const double dockCapsuleRadius = 26;

  /// Official `Button size="mobileIcon"` is 2.5rem (40). Search and + share
  /// that circle so the glass disc is not a tiny sibling of an oversized +.
  /// Glyphs follow official `size-5` (20). Nested list/dock glyphs stay small.
  static const double searchButton = 40;
  static const double addButton = 40;
  static const double headerGlyph = 20;
  static const double headerGlyphStroke = 0.95;

  /// `--oc-mobile-collapsing-action-size` / expand-shift / collapse distance.
  static const double collapsingActionSize = 40;
  static const double collapsingTopPad = 12;
  static const double collapsingExpandShift = 10;
  static const double titleCollapseDistance = 48;
  static const double titleCollapseScaleEnd = 0.625;

  static const double dockGlyph = 9;
  static const double dockGlyphStroke = 0.9;
  static const double dockSquircle = 18;
  static const double dockSquircleRadius = 6;

  static const double leadingCircle = 13;
  static const double leadingCircleCompact = 11;
  static const double leadingGlyph = 6;
  static const double leadingGlyphCompact = 5;

  static const double sessionBullet = 3;
  static const double overflow = 7;
  static const double chevron = 8;

  static const double scheduleStatus = 13;
  static const double scheduleStatusGlyph = 5;

  static const double fileTypeW = 10;
  static const double fileTypeH = 7;
  static const double fileTypeMark = 4;
  static const double fileRowPadV = 1;

  static const double composerRadius = 22;
  static const double composerPlus = 10;
  static const double sendRing = 17;
  static const double sendRingStroke = 0.95;
  static const double sendStop = 4.5;
  static const double scrollFab = 18;
  static const double scrollChevron = 8;

  static const double toolbarGlyph = 8;
  static const double footerGlyph = 9;
}
