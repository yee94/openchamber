import 'package:flutter/material.dart';

import 'oc_tokens.dart';

/// Official `--oc-mobile-float-shadow` / `--oc-mobile-shadow-*` layers.
///
/// Light: soft outside-only lift (README photos). Dark: no drop shadow —
/// hairline borders on the owning widget. Not Material 3 elevation.
/// Not a Flutter glass clone (no blur / inset highlight).
class OcElevation {
  const OcElevation._();

  /// Project / settings cards. Maps `--oc-mobile-float-shadow` without inset.
  static List<BoxShadow> card(BuildContext context, {bool tight = false}) =>
      cardFor(OcTokens.of(context), tight: tight);

  static List<BoxShadow> cardFor(OcTokens tokens, {bool tight = false}) {
    if (tokens.isDark) return const [];
    if (tight) {
      return const [
        BoxShadow(color: Color(0x04000000), blurRadius: 5),
        BoxShadow(color: Color(0x06000000), blurRadius: 20),
        BoxShadow(color: Color(0x08000000), blurRadius: 32, spreadRadius: -10, offset: Offset(0, 3)),
      ];
    }
    return const [
      BoxShadow(color: Color(0x08000000), blurRadius: 3),
      BoxShadow(color: Color(0x0A000000), blurRadius: 18),
      BoxShadow(color: Color(0x0E000000), blurRadius: 32, spreadRadius: -10, offset: Offset(0, 7)),
    ];
  }

  /// Chat file-change card — `--oc-mobile-shadow-near` family.
  static List<BoxShadow> grouped(BuildContext context) => groupedFor(OcTokens.of(context));

  static List<BoxShadow> groupedFor(OcTokens tokens) {
    if (tokens.isDark) return const [];
    return const [
      BoxShadow(color: Color(0x06000000), blurRadius: 2),
      BoxShadow(color: Color(0x0A000000), blurRadius: 12, spreadRadius: -4, offset: Offset(0, 3)),
    ];
  }

  /// Dock capsule — `--oc-mobile-glass-shadow` geometry without glass fill.
  static List<BoxShadow> dock(BuildContext context) => dockFor(OcTokens.of(context));

  static List<BoxShadow> dockFor(OcTokens tokens) {
    if (tokens.isDark) return const [];
    return const [
      BoxShadow(color: Color(0x06000000), blurRadius: 3),
      BoxShadow(color: Color(0x08000000), blurRadius: 16),
      BoxShadow(color: Color(0x0E000000), blurRadius: 28, spreadRadius: -8, offset: Offset(0, 5)),
    ];
  }

  /// Search / + discs — `--oc-mobile-shadow-control`.
  static List<BoxShadow> control(BuildContext context) => controlFor(OcTokens.of(context));

  static List<BoxShadow> controlFor(OcTokens tokens) {
    if (tokens.isDark) return const [];
    return const [
      BoxShadow(color: Color(0x08000000), blurRadius: 2),
      BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2)),
    ];
  }

  /// Composer pill — same family as dock, slightly tighter.
  static List<BoxShadow> composer(BuildContext context) => composerFor(OcTokens.of(context));

  static List<BoxShadow> composerFor(OcTokens tokens) {
    if (tokens.isDark) return const [];
    return const [
      BoxShadow(color: Color(0x06000000), blurRadius: 2),
      BoxShadow(color: Color(0x08000000), blurRadius: 14),
      BoxShadow(color: Color(0x0C000000), blurRadius: 22, spreadRadius: -6, offset: Offset(0, 4)),
    ];
  }
}
