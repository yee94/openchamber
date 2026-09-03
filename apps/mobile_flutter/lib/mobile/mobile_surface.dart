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
class MobileLabeledSurfaceGroup extends StatelessWidget {
  const MobileLabeledSurfaceGroup({
    super.key,
    required this.label,
    this.children = const [],
  });

  final Widget label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label,
        ...children,
      ],
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
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double bottomOccupancy;

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
            ...widget.children,
          ],
        ),
      ),
    );

    if (widget.onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: widget.onRefresh!, child: scroll);
    }

    return Scaffold(
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
