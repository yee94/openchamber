import 'package:flutter/widgets.dart';

import '../native/haptics.dart';
import 'oc_motion.dart';

/// Finger-down press scale + official press-surface highlight.
///
/// Scale engages immediately, springs back on release, and cancels if the
/// pointer drags out. Optional [onPressed] owns the tap; omit it when a parent
/// already handles the gesture (visual + haptic only).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onPressed,
    this.haptic,
    this.enabled = true,
    this.highlight = true,
    this.scale = OcMotion.pressScale,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final HapticStrength? haptic;
  final bool enabled;
  final bool highlight;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _pointer;
  Offset? _origin;
  bool _cancelled = false;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _reduceMotion {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  void _engage() {
    if (!widget.enabled || _reduceMotion) return;
    // Finger-down is immediate; the official 80ms cubic is the spring-back language.
    _controller.value = 1;
  }

  void _release() {
    if (_reduceMotion) {
      _controller.value = 0;
      return;
    }
    _controller.animateTo(0, duration: OcMotion.pressRelease, curve: OcMotion.pressReleaseEase);
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    _pointer = event.pointer;
    _origin = event.position;
    _cancelled = false;
    _armed = true;
    _engage();
    final haptic = widget.haptic;
    if (haptic != null) {
      NativeHaptics.instance.impact(haptic);
    }
  }

  void _move(PointerMoveEvent event) {
    if (_pointer != event.pointer || _cancelled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(event.position);
    final hit = (Offset.zero & box.size).inflate(OcMotion.dragCancelSlop);
    final outside = !hit.contains(local);
    final dragged = _origin != null && (event.position - _origin!).distance > OcMotion.dragCancelSlop;
    if (outside || dragged) {
      _cancelled = true;
      _armed = false;
      _release();
    }
  }

  void _up(PointerUpEvent event) {
    if (_pointer != event.pointer) return;
    final commit = _armed && !_cancelled && widget.enabled;
    _pointer = null;
    _origin = null;
    _armed = false;
    _release();
    if (commit) {
      widget.onPressed?.call();
    }
    _cancelled = false;
  }

  void _cancel(PointerCancelEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _origin = null;
    _armed = false;
    _cancelled = false;
    _release();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final highlightT = t.clamp(0.0, 1.0);
          final scale = 1 - (1 - widget.scale) * t;
          final color = DefaultTextStyle.of(context).style.color;
          final fill = widget.highlight && highlightT > 0 && color != null
              ? OcMotion.pressFill(color).withValues(alpha: OcMotion.pressFillAlpha * highlightT)
              : null;
          return Align(
            child: Transform.scale(
              key: const ValueKey<String>('oc-press-transform'),
              scale: scale,
              filterQuality: FilterQuality.low,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: widget.borderRadius,
                ),
                child: child,
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
