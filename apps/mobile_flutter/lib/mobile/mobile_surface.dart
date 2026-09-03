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
/// Header overlay is sticky (fixed layout height). A static in-flow spacer
/// (`0.625rem`) scrolls away natively. iOS does not get a Flutter glass fill.
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
    Widget scroll = SingleChildScrollView(
      controller: _scroll,
      clipBehavior: Clip.none,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(bottom: 24 + widget.bottomOccupancy),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              key: Key('mobile-tab-page-header-spacer'),
              height: MobileTabPageHeader.expandShift,
            ),
            ...widget.children,
          ],
        ),
      ),
    );

    if (widget.onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: widget.onRefresh!, child: scroll);
    }

    return Scaffold(
      body: Column(
        children: [
          ValueListenableBuilder<double>(
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
          Expanded(child: scroll),
        ],
      ),
    );
  }
}
