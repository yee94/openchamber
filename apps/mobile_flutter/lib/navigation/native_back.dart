import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../motion/oc_motion.dart';
import '../native/haptics.dart';
import '../native/platform_channels.dart';

enum NativeBackKind { started, progressed, invoked, cancelled }

class NativeBackEvent {
  const NativeBackEvent({
    required this.kind,
    required this.progress,
    this.velocityX = 0,
  });

  final NativeBackKind kind;
  final double progress;
  final double velocityX;

  factory NativeBackEvent.fromMap(Object? raw) {
    final map = raw is Map ? raw.cast<Object?, Object?>() : const <Object?, Object?>{};
    final type = map['type']?.toString() ?? '';
    final kind = switch (type) {
      'started' => NativeBackKind.started,
      'progressed' => NativeBackKind.progressed,
      'invoked' => NativeBackKind.invoked,
      _ => NativeBackKind.cancelled,
    };
    return NativeBackEvent(
      kind: kind,
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      velocityX: (map['velocityX'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Listens to the iOS `UIScreenEdgePanGestureRecognizer` plugin and drives the
/// top [IosNativePageRoute]. Flutter does not install a second Material swipe.
class NativeBackDriver {
  NativeBackDriver({
    MethodChannel? channel,
    NativeHaptics? haptics,
  })  : _channel = channel ?? const MethodChannel(OpenChamberChannels.navigation),
        _haptics = haptics ?? NativeHaptics.instance {
    _channel.setMethodCallHandler(_onCall);
  }

  static NativeBackDriver instance = NativeBackDriver();

  final MethodChannel _channel;
  final NativeHaptics _haptics;
  final List<IosNativePageRoute<dynamic>> _stack = [];
  bool _enabled = false;

  @visibleForTesting
  bool get enabled => _enabled;

  @visibleForTesting
  IosNativePageRoute<dynamic>? get topRoute => _stack.isEmpty ? null : _stack.last;

  void attach(IosNativePageRoute<dynamic> route) {
    _stack.remove(route);
    _stack.add(route);
    _syncEnabled();
  }

  void detach(IosNativePageRoute<dynamic> route) {
    _stack.remove(route);
    _syncEnabled();
  }

  Future<void> handle(NativeBackEvent event) async {
    final route = topRoute;
    if (route == null || !route.isCurrent) return;
    switch (event.kind) {
      case NativeBackKind.started:
        route.beginNativeBack();
        route.applyNativeBackProgress(event.progress);
      case NativeBackKind.progressed:
        route.applyNativeBackProgress(event.progress);
      case NativeBackKind.invoked:
        _haptics.impact(HapticStrength.medium);
        await route.completeNativeBack(commit: true, velocityX: event.velocityX);
      case NativeBackKind.cancelled:
        await route.completeNativeBack(commit: false, velocityX: event.velocityX);
    }
  }

  Future<void> _syncEnabled() async {
    final next = _stack.isNotEmpty && defaultTargetPlatform == TargetPlatform.iOS;
    if (next == _enabled) return;
    _enabled = next;
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': next});
    } catch (_) {
      // Plugin is absent in WidgetTester / Android.
    }
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'event') return;
    await handle(NativeBackEvent.fromMap(call.arguments));
  }

  @visibleForTesting
  static void debugReset(NativeBackDriver next) {
    instance = next;
  }
}

/// Cupertino slide (UINavigationController) whose pop is driven by UIKit's
/// `UIScreenEdgePanGestureRecognizer`, not Flutter's edge-pan clone.
class IosNativePageRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
  IosNativePageRoute({
    required this.builder,
    this.pageTitle,
    super.settings,
  });

  final WidgetBuilder builder;
  final String? pageTitle;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  String? get title => pageTitle;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  /// Flutter must not replace the UIKit recognizer with a custom swipe.
  @override
  bool get popGestureEnabled => false;

  @override
  Duration get transitionDuration => OcMotion.navPush;

  @override
  Duration get reverseTransitionDuration => OcMotion.navPush;

  @override
  TickerFuture didPush() {
    NativeBackDriver.instance.attach(this);
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    NativeBackDriver.instance.detach(this);
    return super.didPop(result);
  }

  @override
  void dispose() {
    NativeBackDriver.instance.detach(this);
    super.dispose();
  }

  void beginNativeBack() {
    final nav = navigator;
    if (nav != null && !nav.userGestureInProgress) {
      nav.didStartUserGesture();
    }
  }

  void applyNativeBackProgress(double progress) {
    controller?.value = (1.0 - progress).clamp(0.0, 1.0);
  }

  Future<void> completeNativeBack({required bool commit, required double velocityX}) async {
    final nav = navigator;
    final animation = controller;
    if (nav == null || animation == null) return;
    if (commit) {
      if (isCurrent) {
        nav.pop();
      }
    } else {
      final remaining = (1 - animation.value).clamp(0.0, 1.0);
      final ms = (OcMotion.navSettle.inMilliseconds * remaining - velocityX.abs() / 12)
          .clamp(180, OcMotion.navSettle.inMilliseconds.toDouble());
      await animation.animateTo(
        1,
        duration: Duration(milliseconds: ms.round()),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    }
    if (nav.userGestureInProgress) {
      nav.didStopUserGesture();
    }
  }
}
