/// Official `packages/ui/src/styles/mobile.css` rem tokens, in px at 16.
///
/// Colors stay on [OcTokens] (design-system orange / sand). Do not free-tune
/// these knobs. Live iOS 26 dock/composer use UIKit `UIGlassEffect`.
/// WidgetTester and Android paint [BackdropFilter] through-plates — a
/// degrade, not a Flutter `UIGlassEffect` clone.
class OcOptical {
  const OcOptical._();

  /// Official `.oc-mobile-root-page-title`: 2rem / 1.2 / −0.04em, semibold.
  static const double largeTitle = 32;
  static const double largeTitleTracking = -1.28;
  static const double largeTitleHeight = 1.2;

  /// Official `.oc-mobile-session-title` is 0.75rem / 1rem / −0.012em.
  /// `.oc-mobile-project-shell` sets `--oc-mobile-session-row-height` to
  /// 2.5rem (40). Tiny CJK half-lead only — do not invent 7.5/70 air.
  /// Ink is `font-size`; strut is `line-height`. Do not faux-bold CJK.
  static const double rowTitle = 12;
  /// Official CSS is −0.012em. Flutter letterSpacing packs CJK tighter than
  /// the WebView, so paint 0 and keep the 16/12 CSS boxes.
  static const double rowTitleTracking = 0;
  static const double rowTitleHeight = 16 / 12;
  static const double sessionRowHeight = 46;
  /// Official project-shell row is 40. 2.5px CJK half-lead (per side)
  /// opens 12px title/subtitle without leaving the 40-class — never
  /// 7.5 half-lead / 70px rows.
  static const double sessionRowVisualHeight = 50;
  /// `.oc-mobile-session-row-main` padding-block 0.3125rem (5).
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
  /// Official title/subtitle column is `gap-0.5` (2). Keep that; do not
  /// invent extra title↔meta gap or 15px empty air per line.
  /// Official title is `font-medium` / unread `font-semibold`. Review CJK
  /// has no Medium cut; stem 2.0 + 0.6 cardinal shade keep Regular 12px
  /// on authored foreground. Card frost must sit behind the child —
  /// wrapping ink in `floatSurface` 0.45 floors cores at ~L 129. Not a
  /// 0.02 stem series and not more half-lead.
  static const double sessionTitleStem = 2.0;
  static const double sessionTitleShade = 0.6;
  static const double sessionTitleSubtitleGap = 2;
  /// Official CSS half-leading already lives in the 16/12 boxes (2px / 1px).
  /// 2.5 extra Flutter pixels open Regular CJK without leaving ~40 density.
  static const double cssLineCjkHalfLead = 2.5;
  /// Fraction of the CSS line-height moved into strut `leading`. This
  /// review CJK face ignores strut `leading` (0.52–0.57 goldens stayed
  /// byte-identical). Prefer [OcCssLine] + [cssLineCjkHalfLead].
  static const double sessionLineLeading = 0.57;
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
  /// Official entity title is −0.024em. Flutter Regular CJK packs
  /// tighter than the WebView — paint 0 (session-row precedent).
  static const double projectTitleTracking = 0;
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

  /// Official scheduled mobile tab `space-y-4` between floating cards.
  static const double floatCardStackGap = 16;
  /// Official scheduled task row `p-3` (12).
  static const double scheduleCardPadV = 12;
  /// Official scheduled meta `mt-1` (4). Title air is the CSS 18px box,
  /// not extra half-lead or a second invented gap.
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
  /// Official `tracking-tight`. Flutter Regular CJK packs tighter than
  /// the WebView — paint 0 so dock labels stay open (session-row precedent).
  static const double dockLabelTracking = 0;
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
  /// Official hit is 40 (`mobileIcon`). Search frost plate is 36 — through
  /// `glassChipThrough` 0.22 / σ14, not a 0.68 coin and not a 22 bleed
  /// glyph. Solid primary `+` paints the full 40 hit. No 8/20 umbra.
  static const double headerDiscVisual = 36;
  /// Official `size-5` is 20. Flutter round-cap bloom; paint 14 in the
  /// 36 frost plate so search / ink glyphs are not massy coins.
  static const double headerGlyph = 14;
  /// Official `Icon` default stroke (`ICON_STROKE_WIDTH` = 1.5) in the 24 viewBox.
  static const double headerGlyphStroke = 1.5;
  /// Flutter round-cap bloom at dpr 3; paint under official 1.5 so search
  /// glass stays a thin glyph, not a massy coin.
  static const double headerGlyphStrokeVisual = 0.48;
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

