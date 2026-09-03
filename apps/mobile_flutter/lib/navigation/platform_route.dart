import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// iOS edge-pan back (Cupertino) / Android predictive back (theme).
Route<T> platformPageRoute<T>({required WidgetBuilder builder}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return CupertinoPageRoute<T>(builder: builder);
  }
  return MaterialPageRoute<T>(builder: builder);
}
