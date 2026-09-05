import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/projects/highlighted_text.dart';
import '../theme/ios_chrome.dart';

/// Official `MobileTabPageHeader` — shared root-tab chrome.
///
/// Source: `packages/ui/src/mobile/MobileTabPageHeader.tsx` +
/// `packages/ui/src/styles/mobile.css` `.oc-mobile-collapsing-header*`.
///
/// Layout height is FIXED (`safe-area + 0.75rem + 2.5rem`). The title band
/// paints solid [OcTokens.headerFill] (`--oc-mobile-page-background`) so
/// sticky titles do not wash through body cards. Scroll only drives
/// compositor props (title scale 1→0.625, inner translateY, fade opacity
/// below the band, letter-spacing). The 0.625rem spacer and official
/// `--oc-mobile-page-gap` clearance live in [MobileTabPageScaffold] as
/// real siblings — not folded into padding, not a per-tab restPeek.
class MobileTabPageHeader extends StatelessWidget {
  const MobileTabPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.collapse = 0,
    this.collapseListenable,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  /// 0 expanded → 1 collapsed. Used when [collapseListenable] is null.
  final double collapse;

  /// Scroll-driven collapse. Fade + title listen; [trailing] stays a
  /// stable child so search/frost chips are not rebuilt every frame.
  final ValueListenable<double>? collapseListenable;

  /// Latest collapse, whether from a static value or the live notifier.
  double get currentCollapse => (collapseListenable?.value ?? collapse).clamp(0.0, 1.0);

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
    final fadeH = fadeHeight(safeTop);
    final headerH = layoutHeight(safeTop);
    final inner = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _CollapsingTitle(title: title, eyebrow: eyebrow, collapse: collapse, collapseListenable: collapseListenable)),
        if (trailing != null) ...[
          const SizedBox(width: OcOptical.collapsingInnerGap),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: actionSize),
            child: trailing,
          ),
        ],
      ],
    );

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
            child: _CollapseFade(safeTop: safeTop, collapse: collapse, collapseListenable: collapseListenable),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerH,
            child: IgnorePointer(
              child: ColoredBox(
                key: const Key('mobile-tab-page-header-fill'),
                color: tokens.headerFill,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              OcChrome.pageGutter + OcOptical.collapsingInlineExtra,
              safeTop + topPad,
              OcChrome.pageGutter + OcOptical.collapsingInlineExtra,
              0,
            ),
            child: _CollapseShift(collapse: collapse, collapseListenable: collapseListenable, child: inner),
          ),
        ],
      ),
    );
  }
}

class _CollapseFade extends StatelessWidget {
  const _CollapseFade({
    required this.safeTop,
    required this.collapse,
    required this.collapseListenable,
  });

  final double safeTop;
  final double collapse;
  final ValueListenable<double>? collapseListenable;

  @override
  Widget build(BuildContext context) {
    final fade = OcHeaderFade(safeTop: safeTop, opacity: collapse.clamp(0.0, 1.0));
    final listenable = collapseListenable;
    if (listenable == null) return fade;
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (context, t, _) => OcHeaderFade(safeTop: safeTop, opacity: t.clamp(0.0, 1.0)),
    );
  }
}

class _CollapseShift extends StatelessWidget {
  const _CollapseShift({
    required this.collapse,
    required this.collapseListenable,
    required this.child,
  });

  final double collapse;
  final ValueListenable<double>? collapseListenable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final listenable = collapseListenable;
    if (listenable == null) {
      return Transform.translate(
        offset: Offset(0, MobileTabPageHeader.expandShift * (1 - collapse.clamp(0.0, 1.0))),
        child: child,
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      child: child,
      builder: (context, t, child) {
        return Transform.translate(
          offset: Offset(0, MobileTabPageHeader.expandShift * (1 - t.clamp(0.0, 1.0))),
          child: child,
        );
      },
    );
  }
}

class _CollapsingTitle extends StatelessWidget {
  const _CollapsingTitle({
    required this.title,
    required this.eyebrow,
    required this.collapse,
    required this.collapseListenable,
  });

  final String title;
  final String? eyebrow;
  final double collapse;
  final ValueListenable<double>? collapseListenable;

  @override
  Widget build(BuildContext context) {
    final listenable = collapseListenable;
    if (listenable == null) return _titleAt(context, collapse);
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (context, t, _) => _titleAt(context, t),
    );
  }

  Widget _titleAt(BuildContext context, double raw) {
    final tokens = context.oc;
    final t = raw.clamp(0.0, 1.0);
    return SizedBox(
      height: MobileTabPageHeader.actionSize,
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
                fontWeight: FontWeight.w600,
                letterSpacing: OcOptical.rootTitleTracking(t),
                height: OcOptical.largeTitleHeight,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
