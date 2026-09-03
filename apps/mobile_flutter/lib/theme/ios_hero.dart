/// Official `packages/ui/src/styles/mobile.css` rem tokens, in px at 16.
///
/// Colors stay on [OcTokens] (design-system orange / sand). Do not free-tune
/// these knobs. WidgetTester cannot paint `UIGlassEffect`.
class OcOptical {
  const OcOptical._();

  /// Official `.oc-mobile-root-page-title`: 2rem / 1.2 / −0.04em, semibold.
  static const double largeTitle = 32;
  static const double largeTitleTracking = -1.28;
  static const double largeTitleHeight = 1.2;

  /// Official `.oc-mobile-session-title` is 12 / 16 / −0.012em.
  /// Root `--oc-mobile-session-row-height` is 2.875rem (46). Projects home and
  /// scheduled cards sit in `.oc-mobile-project-shell`, which tightens the
  /// visual slot to 2.5rem (40). 40 ≥ 36 touch min, so hit == visual — no
  /// extra outer pad (that would balloon the card).
  static const double rowTitle = 12;
  static const double rowTitleTracking = -0.14;
  static const double rowTitleHeight = 1.33;
  static const double sessionRowHeight = 46;
  static const double sessionRowVisualHeight = 40;
  static const double sessionRowPadV = 5;
  static const double moreLinkPadV = 8;
  static const double groupHeaderPadV = 10;
  static const double groupHeaderPadVCompact = 8;
  /// Official project-shell `.oc-mobile-project-trigger` padding / gap.
  static const double projectTriggerPad = 10;
  static const double projectTriggerGap = 7;
  /// Official title column `gap-1` (4). Meta chips use 0.3125rem horizontally.
  static const double groupTitleMetaGap = 4;
  static const double sessionRowPadH = 12;

  /// Root `--oc-mobile-entity-title` 16 / 20. Project-shell tightens to 14 / 18.
  static const double entityTitle = 16;
  static const double entityTitleTracking = 0.04;
  static const double entityTitleHeight = 1.25;
  static const double projectTitle = 14;
  static const double projectTitleTracking = -0.34;
  static const double projectTitleHeight = 1.29;

  static const double meta = 12;
  static const double metaTracking = 0.02;
  static const double metaHeight = 1.25;
  static const double sessionTime = 10;
  static const double sessionTimeTracking = 0.0;
  static const double sessionTimeHeight = 1.2;

  static const double scheduleCardPadV = 10;
  static const double scheduleTitleMetaGap = 5;

  /// Official `.oc-mobile-detail-title` 0.9375rem / line-height 1.4 / weight 650.
  static const double chatTitle = 15;
  static const double chatTitleTracking = 0;
  static const double chatTitleHeight = 1.4;
  static const double detailSubtitle = 10;
  static const double detailSubtitleHeight = 1.4;
  static const double detailNavigationHeight = 56;
  static const double detailActionEdgeInset = 16;
  static const double detailActionColumn = 44;
  static const double headerFadeExtra = 28;
  static const double headerFadeMidStop = 0.35;
  static const double chatHeaderButton = 28;
  static const double chatBodyHeight = 1.45;
  static const double chatBodyTracking = 0;

  /// Official `.oc-mobile-tab-button` 0.75rem / line-height 0.75rem / tracking-tight.
  static const double dockLabel = 12;
  static const double dockLabelTracking = -0.3;
  static const double dockLabelHeight = 1.0;
  static const double dockLabelGap = 3;
  static const double dockGap = 3;
  static const double dockCapsuleHeight = 68;
  static const double dockCapsuleRadius = 34;
  static const double dockInnerInset = 5;
  static const double dockTabHeight = 58;
  static const double dockTabRadius = 29;
  static const double dockBottomPad = 20;
  static const double dockMaxWidth = 416;

