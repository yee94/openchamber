import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Live iPhone / iPad only. WidgetTester and Android stay on the review
/// Regular-CJK path so goldens do not move.
///
/// UIKit `UIGlassEffect` is already on the native tab bar and composer.
/// This flag is the Flutter-side type gate: keep official Medium /
/// Semibold so PingFang SC paints the real cut.
bool get ocLiveIosType {
  final override = debugOcLiveIosType;
  if (override != null) return override;
  return !kIsWeb && Platform.isIOS;
}

/// Test-only. `null` restores [Platform.isIOS].
bool? debugOcLiveIosType;
