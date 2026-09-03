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

  /// Official `.oc-mobile-session-title` is 12 / 16 / −0.012em in
  /// `--oc-mobile-session-row-height` (2.875rem = 46). CJK keeps a little
  /// positive tracking; pad is official 5px and min-height fills the slot.
  static const double rowTitle = 12;
  static const double rowTitleTracking = 0.2;
  static const double rowTitleHeight = 1.333;
  static const double sessionRowHeight = 46;
  static const double sessionRowPadV = 5;
  static const double moreLinkPadV = 8;
  static const double groupHeaderPadV = 10;
  static const double groupHeaderPadVCompact = 10;
  static const double groupTitleMetaGap = 4;

  /// Root `--oc-mobile-entity-title` 16 / 20. Project-shell tightens to 14 / 18.
  static const double entityTitle = 16;
  static const double entityTitleTracking = 0.2;
  static const double entityTitleHeight = 1.25;
  static const double projectTitle = 14;
  static const double projectTitleTracking = 0.2;
  static const double projectTitleHeight = 1.286;

  static const double meta = 13;
  static const double metaTracking = 0.15;
  static const double metaHeight = 1.23;
  static const double sessionTime = 10;
  static const double sessionTimeTracking = 0.15;
  static const double sessionTimeHeight = 1.2;

  static const double scheduleCardPadV = 12;
  static const double scheduleTitleMetaGap = 4;

  static const double chatTitle = 15;
  static const double chatTitleTracking = 0.4;
  static const double chatTitleHeight = 1.33;
  static const double chatHeaderButton = 28;
  static const double chatBodyHeight = 1.56;
  static const double chatBodyTracking = 0.35;

  static const double dockLabel = 12;
  static const double dockLabelTracking = 0.2;
  static const double dockLabelGap = 3;
  static const double dockCapsuleHeight = 68;
  static const double dockCapsuleRadius = 34;
  static const double dockInnerInset = 5;
  static const double dockTabRadius = 29;
  static const double dockBottomPad = 20;
  static const double dockMaxWidth = 416;

  /// Official `Button` `mobileIcon` is the disc (40). Search is `mobileGlass`
  /// (light plate + outside shadow), `+` is primary round. Glyph is `size-5`.
  static const double searchButton = 40;
  static const double addButton = 40;
  static const double headerDisc = 40;
  static const double headerGlyph = 18;
  static const double headerGlyphStroke = 0.85;
  /// In-card / dock / footer strokes stay thinner than header.
  static const double listGlyphStroke = 0.70;

  /// `--oc-mobile-collapsing-action-size` / expand-shift / collapse distance.
  static const double collapsingActionSize = 40;
  static const double collapsingTopPad = 12;
  static const double collapsingExpandShift = 10;
  static const double titleCollapseDistance = 48;
  static const double titleCollapseScaleEnd = 0.625;

  /// Official dock icon is `size-[23px]` medium. Stroke glyphs stay smaller
  /// and lighter so they do not read heavier than the sprite. Selected
  /// chrome is an icon-only wash — never a full-slot slab.
  static const double dockGlyph = 15;
  static const double dockGlyphStroke = 0.72;
  static const double dockIconPillWidth = 30;
  static const double dockIconPillHeight = 22;
  static const double dockIconPillRadius = 11;
  static const double dockIconWashAlpha = 0.06;
  static const double dockIconGlowAlpha = 0.035;
  static const double dockIconGlowBlur = 8;

  /// `.oc-mobile-project-shell` icon 2.375rem; in-card glyph stays thinner
  /// than the official 18px filled sprite.
  static const double leadingCircle = 38;
  static const double leadingCircleCompact = 28;
  static const double leadingGlyph = 13;
  static const double leadingGlyphCompact = 10;

  static const double sessionBullet = 5;
  static const double overflow = 11;
  static const double chevron = 11;

  static const double scheduleStatus = 38;
  static const double scheduleStatusGlyph = 13;

  static const double fileTypeW = 11;
  static const double fileTypeH = 7;
  static const double fileTypeMark = 3.5;
  static const double fileRowPadV = 6;

  static const double composerRadius = 24;
  static const double composerPlus = 12;
  static const double sendRing = 28;
  static const double sendRingStroke = 0.90;
  static const double sendStop = 8;
  static const double scrollFab = 26;
  static const double scrollChevron = 9;

  static const double toolbarGlyph = 11;
  static const double footerGlyph = 11;
}
