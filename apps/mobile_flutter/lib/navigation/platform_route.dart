import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'native_back.dart';

/// iOS: UINavigationController-style slide whose interactive pop is driven by
/// `UIScreenEdgePanGestureRecognizer`. Android: Material + predictive back.
Route<T> platformPageRoute<T>({required WidgetBuilder builder}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return IosNativePageRoute<T>(builder: builder);
  }
  return MaterialPageRoute<T>(builder: builder);
}
