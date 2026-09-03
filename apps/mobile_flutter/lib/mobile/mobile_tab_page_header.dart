import 'package:flutter/material.dart';

import '../theme/ios_chrome.dart';

/// Official `MobileTabPageHeader` — shared root-tab chrome.
///
/// Source: `packages/ui/src/mobile/MobileTabPageHeader.tsx` +
/// `packages/ui/src/styles/mobile.css` `.oc-mobile-collapsing-header*`.
///
/// Layout height is FIXED (`safe-area + 0.75rem + 2.5rem`). Background is
/// transparent. Scroll only drives compositor props (title scale 1→0.625,
/// inner translateY, fade opacity, letter-spacing). The 0.625rem spacer lives
/// in [MobileTabPageScaffold] as a real sibling — not folded into padding.
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
                                    fontWeight: FontWeight.w500,
                                    color: tokens.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          Transform.scale(
                            key: const Key('mobile-tab-page-title'),
                            alignment: Alignment.centerLeft,
                            scale: 1 - (OcOptical.titleCollapseScaleReduce * t),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: OcOptical.largeTitle,
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
