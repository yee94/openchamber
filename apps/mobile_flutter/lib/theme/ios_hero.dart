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

  /// Official `.oc-mobile-session-title` is 0.75rem / 1rem / −0.012em.
  /// `.oc-mobile-project-shell` sets `--oc-mobile-session-row-height` to
  /// 2.5rem (40). 40 ≥ 36 touch min, so hit == visual.
  /// Ink is `font-size`; strut is `line-height`. Do not faux-bold CJK.
  static const double rowTitle = 12;
  /// Official CSS is −0.012em. Flutter letterSpacing packs CJK tighter than
  /// the WebView, so paint 0 and keep the 16/12 strut + 40px box.
  static const double rowTitleTracking = 0;
  static const double rowTitleHeight = 16 / 12;
  static const double sessionRowHeight = 46;
  static const double sessionRowVisualHeight = 40;
  /// `.oc-mobile-session-row-main` padding-block 0.3125rem.
  static const double sessionRowPadV = 5;
  static const double moreLinkPadV = 8;
  static const double groupHeaderPadV = 10;
  static const double groupHeaderPadVCompact = 8;
  /// `.oc-mobile-project-shell .oc-mobile-project-trigger`: padding 0.625rem,
  /// gap 0.4375rem. Not the standalone trigger padding 0.75rem.
  static const double projectTriggerPad = 10;
  static const double projectTriggerGap = 7;
  /// Project title column `flex-col gap-1` = 0.25rem. Must not collapse.
  static const double groupTitleMetaGap = 4;
  /// `.oc-mobile-session-row-main` padding-left is 16 (inline style).
  static const double sessionRowPadH = 16;
  static const double sessionRowPadRight = 2;
  /// Official title/subtitle column is `gap-0.5` (2). With padV 5 + 16 + 2
  /// + 12 + 5 the visual row is exactly 40. Do not add extra gap or grow
  /// icons. Air inside the box comes from [sessionLineLeading] on the strut.
  /// CSS `font-size` is the ink; `line-height` is the strut. Do not also
  /// multiply Flutter `TextStyle.height` — that packs CJK into the box.
  /// Official title is `font-medium` / unread `font-semibold`. The review
  /// CJK face is Regular-only, so paint Regular / Medium — do not faux-bold.
  static const double sessionTitleSubtitleGap = 2;
  /// Fraction of the CSS line-height moved into strut `leading` so CJK
  /// glyphs do not fill the 16/12 boxes. Total box stays official —
  /// [ocCssLineBox] must not floor `height` at 1.0 or leading grows the
  /// row instead of opening air inside it.
  static const double sessionLineLeading = 0.395;
  /// `.oc-mobile-session-status` 0.75rem; `.oc-mobile-session-row-main` gap 0.5rem.
  static const double sessionStatus = 12;
  static const double sessionRowMainGap = 8;

  /// `.oc-mobile-project-card` min-height = 4.625rem.
  static const double projectHeaderHeight = 74;
  /// `.oc-mobile-project-groups` padding: 0.125rem 0.75rem 0.875rem.
  static const double projectGroupsPadTop = 2;
  static const double projectGroupsPadInline = 12;
  static const double projectGroupsPadBottom = 14;
  /// `--oc-mobile-project-group-gap` inside the shell.
  static const double projectGroupGap = 10;
  /// `MobileProjectsHome` `gap-5`.
  static const double pageProjectGap = 20;
  /// `.oc-mobile-entity-meta` gap 0.3125rem.
  static const double entityMetaGap = 5;
  /// `.oc-mobile-project-action` margin-right 0.25rem.
  static const double projectActionMargin = 4;
  /// `.oc-mobile-group-label` min-height 2.625rem.
  static const double worktreeLabelMinHeight = 42;
  /// `.oc-mobile-group-label-trigger` padding 0.375rem 0.625rem.
  static const double worktreeLabelPadV = 6;
  static const double worktreeLabelPadLeft = 10;
  /// `.oc-mobile-worktree-label-trigger` padding-right 0.125rem.
  static const double worktreeLabelPadRight = 2;
  static const double worktreeLabelGap = 7;

  /// Root `--oc-mobile-entity-title` 16 / 20. Project-shell tightens to
  /// 0.875rem / 1.125rem / letter-spacing -0.024em.
  static const double entityTitle = 16;
  static const double entityTitleTracking = 0.04;
  static const double entityTitleHeight = 1.25;
  static const double projectTitle = 14;
  static const double projectTitleTracking = -0.336;
  static const double projectTitleHeight = 18 / 14;

  /// `.oc-mobile-entity-meta` 0.75rem / 0.9375rem.
  static const double meta = 12;
  static const double metaTracking = 0;
  static const double metaHeight = 15 / 12;
  /// `.oc-mobile-session-subtitle` / `.oc-mobile-session-time` 0.625rem / 0.75rem.
  static const double sessionTime = 10;
  static const double sessionTimeTracking = 0.0;
  static const double sessionTimeHeight = 12 / 10;
  static const double sessionSubtitle = sessionTime;
  static const double sessionSubtitleHeight = sessionTimeHeight;

  static const double scheduleCardPadV = 10;
  /// Official scheduled meta `mt-1` (4).
  static const double scheduleTitleMetaGap = 4;

  /// Official `.oc-mobile-detail-title` 0.9375rem / line-height 1.4 / weight 650.
  static const double chatTitle = 15;
  static const double chatTitleTracking = 0;
  static const double chatTitleHeight = 1.4;
  static const double detailSubtitle = 10;
  static const double detailSubtitleHeight = 1.4;
  /// Official `.oc-mobile-detail-subtitle` `margin-block-start` 0.125rem.
  static const double detailSubtitleGap = 2;
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

  /// Official `Button` `mobileIcon` is the disc (40). Search is `mobileGlass`,
  /// `+` is primary. Glyph is `size-5` (20).
  static const double searchButton = 40;
  static const double addButton = 40;
  static const double headerDisc = 40;
  /// Official hit is 40 (`mobileIcon`). Painted plate is 36. Search is
  /// surface-elevated + official glass-shadow (near-pair + umbra). No
  /// disc BackdropFilter, no primary + glow.
  static const double headerDiscVisual = 36;
  static const double headerGlyph = 20;
  /// Official `Icon` default stroke (`ICON_STROKE_WIDTH` = 1.5) in the 24 viewBox.
  static const double headerGlyphStroke = 1.5;
  /// Flutter round-cap bloom at dpr 3; paint under official 1.5 so 20px
  /// header glyphs stay thin, not a filled coin stroke.
  static const double headerGlyphStrokeVisual = 1.25;
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
  /// At-rest list peek under the transparent collapsing header. Official
  /// overlay is sticky + transparent; WidgetTester must show catalog under
  /// the plate or the header reads as a solid cream banner.
  static const double headerRestPeek = 20;

  /// `.oc-mobile-root-page-title` letter-spacing: −0.04em + 0.02em × collapse.
  static double rootTitleTracking(double collapse) =>
      largeTitle * (-0.04 + 0.02 * collapse.clamp(0.0, 1.0));

  /// Official dock `Icon` is `size-[23px]` medium. Selected chrome is the
  /// full tab slot (58 tall, radius 29) with `bg-interactive-selection/55`.
  /// Glyph stays visible — wash never replaces it with a primary square.
  static const double dockGlyph = 23;
  /// Official `size-[23px]`. Do not shrink the box — medium weight is the
  /// 23px sprite, not a 21px stand-in.
  static const double dockGlyphVisual = 23;
  /// Official dock `Icon weight="medium"` (`ICON_STROKE_WIDTH_MEDIUM` = 2).
  /// Flutter round-cap bloom at dpr 3; paint 1.55 on stroke frames so
  /// slim filled-medium 23px stays delicate — not bricks, not hairlines.
  static const double dockGlyphStroke = 2;
  static const double dockGlyphStrokeVisual = 1.55;
  /// Slim filled-medium: folder well, calendar grid, hollow gear.
  /// Not 90271 bricks and not stroke-only outlines.
  static const bool dockGlyphFillBodies = true;
  static const bool dockSelectedFullSlot = true;
  static const double dockIconWashAlpha = 0.55;
  /// Cell frost only — nested 20/8 still smeared a second cream well.
  /// Sigma 2 + 55% mix — frost over dock glass, not a cream well.
  static const double dockWashBlur = 2;
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
  /// Official visible more is `min-w-9` + `mr-1`. Open the trailing air a
  /// hair past that so time + ellipsis do not crowd the card edge.
  static const double sessionMoreHit = 36;
  /// Official visible more is `min-w-9` + `mr-1` (4).
  static const double sessionMoreEdge = 4;
  /// Official time cluster `gap-1.5` (6).
  static const double sessionTimeGap = 6;

  static const double sessionBullet = 5;
  static const double overflow = 16;
  static const double chevron = 14;
  /// Official `Button` `mobileIcon` = `size-10` (40). Same disc as header actions.
  static const double chatChip = 40;

  /// Official scheduled status uses the project-shell glass disc, with a
  /// quieter `size-4` glyph so the row does not out-weigh the segment track.
  static const double scheduleStatus = leadingCircle;
  /// Painted plate sits inside the 38 shell so WidgetTester frost is not a coin.
  static const double scheduleStatusVisual = 32;
  /// Official non-tab scheduled glyph is `size-3.5`; shell disc stays 38.
  static const double scheduleStatusGlyph = 14;

  /// Official `FileTypeIcon` mobile size `h-3 w-3` (12px).
  static const double fileTypeSize = 12;
  static const double fileTypeMark = 7;
  static const double fileRowPadV = 3;
  static const double fileRowHeight = 24;
  static const double fileChrome = 11;

  static const double composerRadius = 24;
  /// Official composer attach `Icon name="attachment-2" className="size-5"`.
  static const double composerPlus = 20;
  static const double composerPlusStroke = 1.5;
  /// Official send/stop: `size-8` hit. Idle empty is `send-plane-2` `size-4`
  /// inside the pill (no filled disc). Ready is `SendCircleIcon` `size-6`.
  static const double sendRing = 32;
  static const double sendRingDisc = 24;
  static const double sendRingStroke = 0;
  static const double sendPlane = 16;
  /// Official stop square is 38% of the disc with 20% radius.
  static const double sendStop = 9;
  static const double sendArrow = 13;
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
