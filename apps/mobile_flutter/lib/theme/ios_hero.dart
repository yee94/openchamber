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

  /// Yee: type was too tight. Open CJK/Latin tracking + leading.
  /// Do not densify these back toward a packed README photo.
  /// Glyph sizes stay small; colors stay on [OcTokens].
  static const double rowTitle = 15;
  static const double rowTitleTracking = 0.75;
  static const double rowTitleHeight = 1.52;
  static const double sessionRowPadV = 12;
  static const double moreLinkPadV = 8;
  static const double groupHeaderPadV = 13;
  static const double groupHeaderPadVCompact = 11;
  static const double groupTitleMetaGap = 7;

  static const double entityTitle = 16;
  static const double entityTitleTracking = 0.7;
  static const double entityTitleHeight = 1.42;

  static const double meta = 13;
  static const double metaTracking = 0.55;
  static const double metaHeight = 1.68;

  static const double scheduleCardPadV = 14;
  static const double scheduleTitleMetaGap = 9;

  static const double chatTitle = 15;
  static const double chatTitleTracking = 0.4;
  static const double chatTitleHeight = 1.32;
  static const double chatHeaderButton = 24;
  static const double chatBodyHeight = 1.6;
  static const double chatBodyTracking = 0.42;

  static const double dockLabel = 10;
  static const double dockLabelTracking = 0.55;
  static const double dockLabelGap = 2;
  static const double dockCapsuleHeight = 56;
  static const double dockCapsuleRadius = 28;

  /// Header + is a small filled circle; search is smaller still.
  /// Glyphs occupy ~35% of the circle so they do not crowd the rim.
  static const double searchButton = 26;
  static const double addButton = 28;
  static const double headerGlyph = 9;
  static const double headerGlyphStroke = 1.0;

  static const double dockGlyph = 11;
  static const double dockGlyphStroke = 1.0;
  static const double dockSquircle = 18;
  static const double dockSquircleRadius = 6;

  static const double leadingCircle = 16;
  static const double leadingCircleCompact = 14;
  static const double leadingGlyph = 8;
  static const double leadingGlyphCompact = 7;

  static const double sessionBullet = 3;
  static const double overflow = 9;
  static const double chevron = 10;

  static const double scheduleStatus = 16;
  static const double scheduleStatusGlyph = 7;

  static const double fileTypeW = 12;
  static const double fileTypeH = 9;
  static const double fileTypeMark = 5;
  static const double fileRowPadV = 3;

  static const double composerPlus = 11;
  static const double sendRing = 18;
  static const double sendRingStroke = 1.05;
  static const double sendStop = 5;
  static const double scrollFab = 20;
  static const double scrollChevron = 9;

  static const double toolbarGlyph = 10;
  static const double footerGlyph = 11;
}