  /// Official `Button` `mobileIcon` is the disc (40). Search is `mobileGlass`
  /// (light plate + outside shadow), `+` is primary round. Glyph is `size-5`.
  /// Hit area is the disc; visual glyph is [headerGlyph].
  static const double searchButton = 40;
  static const double addButton = 40;
  static const double headerDisc = 40;
  static const double headerGlyph = 20;
  /// Official `Icon` default stroke (`ICON_STROKE_WIDTH` = 1.5) in the 24 viewBox.
  static const double headerGlyphStroke = 1.5;
  /// In-card / list `Icon` regular weight — same 24-viewBox 1.5 as header.
  static const double listGlyphStroke = 1.5;
  /// Search-field prefix `Icon name="search" className="size-4"`.
  static const double searchFieldGlyph = 16;

  /// Official `.oc-mobile-collapsing-header` — exact rem tokens, not optical guesses.
  static const double collapsingActionSize = 40;
  static const double collapsingTitleCompactSize = 20;
  static const double collapsingTopPad = 12;
  static const double collapsingExpandShift = 10;
  static const double collapsingInnerGap = 16;
  static const double collapsingTrailingGap = 14;
  static const double collapsingInlineExtra = 4;
  static const double titleCollapseDistance = 48;
  static const double titleCollapseScaleReduce = 0.375;
  static const double titleCollapseScaleEnd = 0.625;
  static const double pageScrollBottomExtra = 40;

  /// `.oc-mobile-root-page-title` letter-spacing: −0.04em + 0.02em × collapse.
  static double rootTitleTracking(double collapse) =>
      largeTitle * (-0.04 + 0.02 * collapse.clamp(0.0, 1.0));

  /// Official dock `Icon` is `size-[23px]` medium. Selected chrome is the
  /// full tab slot (icon + label), matching `.oc-mobile-tab-button`.
  static const double dockGlyph = 23;
  /// Official dock `Icon weight="medium"` (`ICON_STROKE_WIDTH_MEDIUM` = 2).
  static const double dockGlyphStroke = 2;
  static const bool dockSelectedFullSlot = true;
  static const double dockIconWashAlpha = 0.55;
  static const double dockIconGlowAlpha = 0.0;
  static const double dockIconGlowBlur = 0;

  /// Official project-shell icon 2.375rem; glyph `1.125rem` (18) `code-box`.
  /// Worktree label: `.oc-mobile-group-label-icon` 1.125rem box + `git-branch`
  /// `size-3.5` (14). Hit areas (36/40) stay separate from these visuals.
  static const double leadingCircle = 38;
  static const double leadingCircleCompact = 22;
  static const double leadingGlyph = 18;
  static const double leadingGlyphCompact = 14;
  static const double worktreeIconBox = 18;
  static const double worktreeGlyph = 14;
  /// Session / worktree `more-2` `size-3.5`. Project action is `size-4`.
  static const double sessionMore = 14;

  static const double sessionBullet = 5;
  static const double overflow = 16;
  static const double chevron = 14;
  /// Official `Button` `mobileIcon` = `size-10` (40). Same disc as header actions.
  static const double chatChip = 40;

  static const double scheduleStatus = 28;
  static const double scheduleStatusGlyph = 12;

  /// Official `FileTypeIcon` mobile size `h-3 w-3` (12px).
  static const double fileTypeSize = 16;
  static const double fileTypeMark = 8;
  static const double fileRowPadV = 4;

  static const double composerRadius = 24;
  /// Official composer attach `Icon name="attachment-2" className="size-5"`.
  static const double composerPlus = 20;
  static const double composerPlusStroke = 1.5;
  static const double sendRing = 32;
  static const double sendRingStroke = 0;
  static const double sendStop = 12;
  static const double scrollFab = 36;
  static const double scrollChevron = 16;
  static const double scrollChevronStroke = 2.4;
  static const double glassBlur = 20;

  static const double toolbarGlyph = 16;
  /// Official `MESSAGE_ACTION_ICON_CLASS` `size-3.5` / medium stroke.
  static const double footerGlyph = 14;
  static const double footerGlyphStroke = 2;
  /// Official `MESSAGE_FOOTER_META_CLASS` `text-[11px] leading-none`.
  static const double footerMeta = 11;
  static const double footerMetaHeight = 1.0;
}
