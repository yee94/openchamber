import 'package:flutter/material.dart';

import 'oc_tokens.dart';

/// README iOS photograph chrome for Projects / Chat / Scheduled.
///
/// Official `OcTokens` stay the WebView design-system catalog (orange
/// `--primary`, warm sand). Those three hero surfaces follow the attached
/// `docs/references/mobile_*.png` photos when the two conflict: cool grouped
/// gray, white cards, UIKit blue tint. Settings / Connect / Assistant keep
/// [OcTokens]. This is not a Flutter glass clone.
@immutable
class OcIosHero {
  const OcIosHero({
    required this.brightness,
    required this.groupedBackground,
    required this.card,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.track,
    required this.tint,
    required this.tintFill,
    required this.navy,
    required this.userBubble,
  });

  final Brightness brightness;
  final Color groupedBackground;
  final Color card;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color separator;
  final Color track;
  final Color tint;
  final Color tintFill;
  final Color navy;
  final Color userBubble;

  bool get isDark => brightness == Brightness.dark;

  /// UIKit systemBlue. Photograph chrome — not `--primary`.
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemBlueDark = Color(0xFF0A84FF);

  static const OcIosHero light = OcIosHero(
    brightness: Brightness.light,
    groupedBackground: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    label: Color(0xFF1C1C1E),
    secondaryLabel: Color(0xFF8E8E93),
    tertiaryLabel: Color(0xFFAEAEB2),
    separator: Color(0x143C3C43),
    track: Color(0xFFE5E5EA),
    tint: systemBlue,
    tintFill: Color(0x1F007AFF),
    navy: Color(0xFF1C1C1E),
    userBubble: Color(0xFFE8EEF6),
  );

  static const OcIosHero dark = OcIosHero(
    brightness: Brightness.dark,
    groupedBackground: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    label: Color(0xFFF2F2F7),
    secondaryLabel: Color(0xFF8E8E93),
    tertiaryLabel: Color(0xFF636366),
    separator: Color(0x26FFFFFF),
    track: Color(0xFF2C2C2E),
    tint: systemBlueDark,
    tintFill: Color(0x330A84FF),
    navy: Color(0xFFF2F2F7),
    userBubble: Color(0xFF2C2C2E),
  );

  static OcIosHero forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static OcIosHero of(BuildContext context) {
    return forBrightness(Theme.of(context).brightness);
  }
}

/// Remaps [OcTokens] + Material colors for a README hero surface.
/// Catalog tokens remain on the ancestor (Settings, Appearance, dock tests).
class HeroSurface extends StatelessWidget {
  const HeroSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = OcTokens.of(context);
    final hero = OcIosHero.forBrightness(base.brightness);
    final scheme = Theme.of(context).colorScheme.copyWith(
          primary: hero.tint,
          onPrimary: Colors.white,
          surface: hero.card,
          onSurface: hero.label,
          secondary: hero.track,
          onSecondary: hero.label,
        );
    final baseTheme = Theme.of(context);
    return Theme(
      data: baseTheme.copyWith(
        scaffoldBackgroundColor: hero.groupedBackground,
        canvasColor: hero.groupedBackground,
        cardColor: hero.card,
        dividerColor: hero.separator,
        hintColor: hero.secondaryLabel,
        splashColor: hero.tint.withValues(alpha: 0.08),
        highlightColor: hero.tint.withValues(alpha: 0.05),
        colorScheme: scheme,
        textTheme: baseTheme.textTheme.apply(bodyColor: hero.label, displayColor: hero.label),
        primaryTextTheme: baseTheme.primaryTextTheme.apply(bodyColor: hero.label, displayColor: hero.label),
        iconTheme: IconThemeData(color: hero.secondaryLabel, size: 18),
        appBarTheme: AppBarTheme(
          backgroundColor: hero.groupedBackground,
          foregroundColor: hero.label,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        extensions: <ThemeExtension<dynamic>>[
          base.copyWith(
            background: hero.groupedBackground,
            foreground: hero.label,
            card: hero.card,
            cardForeground: hero.label,
            popover: hero.card,
            popoverForeground: hero.label,
            primary: hero.tint,
            primaryForeground: Colors.white,
            secondary: hero.track,
            secondaryForeground: hero.label,
            muted: hero.track,
            mutedForeground: hero.secondaryLabel,
            accent: hero.track,
            accentForeground: hero.label,
            border: hero.separator,
            input: hero.card,
            ring: hero.tint,
            sidebar: hero.groupedBackground,
            sidebarForeground: hero.label,
            sidebarPrimary: hero.tint,
            sidebarPrimaryForeground: Colors.white,
            sidebarAccent: hero.track,
            sidebarAccentForeground: hero.label,
            sidebarBorder: hero.separator,
            sidebarRing: hero.tint,
          ),
        ],
      ),
      child: child,
    );
  }
}
