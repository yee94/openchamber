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
  static const double largeTitleTracking = 1.1;
  static const double largeTitleHeight = 1.22;

  static const double rowTitle = 15;
  static const double rowTitleTracking = 0.45;
  static const double rowTitleHeight = 1.38;

  static const double entityTitle = 16;
  static const double entityTitleTracking = 0.4;
  static const double entityTitleHeight = 1.32;

  static const double meta = 13;
  static const double metaTracking = 0.35;
  static const double metaHeight = 1.5;

  static const double chatBodyHeight = 1.5;
  static const double chatBodyTracking = 0.2;

  static const double dockLabel = 10;
  static const double dockLabelTracking = 0.45;

  /// Header + is a small filled circle; search is smaller still.
  /// Glyphs occupy ~35% of the circle so they do not crowd the rim.
  static const double searchButton = 28;
  static const double addButton = 30;
  static const double headerGlyph = 11;
  static const double headerGlyphStroke = 1.05;

  static const double dockGlyph = 13;
  static const double dockGlyphStroke = 1.05;
  static const double dockSquircleW = 22;
  static const double dockSquircleH = 18;
  static const double dockSquircleRadius = 6;

  static const double leadingCircle = 20;
  static const double leadingCircleCompact = 18;
  static const double leadingGlyph = 10;
  static const double leadingGlyphCompact = 9;

  static const double sessionBullet = 3.5;
  static const double overflow = 11;
  static const double chevron = 12;

  static const double scheduleStatus = 20;
  static const double scheduleStatusGlyph = 9;

  static const double fileTypeW = 16;
  static const double fileTypeH = 12;
  static const double fileTypeMark = 6.5;

  static const double composerPlus = 13;
  static const double sendRing = 22;
  static const double sendRingStroke = 1.1;
  static const double sendStop = 6;
  static const double scrollFab = 24;
  static const double scrollChevron = 11;

  static const double toolbarGlyph = 11;
  static const double footerGlyph = 12;
}
