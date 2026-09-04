import 'package:flutter/material.dart';

import '../theme/ios_chrome.dart';
import 'mobile_tab_page_header.dart';

/// Official `MobileFloatingSurface` — borderless floating material.
///
/// Source: `packages/ui/src/mobile/MobileSurface.tsx`.
/// Elevation is `--oc-mobile-float-shadow` via [OcElevation.card]. The outer
/// box owns the shadow; the fill is clipped so the shadow is not clipped.
class MobileFloatingSurface extends GroupedInsetCard {
  const MobileFloatingSurface({
    super.key,
    required super.child,
    super.margin,
    super.padding,
    super.tight,
  });
}

/// Official `MobileLabeledSurfaceGroup` — inset group inside a floating surface.
///
/// Source: `packages/ui/src/mobile/MobileSurface.tsx` +
/// `.oc-mobile-labeled-surface-group` (inset radius, 1px border, no shadow).
class MobileLabeledSurfaceGroup extends StatelessWidget {
  const MobileLabeledSurfaceGroup({
    super.key,
    this.label,
    this.children = const [],
  });

  final Widget? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final inner = OcTokens.insetRadius - 1;
    final tokens = context.oc;
    // Official inset group is 1px `--oc-mobile-border` (6%). On cream
    // frost that hairline vanishes — paint 11% so nested worktree shells
    // stay a labeled group, not a flat stack.
    final insetBorder = tokens.foreground.withValues(alpha: tokens.isDark ? 0.05 : 0.11);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(OcTokens.insetRadius),
        border: Border.all(color: insetBorder),
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          if (label != null)
            DecoratedBox(
              decoration: BoxDecoration(
                border: children.isEmpty
                    ? null
                    : Border(bottom: BorderSide(color: context.oc.mobileDivider, width: 1)),
                borderRadius: children.isEmpty
                    ? BorderRadius.circular(inner)
                    : BorderRadius.vertical(top: Radius.circular(inner)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: OcOptical.worktreeLabelMinHeight),
                child: label,
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// Official `MobileTabPageScaffold` — one page rhythm for the four root tabs.
///
/// Flutter analogue of sticky `.oc-mobile-collapsing-header`: a [Stack] overlay
/// so scrolling content passes **under** the translucent header / status area.
/// The scroll body keeps an in-flow [MobileTabPageHeader.layoutSlot] plus the
/// official `0.625rem` expand-shift spacer. Children stay a built [Column]
/// (not a lazy sliver) so settings slugs remain hittable via `ensureVisible`.
/// WidgetTester / Android paint header frost via [MobileTabPageHeader].
/// Real iOS still keeps live glass on the UIKit `UITabBar` overlay.
class MobileTabPageScaffold extends StatefulWidget {
  const MobileTabPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.eyebrow,
    this.trailing,
    this.onRefresh,
    this.bottomOccupancy = 0,
    this.restPeek = OcOptical.headerRestPeek,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double bottomOccupancy;

  /// Projects peek catalog under the translucent title. Scheduled / assistant
  /// / settings keep content below the large title (official stack).
  final double restPeek;

  @override
  State<MobileTabPageScaffold> createState() => _MobileTabPageScaffoldState();
}

class _MobileTabPageScaffoldState extends State<MobileTabPageScaffold> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _collapse = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _collapse.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_scroll.hasClients) return;
    final next = MobileTabPageHeader.collapseProgress(
      offset: _scroll.offset,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
    if ((next - _collapse.value).abs() < 0.001) return;
    _collapse.value = next;
  }

  @override
  Widget build(BuildContext context) {
    final view = MediaQuery.viewPaddingOf(context);
    final safeTop = view.top;
    Widget scroll = SingleChildScrollView(
      key: const Key('mobile-tab-page-scroll'),
      controller: _scroll,
      clipBehavior: Clip.none,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: OcTokens.dockHeight +
              OcOptical.pageScrollBottomExtra +
              view.bottom +
              widget.bottomOccupancy,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileTabPageHeader.layoutSlot(safeTop: safeTop),
            MobileTabPageHeader.expandShiftSpacer,
            Transform.translate(
              offset: Offset(0, -widget.restPeek),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
            SizedBox(height: widget.restPeek),
          ],
        ),
      ),
    );

    if (widget.onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: widget.onRefresh!, child: scroll);
    }

    return Scaffold(
      backgroundColor: context.oc.pageBackground,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: scroll),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _collapse,
              builder: (context, collapse, _) {
                return MobileTabPageHeader(
                  title: widget.title,
                  eyebrow: widget.eyebrow,
                  trailing: widget.trailing,
                  collapse: collapse,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
