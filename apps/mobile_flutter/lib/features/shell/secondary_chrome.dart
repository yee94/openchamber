import 'package:flutter/foundation.dart';

/// Homepage dock hides while a pushed Chat (or editor) is mounted.
/// Matches OpenChamberTabBar hide-on-secondary. Settings drill-ins stay docked.
class SecondaryChrome {
  SecondaryChrome._();

  static final ValueNotifier<int> listenable = ValueNotifier<int>(0);
  static int _chatCount = 0;

  static bool get hideHomepageDock => _chatCount > 0;

  static void chatOpened() {
    _chatCount += 1;
    listenable.value = _chatCount;
  }

  static void chatClosed() {
    if (_chatCount == 0) return;
    _chatCount -= 1;
    listenable.value = _chatCount;
  }

  @visibleForTesting
  static void debugReset() {
    _chatCount = 0;
    listenable.value = 0;
  }
}
