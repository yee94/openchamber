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

  static const double rowTitle = 15;
  static const double rowTitleTracking = 0.7;
  static const double rowTitleHeight = 1.5;

  static const double entityTitle = 16;
  static const double entityTitleTracking = 0.65;
  static const double entityTitleHeight = 1.4;

  static const double meta = 13;
  static const double metaTracking = 0.5;
  static const double metaHeight = 1.65;

  static const double chatBodyHeight = 1.55;
  static const double chatBodyTracking = 0.35;

  static const double dockLabel = 10;
  static const double dockLabelTracking = 0.55;

  /// Header + is a small filled circle; search is smaller still.
  /// Glyphs occupy ~35% of the circle so they do not crowd the rim.
  static const double searchButton = 26;
  static const double addButton = 28;
  static const double headerGlyph = 10;
  static const double headerGlyphStroke = 1.0;

  static const double dockGlyph = 12;
  static const double dockGlyphStroke = 1.0;
  static const double dockSquircleW = 20;
  static const double dockSquircleH = 16;
  static const double dockSquircleRadius = 5;

  static const double leadingCircle = 18;
  static const double leadingCircleCompact = 16;
  static const double leadingGlyph = 9;
  static const double leadingGlyphCompact = 8;

  static const double sessionBullet = 3;
  static const double overflow = 10;
  static const double chevron = 11;

  static const double scheduleStatus = 18;
  static const double scheduleStatusGlyph = 8;

  static const double fileTypeW = 14;
  static const double fileTypeH = 11;
  static const double fileTypeMark = 6;

  static const double composerPlus = 12;
  static const double sendRing = 20;
  static const double sendRingStroke = 1.05;
  static const double sendStop = 5.5;
  static const double scrollFab = 22;
  static const double scrollChevron = 10;

  static const double toolbarGlyph = 11;
  static const double footerGlyph = 12;
}
