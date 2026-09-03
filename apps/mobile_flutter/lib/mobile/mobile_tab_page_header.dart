import 'package:flutter/material.dart';

import '../theme/ios_chrome.dart';

/// Official `MobileTabPageHeader` — shared root-tab chrome.
///
/// Source: `packages/ui/src/mobile/MobileTabPageHeader.tsx` +
/// `packages/ui/src/styles/mobile.css` `.oc-mobile-collapsing-header*`.
///
/// Layout height is FIXED (`safe-area + 0.75rem + 2.5rem`). Background is
/// transparent. Scroll only drives compositor props (title scale 1→0.625,
/// inner translateY, fade opacity). The 0.625rem spacer lives in
/// [MobileTabPageScaffold], not here.
///
/// iOS: this widget does **not** paint a Flutter blur/glass rectangle. Tab-bar
/// translucency stays on the existing UIKit `UITabBar` overlay. The collapse
/// fade is the official `--oc-mobile-header-fade` color-mix (WidgetTester and
/// Android goldens are solid, not `UIVisualEffect`).
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

  /// In-flow clearance so overlay chrome does not cover the first card at rest.
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

  static double fadeHeight(double safeAreaTop) {
    // Official: safe-area + --oc-mobile-detail-navigation-height (3.5rem) + 1.75rem.
    return safeAreaTop + 56 + 28;
  }

  static double collapseProgress({required double offset, required bool reduceMotion}) {
    final raw = (offset / collapseDistance).clamp(0.0, 1.0);
    return reduceMotion ? (raw >= 0.5 ? 1.0 : 0.0) : raw;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final safeTop = MediaQuery.paddingOf(context).top;
    final t = collapse.clamp(0.0, 1.0);
    final fade = tokens.background.withValues(alpha: 0.85);
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
            height: fadeH,
            child: IgnorePointer(
              child: Opacity(
                opacity: t,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [fade, fade, fade.withValues(alpha: 0)],
                      stops: [
                        0,
                        ((safeTop + fadeH * 0.35) / fadeH).clamp(0.0, 1.0),
                        1,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              OcChrome.pageGutter + 4,
              safeTop + topPad,
              OcChrome.pageGutter + 4,
              0,
            ),
            child: SizedBox(
              height: actionSize,
              child: Transform.translate(
                offset: Offset(0, expandShift * (1 - t)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OverflowBox(
                        maxHeight: 56,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
                                      fontWeight: FontWeight.w500,
                                      color: tokens.mutedForeground,
                                    ),
                                  ),
                                ),
                              ),
                            Transform.scale(
                              key: const Key('mobile-tab-page-title'),
                              alignment: Alignment.centerLeft,
                              scale: 1 - ((1 - OcOptical.titleCollapseScaleEnd) * t),
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: OcOptical.largeTitle,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: OcOptical.largeTitleTracking,
                                  height: OcOptical.largeTitleHeight,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (trailing != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: trailing,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
