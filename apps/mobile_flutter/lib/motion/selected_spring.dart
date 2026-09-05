import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'oc_motion.dart';

/// Selected-state spring (segmented control, filter chips, dock pill).
///
/// [t] travels 0 → 1 with the iOS CASpring, not an instant snap or linear fade.
class OcSelectedSpring extends StatefulWidget {
  const OcSelectedSpring({
    super.key,
    required this.selected,
    required this.builder,
  });

  final bool selected;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<OcSelectedSpring> createState() => _OcSelectedSpringState();
}

class _OcSelectedSpringState extends State<OcSelectedSpring> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: widget.selected ? 1 : 0);
  }

  @override
  void didUpdateWidget(covariant OcSelectedSpring oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _controller.value = widget.selected ? 1 : 0;
      return;
    }
    final target = widget.selected ? 1.0 : 0.0;
    _controller.animateWith(
      SpringSimulation(OcMotion.iosSpring, _controller.value, target, 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value.clamp(0.0, 1.0)),
    );
  }
}
