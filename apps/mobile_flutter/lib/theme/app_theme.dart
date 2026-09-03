import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Semantic tokens aligned with OpenChamber `surface.*` / `primary.*`
/// (see `.claude/skills/theme-system/references/tokens-and-examples.md`).
/// Native-first: Cupertino on iOS, Material 3 on Android. No WebView theme.
class OcTokens {
  static const Color backgroundLight = Color(0xFFF7F5F2);
  static const Color backgroundDark = Color(0xFF141311);
  static const Color elevatedLight = Color(0xFFFFFFFF);
  static const Color elevatedDark = Color(0xFF1C1B19);
  static const Color foregroundLight = Color(0xFF1A1916);
  static const Color foregroundDark = Color(0xFFF4F1EA);
  static const Color mutedLight = Color(0xFF6F6A62);
  static const Color mutedDark = Color(0xFFA39D93);
  static const Color borderLight = Color(0x1F1A1916);
  static const Color borderDark = Color(0x33F4F1EA);
  static const Color primary = Color(0xFF2F6FED);
  static const Color unreadDot = Color(0xFF2F6FED);
  static const double groupRadius = 16;
  static const double rowMinHeight = 52;
  static const double sectionGap = 8;
  static const double sectionStackGap = 20;
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
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? OcTokens.backgroundDark : OcTokens.backgroundLight,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xE61C1B19) : const Color(0xE6FFFFFF),
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
        ? const Color(0xE61C1B19)
        : const Color(0xE6F7F5F2),
  );
}
