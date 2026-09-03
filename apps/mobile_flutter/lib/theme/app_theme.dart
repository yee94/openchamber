import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'ios_chrome.dart';

/// Semantic tokens aligned with OpenChamber `surface.*` / `primary.*`.
/// Native-first: iOS grouped chrome on every surface; Material 3 on Android
/// without underline fields or a fake glass dock.
class OcTokens {
  static const Color backgroundLight = OcChrome.groupedLight;
  static const Color backgroundDark = OcChrome.groupedDark;
  static const Color elevatedLight = OcChrome.cardLight;
  static const Color elevatedDark = OcChrome.cardDark;
  static const Color foregroundLight = OcChrome.title;
  static const Color foregroundDark = Color(0xFFF2F2F7);
  static const Color mutedLight = OcChrome.secondary;
  static const Color mutedDark = Color(0xFF8E8E93);
  static const Color borderLight = Color(0x1F1A1916);
  static const Color borderDark = Color(0x33F4F1EA);
  static const Color primary = Color(0xFF2F6FED);
  static const Color unreadDot = Color(0xFF2F6FED);
  static const double groupRadius = OcChrome.cardRadius;
  static const double rowMinHeight = 52;
  static const double sectionGap = 8;
  static const double sectionStackGap = 20;
}

InputDecorationTheme _inputTheme(ColorScheme scheme, bool isDark) {
  final fill = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
  final radius = BorderRadius.circular(12);
  final none = OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none);
  return InputDecorationTheme(
    filled: true,
    fillColor: fill,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    border: none,
    enabledBorder: none,
    focusedBorder: none,
    disabledBorder: none,
    errorBorder: none,
    focusedErrorBorder: none,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.4)),
    labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
  );
}

ThemeData materialTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: OcTokens.primary,
    onPrimary: Colors.white,
    secondary: OcTokens.primary,
    onSecondary: Colors.white,
    error: const Color(0xFFC62828),
    onError: Colors.white,
    surface: isDark ? OcTokens.elevatedDark : OcTokens.elevatedLight,
    onSurface: isDark ? OcTokens.foregroundDark : OcTokens.foregroundLight,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? OcTokens.backgroundDark : OcTokens.backgroundLight,
    canvasColor: isDark ? OcTokens.backgroundDark : OcTokens.backgroundLight,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? OcTokens.backgroundDark : OcTokens.backgroundLight,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    inputDecorationTheme: _inputTheme(scheme, isDark),
    dividerColor: Colors.transparent,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xE61C1C1E) : const Color(0xF2FFFFFF),
      indicatorColor: OcTokens.primary.withValues(alpha: 0.16),
      elevation: 0,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
  );
}

CupertinoThemeData cupertinoTheme(Brightness brightness) {
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: OcTokens.primary,
    scaffoldBackgroundColor:
        brightness == Brightness.dark ? OcTokens.backgroundDark : OcTokens.backgroundLight,
    barBackgroundColor: brightness == Brightness.dark
        ? const Color(0xE61C1C1E)
        : const Color(0xF2F2F2F7),
  );
}
