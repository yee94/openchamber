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
  static List<BoxShadow> card(BuildContext context, {bool tight = false}) {
    if (OcTokens.of(context).isDark) return const [];
    if (tight) {
      return const [
        BoxShadow(color: Color(0x0A000000), blurRadius: 2),
        BoxShadow(color: Color(0x0C000000), blurRadius: 8),
        BoxShadow(color: Color(0x14000000), blurRadius: 16, spreadRadius: -5, offset: Offset(0, 6)),
      ];
    }
    return const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 2),
      BoxShadow(color: Color(0x0D000000), blurRadius: 12),
      BoxShadow(color: Color(0x1A000000), blurRadius: 24, spreadRadius: -6, offset: Offset(0, 10)),
    ];
  }

  /// Chat file-change card — `--oc-mobile-shadow-near` family.
  static List<BoxShadow> grouped(BuildContext context) {
    if (OcTokens.of(context).isDark) return const [];
    return const [
      BoxShadow(color: Color(0x08000000), blurRadius: 2),
      BoxShadow(color: Color(0x0A000000), blurRadius: 10, spreadRadius: -3, offset: Offset(0, 3)),
    ];
  }

  /// Dock capsule — `--oc-mobile-glass-shadow` geometry without glass fill.
  static List<BoxShadow> dock(BuildContext context) {
    if (OcTokens.of(context).isDark) return const [];
    return const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 2),
      BoxShadow(color: Color(0x0F000000), blurRadius: 12),
      BoxShadow(color: Color(0x1F000000), blurRadius: 20, spreadRadius: -6, offset: Offset(0, 8)),
    ];
  }

  /// Search / + discs — `--oc-mobile-shadow-control`.
  static List<BoxShadow> control(BuildContext context) {
    if (OcTokens.of(context).isDark) return const [];
    return const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 2),
      BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
    ];
  }

  /// Composer pill — same family as dock, slightly tighter.
  static List<BoxShadow> composer(BuildContext context) {
    if (OcTokens.of(context).isDark) return const [];
    return const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 2),
      BoxShadow(color: Color(0x0D000000), blurRadius: 10),
      BoxShadow(color: Color(0x14000000), blurRadius: 16, spreadRadius: -4, offset: Offset(0, 6)),
    ];
  }
}