  /// Official `--oc-settings-group-radius` 1rem. Not project 1.5rem.
  static const double settingsGroupRadius = 16;
  /// Official `--oc-settings-row-min-height` 3.25rem.
  static const double settingsRowMinHeight = 52;
  static const double settingsRowGap = 10;
  static const double settingsRowInset = 14;
  /// Official `.oc-mobile-settings-search-field` min-height 2.75rem.
  static const double settingsSearchMinHeight = 44;
  /// Official nav `Icon` `h-4 w-4`.
  static const double settingsNavIcon = 16;

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
  /// Flutter round-cap bloom at dpr 3; paint under 2 so slim filled-medium
  /// 23px stays delicate — not bricks, not hairlines.
  static const double dockGlyphStroke = 2;
  /// Official medium is 2; Flutter round-cap bloom at dpr 3. Paint under
  /// 1 so calendar/gear stay filled-medium sprites, not bricks.
  static const double dockGlyphStrokeVisual = 0.56;
  /// Folder / sparkles stay official medium stroke but paint lighter
  /// than calendar/gear so the 23px outline is not a brick.
  static const double dockStrokeGlyphStrokeVisual = 0.50;
  /// Official filled-medium 23px sprites: folder / sparkles / calendar
  /// grid / holed gear. Not hairline outlines and not brick mass.
  static const bool dockGlyphFillBodies = true;
  static const bool dockSelectedFullSlot = true;
  /// Official selected class is `bg-interactive-selection/55`.
  /// Mix only (no nested frost) so the 58×r29 cell is a through-wash.
  /// Do not use RGB@0.55 or a second BackdropFilter.
  static const double dockIconWashAlpha = 0.55;
  /// Official selected tab is `bg-interactive-selection/55` on already-
  /// frosted dock glass — no second BackdropFilter. Nested sigma painted
  /// a cream plate that hid the list. 0 = mix only so rows show through.
  static const double dockWashBlur = 0;
  /// Official `--oc-mobile-glass-blur` on the 36 `mobileGlass` disc.
  static const double chipBlur = 20;
  /// Chip frost sigma. Official [chipBlur] is 20; WidgetTester cream +
  /// 20 paints a coin. 14 + fill 0.34 is a mobileGlass frost plate —
  /// not a bare glyph and not a 0.68 cream disc.
  static const double chipBleedBlur = 14;
  /// Official `.oc-mobile-floating-surface` `blur(22px) saturate(1.35)`.
  /// Distinct from control-scale [chipBlur] / [glassSaturate].
  static const double floatBlur = 22;
  static const double floatSaturate = 1.35;
  static const double dockIconGlowAlpha = 0.0;
  static const double dockIconGlowBlur = 0;

  /// Official project-shell icon 2.375rem; glyph `1.125rem` (18) `code-box`.
  /// Worktree label: `.oc-mobile-group-label-icon` 1.125rem box + `git-branch`
  /// `size-3.5` (14). Hit areas (36/40) stay separate from these visuals.
  static const double leadingCircle = 38;
  /// Painted plate inside the official 38 shell so project leading
  /// discs are not oversized coins (wake-0905).
  static const double leadingCircleVisual = 32;
  static const double leadingCircleCompact = 22;
  /// Official `.oc-mobile-project-shell .oc-mobile-project-icon-glyph` is
  /// 1.125rem (18). Flutter CustomPaint blooms past the web SVG; paint
  /// [leadingGlyphVisual] inside the official 38/32 hit/plate.
  static const double leadingGlyph = 18;
  static const double leadingGlyphVisual = 14;
  static const double leadingGlyphCompact = 14;
  static const double worktreeIconBox = 18;
  /// Official worktree `git-branch` is `size-3.5` (14). Paint [worktreeGlyphVisual]
  /// inside the 18 box so the sprite matches the web scale.
  static const double worktreeGlyph = 14;
  static const double worktreeGlyphVisual = 12;
  /// Session / worktree `more-2` `size-3.5`. Project action is `size-4`.
  static const double sessionMore = 12;
  /// Official visible more is `min-w-9` + `mr-1`. Open the trailing air a
  /// hair past that so time + ellipsis do not crowd the card edge.
  static const double sessionMoreHit = 36;
  /// Official visible more is `min-w-9` + `mr-1` (4).
  static const double sessionMoreEdge = 4;
  /// Official time cluster `gap-1.5` (6).
  static const double sessionTimeGap = 6;

