import 'package:flutter/material.dart';

import '../features/projects/highlighted_text.dart';
import '../theme/ios_chrome.dart';

/// Official `MobileTabPageHeader` — shared root-tab chrome.
///
/// Source: `packages/ui/src/mobile/MobileTabPageHeader.tsx` +
/// `packages/ui/src/styles/mobile.css` `.oc-mobile-collapsing-header*`.
///
/// Layout height is FIXED (`safe-area + 0.75rem + 2.5rem`). Background is
/// transparent. Scroll only drives compositor props (title scale 1→0.625,
/// inner translateY, fade opacity, letter-spacing). The 0.625rem spacer and
/// official `--oc-mobile-page-gap` clearance live in [MobileTabPageScaffold]
/// as real siblings — not folded into padding, not a per-tab restPeek.
class MobileTabPageHeader extends StatelessWidget {
  const MobileTabPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.collapse = 0,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  /// 0 expanded → 1 collapsed. Never changes this widget's layout height.
  final double collapse;

  static const double collapseDistance = OcOptical.titleCollapseDistance;
  static const double actionSize = OcOptical.collapsingActionSize;
  static const double topPad = OcOptical.collapsingTopPad;
  static const double expandShift = OcOptical.collapsingExpandShift;

  static double layoutHeight(double safeAreaTop) => safeAreaTop + topPad + actionSize;

  static Widget layoutSlot({required double safeTop}) {
    return SizedBox(
      key: const Key('mobile-tab-page-header-slot'),
      height: layoutHeight(safeTop),
    );
  }

  static const expandShiftSpacer = SizedBox(
    key: Key('mobile-tab-page-header-spacer'),
    height: expandShift,
  );

  /// Official `MobileTabPageHeader` is a fragment (sticky header + 10px
  /// spacer). `MobileProjectsHome` / `.oc-mobile-tab-page` `gap-5` (20)
  /// sits between each flattened flex item: header → 20 → spacer → 20 →
  /// content. Structural air after the header box is 20+10+20 = 50.
  /// [OcOptical.pageProjectGap] is card-stack only. `headerRestPeek` stays 0.
  static const leadingPageGap = SizedBox(
    key: Key('mobile-tab-page-header-leading-gap'),
    height: OcTokens.pageGap,
  );

  /// Official `.oc-mobile-tab-page` / Projects `gap-5` after the spacer
  /// (`--oc-mobile-page-gap` = 1.25rem). Shared large-title 空档 for every
  /// root tab — not [OcOptical.pageProjectGap] card-stack spacing.
  static const double titleClearanceHeight = OcTokens.pageGap;

  static const titleClearance = SizedBox(
    key: Key('mobile-tab-page-header-clearance'),
    height: titleClearanceHeight,
  );

  /// Official flattened fragment + `gap-5`: 20 + 10 + 20.
  static const double titleBandAir = OcTokens.pageGap + expandShift + OcTokens.pageGap;

  static double fadeHeight(double safeAreaTop) => OcHeaderFade.heightFor(safeAreaTop);

  static double collapseProgress({required double offset, required bool reduceMotion}) {
    final raw = (offset / collapseDistance).clamp(0.0, 1.0);
    return reduceMotion ? (raw >= 0.5 ? 1.0 : 0.0) : raw;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    final t = collapse.clamp(0.0, 1.0);
    final fadeH = fadeHeight(safeTop);
    final headerH = layoutHeight(safeTop);

    return SizedBox(
      key: const Key('mobile-tab-page-header'),
      height: headerH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerH,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.55 + (0.25 * t),
                child: OcFrosted(
                  fill: tokens.glassFill.withValues(alpha: tokens.isDark ? 0.32 : 0.26),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: fadeH,
            child: OcHeaderFade(safeTop: safeTop, opacity: t),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              OcChrome.pageGutter + OcOptical.collapsingInlineExtra,
              safeTop + topPad,
              OcChrome.pageGutter + OcOptical.collapsingInlineExtra,
              0,
            ),
            child: Transform.translate(
              offset: Offset(0, expandShift * (1 - t)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: actionSize,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (eyebrow != null)
                            Opacity(
                              opacity: 1 - t,
                              child: Transform.scale(
                                alignment: Alignment.topLeft,
                                scaleY: 1 - t,
                                child: Text(
                                  eyebrow!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: OcTokens.textMicro,
                                    fontWeight: FontWeight.w400,
                                    color: tokens.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          Transform.scale(
                            key: const Key('mobile-tab-page-title'),
                            alignment: Alignment.centerLeft,
                            scale: 1 - (OcOptical.titleCollapseScaleReduce * t),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  for (final run in scriptRuns(title))
                                    TextSpan(
                                      text: run.text,
                                      style: run.cjk && !ocLiveIosType
                                          ? const TextStyle(fontWeight: FontWeight.w400)
                                          : null,
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: OcOptical.largeTitle,
                                // Official `.oc-mobile-root-page-title` is
                                // font-semibold. Latin keeps ReviewSans
                                // Medium. WidgetTester / Android CJK uses
                                // Regular Micro Hei (32px DemiLight@500
                                // bricks vs PingFang Semibold). Live iOS
                                // inherits this w600 so PingFang SC
                                // Semibold paints. Session/card stay
                                // DemiLight on the tester path.
                                fontWeight: FontWeight.w600,
                                letterSpacing: OcOptical.rootTitleTracking(t),
                                height: OcOptical.largeTitleHeight,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: OcOptical.collapsingInnerGap),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: actionSize),
                      child: trailing,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
