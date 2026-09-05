import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'oc_live_ios.dart';
import 'oc_tokens.dart';

export 'oc_tokens.dart';

/// Material 3 theme built from official [OcTokens] for [brightness].
ThemeData materialTheme(Brightness brightness) {
  final tokens = OcTokens.forBrightness(brightness);
  final scheme = tokens.colorScheme;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.pageBackground,
    canvasColor: tokens.pageBackground,
    cardColor: tokens.card,
    dividerColor: tokens.mobileDivider,
    hintColor: tokens.mutedForeground,
    extensions: <ThemeExtension<dynamic>>[tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.pageBackground,
      foregroundColor: tokens.foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: OcTokens.textUiHeader + 3, // 17pt pushed-nav title
        fontWeight: FontWeight.w600,
        color: tokens.foreground,
      ),
    ),
    inputDecorationTheme: _inputTheme(tokens),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.dockFill,
      indicatorColor: tokens.primary.withValues(alpha: 0.16),
      elevation: 0,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.primary;
        }
        return tokens.mutedForeground;
      }),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
    textTheme: _textTheme(tokens),
  );
}

TextTheme _textTheme(OcTokens tokens) {
  // WidgetTester / Android keep Material Android metrics (goldens).
  // Live iOS uses SF / PingFang through the iOS 2021 typography.
  final platform = ocLiveIosType ? TargetPlatform.iOS : TargetPlatform.android;
  final base = Typography.material2021(platform: platform);
  final themed = tokens.isDark ? base.white : base.black;
  return themed.copyWith(
    bodyLarge: themed.bodyLarge?.copyWith(fontSize: OcTokens.textMarkdown, color: tokens.foreground),
    bodyMedium: themed.bodyMedium?.copyWith(fontSize: OcTokens.textMarkdown, color: tokens.foreground),
    bodySmall: themed.bodySmall?.copyWith(fontSize: OcTokens.textMeta, color: tokens.mutedForeground),
    titleLarge: themed.titleLarge?.copyWith(fontSize: OcTokens.rootTitleSize, color: tokens.foreground),
    titleMedium: themed.titleMedium?.copyWith(fontSize: OcTokens.textUiHeader, color: tokens.foreground),
    titleSmall: themed.titleSmall?.copyWith(fontSize: OcTokens.textUiLabel, color: tokens.foreground),
    labelLarge: themed.labelLarge?.copyWith(fontSize: OcTokens.textUiLabel, color: tokens.foreground),
    labelMedium: themed.labelMedium?.copyWith(fontSize: OcTokens.textUiLabel, color: tokens.mutedForeground),
    labelSmall: themed.labelSmall?.copyWith(fontSize: OcTokens.textMicro, color: tokens.mutedForeground),
  );
}

InputDecorationTheme _inputTheme(OcTokens tokens) {
  final radius = BorderRadius.circular(OcTokens.formControlRadius);
  final none = OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none);
  return InputDecorationTheme(
    filled: true,
    fillColor: tokens.input,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    border: none,
    enabledBorder: none,
    focusedBorder: none,
    disabledBorder: none,
    errorBorder: none,
    focusedErrorBorder: none,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    hintStyle: TextStyle(color: tokens.mutedForeground.withValues(alpha: 0.8), fontSize: OcTokens.textUiLabel),
    labelStyle: TextStyle(color: tokens.mutedForeground, fontSize: OcTokens.textUiLabel),
  );
}

CupertinoThemeData cupertinoTheme(Brightness brightness) {
  final tokens = OcTokens.forBrightness(brightness);
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: tokens.primary,
    applyThemeToAll: true,
    scaffoldBackgroundColor: tokens.pageBackground,
    barBackgroundColor: tokens.surfaceElevated,
    textTheme: CupertinoTextThemeData(
      primaryColor: tokens.primary,
      textStyle: TextStyle(
        fontSize: OcTokens.textMarkdown,
        color: tokens.foreground,
      ),
    ),
  );
}
