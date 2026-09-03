import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Press / spring timing owned by the Flutter motion layer.
///
/// Scale direction is Yee's native brief (0.97–0.98 down). Engage / release
/// cubics match official `packages/ui/src/styles/mobile.css` press-surface.
/// The iOS CASpring numbers come from Flutter's Cupertino route (measured
/// `CASpringAnimation` in Xcode): critically damped, ~404ms for a full travel.
abstract final class OcMotion {
  /// Midpoint of the required 0.97–0.98 press scale.
  static const double pressScale = 0.975;

  /// Official `--oc-press-engage-duration`.
  static const Duration pressEngage = Duration(milliseconds: 80);

  /// Official `--oc-press-release-duration`.
  static const Duration pressRelease = Duration(milliseconds: 260);

  /// Official `--oc-press-engage-ease`: cubic-bezier(0.16, 1, 0.3, 1).
  static const Cubic pressEngageEase = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Official `--oc-press-release-ease`: cubic-bezier(0.2, 1.28, 0.3, 1).
  static const Cubic pressReleaseEase = Cubic(0.2, 1.28, 0.3, 1.0);

  /// `--oc-mobile-press-fill` = surface-foreground 7%.
  static const double pressFillAlpha = 0.07;

  /// Cancel a press once the pointer leaves the target by this many logical px.
  static const double dragCancelSlop = 28;

  /// UINavigationController-ish push. Not a 300ms linear fade.
  static const Duration navPush = Duration(milliseconds: 350);

  /// Flutter Cupertino dropped-swipe settle (matches native pop settle).
  static const Duration navSettle = Duration(milliseconds: 350);

  /// Capacitor `OpenChamberNavigation` commit: progress ≥ 0.35.
  static const double backCommitProgress = 0.35;

  /// Capacitor `OpenChamberNavigation` commit: progress ≥ 0.08 and vx ≥ 700.
  static const double backCommitMinProgress = 0.08;
  static const double backCommitVelocity = 700;

  /// Measured iOS `CASpringAnimation` (Flutter Cupertino `_kStandardSpring`).
  static const SpringDescription iosSpring = SpringDescription(
    mass: 1,
    stiffness: 522.35,
    damping: 45.7099552,
  );

  static Color pressFill(Color foreground) => foreground.withValues(alpha: pressFillAlpha);

  static bool shouldCommitBack({required double progress, required double velocityX}) {
    return progress >= backCommitProgress || (progress >= backCommitMinProgress && velocityX >= backCommitVelocity);
  }
}
