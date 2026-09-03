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

  /// Official `.oc-mobile-session-title` is 12 / 16 / −0.012em in a 46px
  /// row. CJK keeps a little positive tracking; pad fills toward 46 without
  /// ballooning 15pt type.
  static const double rowTitle = 13;
  static const double rowTitleTracking = 0.55;
  static const double rowTitleHeight = 1.38;
  static const double sessionRowPadV = 11;
  static const double moreLinkPadV = 8;
  static const double groupHeaderPadV = 12;
  static const double groupHeaderPadVCompact = 10;
  static const double groupTitleMetaGap = 6;

  static const double entityTitle = 16;
  static const double entityTitleTracking = 0.35;
  static const double entityTitleHeight = 1.28;

  static const double meta = 11;
  static const double metaTracking = 0.4;
  static const double metaHeight = 1.45;

  static const double scheduleCardPadV = 14;
  static const double scheduleTitleMetaGap = 8;

  static const double chatTitle = 15;
  static const double chatTitleTracking = 0.7;
  static const double chatTitleHeight = 1.46;
  static const double chatHeaderButton = 24;
  static const double chatBodyHeight = 1.56;
  static const double chatBodyTracking = 0.5;

  static const double dockLabel = 10;
  static const double dockLabelTracking = 0.55;
  static const double dockLabelGap = 4;
  static const double dockCapsuleHeight = 68;
  static const double dockCapsuleRadius = 34;
  static const double dockInnerInset = 5;
  static const double dockTabRadius = 29;
  static const double dockBottomPad = 20;
  static const double dockMaxWidth = 416;

  /// Hit target stays official 2.5rem (40). Painted disc stays thinner than
  /// the 26/32 plates that read as Material.
  static const double searchButton = 40;
  static const double addButton = 40;
  static const double headerDisc = 24;
  static const double headerGlyph = 11;
  static const double headerGlyphStroke = 0.42;
  /// In-card / dock / footer glyphs — thinner than header strokes.
  static const double listGlyphStroke = 0.34;

  /// `--oc-mobile-collapsing-action-size` / expand-shift / collapse distance.
  static const double collapsingActionSize = 40;
  static const double collapsingTopPad = 12;
  static const double collapsingExpandShift = 10;
  static const double titleCollapseDistance = 48;
  static const double titleCollapseScaleEnd = 0.625;

  static const double dockGlyph = 6;
  static const double dockGlyphStroke = 0.34;
  /// Soft selected wash behind the dock **icon only** — faint stadium +
  /// feathered glow, not a coarse peach disc and not a full-slot wash.
  static const double dockIconPillWidth = 30;
  static const double dockIconPillHeight = 18;
  static const double dockIconPillRadius = 9;
  static const double dockIconWashAlpha = 0.07;
  static const double dockIconGlowAlpha = 0.04;
  static const double dockIconGlowBlur = 8;

  static const double leadingCircle = 9;
  static const double leadingCircleCompact = 8;
  static const double leadingGlyph = 4;
  static const double leadingGlyphCompact = 3.5;

  static const double sessionBullet = 2;
  static const double overflow = 5;
  static const double chevron = 6;

  static const double scheduleStatus = 9;
  static const double scheduleStatusGlyph = 3.5;

  static const double fileTypeW = 8;
  static const double fileTypeH = 5;
  static const double fileTypeMark = 2.75;
  static const double fileRowPadV = 5;

  static const double composerRadius = 26;
  static const double composerPlus = 6;
  static const double sendRing = 17;
  static const double sendRingStroke = 0.50;
  static const double sendStop = 4;
  static const double scrollFab = 15;
  static const double scrollChevron = 6;

  static const double toolbarGlyph = 6;
  static const double footerGlyph = 6;
}
