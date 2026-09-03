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

  /// Large titles stay open. Nested session / file rows keep open CJK
  /// tracking and leading (README air), not official CSS `-0.024em`.
  /// Glyph sizes stay small; colors stay on [OcTokens].
  static const double rowTitle = 15;
  static const double rowTitleTracking = 0.9;
  static const double rowTitleHeight = 1.46;
  static const double sessionRowPadV = 7;
  static const double moreLinkPadV = 6;
  static const double groupHeaderPadV = 12;
  static const double groupHeaderPadVCompact = 10;
  static const double groupTitleMetaGap = 8;

  static const double entityTitle = 16;
  static const double entityTitleTracking = 1.15;
  static const double entityTitleHeight = 1.46;

  static const double meta = 13;
  static const double metaTracking = 0.9;
  static const double metaHeight = 1.7;

  static const double scheduleCardPadV = 14;
  static const double scheduleTitleMetaGap = 11;

  static const double chatTitle = 15;
  static const double chatTitleTracking = 0.6;
  static const double chatTitleHeight = 1.42;
  static const double chatHeaderButton = 24;
  static const double chatBodyHeight = 1.5;
  static const double chatBodyTracking = 0.4;

  static const double dockLabel = 10;
  static const double dockLabelTracking = 0.55;
  static const double dockLabelGap = 4;
  static const double dockCapsuleHeight = 68;
  static const double dockCapsuleRadius = 34;
  static const double dockInnerInset = 5;
  static const double dockTabRadius = 29;
  static const double dockBottomPad = 20;
  static const double dockMaxWidth = 416;

  /// Hit target stays official 2.5rem (40). Painted disc and glyph are
  /// smaller so search / + do not read as heavy glass plates.
  static const double searchButton = 40;
  static const double addButton = 40;
  static const double headerDisc = 32;
  static const double headerGlyph = 16;
  static const double headerGlyphStroke = 0.65;
  /// In-card / dock / footer glyphs — thinner than header strokes.
  static const double listGlyphStroke = 0.55;

  /// `--oc-mobile-collapsing-action-size` / expand-shift / collapse distance.
  static const double collapsingActionSize = 40;
  static const double collapsingTopPad = 12;
  static const double collapsingExpandShift = 10;
  static const double titleCollapseDistance = 48;
  static const double titleCollapseScaleEnd = 0.625;

  static const double dockGlyph = 7;
  static const double dockGlyphStroke = 0.55;
  /// Soft selected wash behind the dock **icon only** — not the whole slot.
  static const double dockIconPill = 24;
  static const double dockIconPillRadius = 12;

  static const double leadingCircle = 11;
  static const double leadingCircleCompact = 9;
  static const double leadingGlyph = 5;
  static const double leadingGlyphCompact = 4;

  static const double sessionBullet = 2.5;
  static const double overflow = 6;
  static const double chevron = 7;

  static const double scheduleStatus = 11;
  static const double scheduleStatusGlyph = 4;

  static const double fileTypeW = 9;
  static const double fileTypeH = 6;
  static const double fileTypeMark = 3.5;
  static const double fileRowPadV = 4;

  static const double composerRadius = 22;
  static const double composerPlus = 8;
  static const double sendRing = 17;
  static const double sendRingStroke = 0.85;
  static const double sendStop = 4.5;
  static const double scrollFab = 16;
  static const double scrollChevron = 7;

  static const double toolbarGlyph = 7;
  static const double footerGlyph = 7;
}