  static const double sessionBullet = 5;
  /// Official read-dot is `bg-muted-foreground/35`. On cream that washes
  /// into the card — raise so the status bullet stays scannable.
  static const double sessionBulletReadAlpha = 0.55;
  static const double overflow = 16;
  static const double chevron = 14;
  /// Official `Button` `mobileIcon` disc (40). Residual 44 outweighed
  /// the 56px detail band — paint the official hit so back / busy / more
  /// are chips, not oversized coins.
  static const double chatChip = 40;
  /// Official chip glyph is `size-4` (16). Flutter bloom; paint 14 so
  /// back / ··· stay thin in the 40 frost disc.
  static const double chatChipGlyph = 14;

  /// Official scheduled status uses the project-shell glass disc (2.375rem).
  static const double scheduleStatus = leadingCircle;
  /// Hit stays official 38. Paint the same 32 plate as project leading
  /// so the status disc is not a massy coin on the card.
  static const double scheduleStatusVisual = 32;
  /// Official non-tab scheduled glyph is `size-3.5`; residual optical
  /// paints 12 so the badge does not outweigh the segment track.
  static const double scheduleStatusGlyph = 12;
  /// Quiet status polish: 12px check/pause at header visual stroke so
  /// the 38 disc does not outweigh the card title.
  static const double scheduleStatusGlyphStroke = headerGlyphStrokeVisual;

  /// Official `FileTypeIcon` mobile size `h-3 w-3` (12px).
  static const double fileTypeSize = 12;
  /// Flutter round-cap bloom at 12px; paint under official 1.5.
  static const double fileTypeStrokeVisual = headerGlyphStrokeVisual;
  static const double fileTypeMark = 7;
  static const double fileRowPadV = 3;
  static const double fileRowHeight = 24;
  static const double fileChrome = 11;

  /// Official mobile composer textarea `py-2.5` (10).
  static const double composerFieldPadV = 10;
  /// Pill chrome around the field — not float-shadow (official `none`).
  static const double composerPillPadV = 8;
  static const double composerRadius = 24;
  /// Official composer attach `Icon name="attachment-2" className="size-5"`.
  static const double composerPlus = 18;
  static const double composerPlusStroke = 1.25;
  /// Official send/stop: `size-8` hit. Idle empty is `send-plane-2` `size-4`
  /// inside the pill (no filled disc). Ready is `SendCircleIcon` `size-6`.
  static const double sendRing = 32;
  static const double sendRingDisc = 24;
  static const double sendRingStroke = 1.0;
  /// Official idle send is the plane only (`size-4`, no disc). Keep a
  /// faint 24 ring so the hit reads as a control, not a massy coin.
  static const double sendRingIdleAlpha = 0.32;
  static const double sendPlane = 16;
  /// Official stop square is 38% of the disc with 20% radius.
  static const double sendStop = 9;
  static const double sendArrow = 13;
  static const double scrollFab = 36;
  static const double scrollChevron = 16;
  static const double scrollChevronStroke = 1.8;
  static const double glassBlur = 20;
  /// Official `--oc-mobile-glass-saturate` (light 1.25).
  static const double glassSaturate = 1.25;

  static const double toolbarGlyph = 16;
  /// Official `MESSAGE_ACTION_ICON_CLASS` `size-3.5` / medium stroke.
  static const double footerGlyph = 14;
  static const double footerGlyphStroke = 2;
  /// Official medium is 2; Flutter bloom at dpr 3. Paint under 2 so
  /// copy / fork / clock stay filled-medium, not chunky bricks.
  static const double footerGlyphStrokeVisual = 0.56;
  /// Official ProgressiveGroup expanded rail: header must not sit flush
  /// on the first skill/terminal row (Yee P0 2026-09-04).
  static const double activityExpandedGap = 10;
  /// Official expanded rail `ml-2 pl-3` (8 + 12).
  static const double activityExpandedIndent = 20;
  /// Official skill-group expanded children `ml-2 pl-3` inner inset.
  static const double activityChildIndent = 12;
  static const double activityRowGap = 4;
  /// Official tool-row icon `size-3.5`.
  static const double toolRowGlyph = 14;
  /// Official `MESSAGE_FOOTER_META_CLASS` `text-[11px] leading-none`.
  static const double footerMeta = 11;
  static const double footerMetaHeight = 1.0;
}
