import 'package:flutter/material.dart';

import 'oc_tokens.dart';

/// Official `--oc-mobile-float-shadow` / `--oc-mobile-glass-shadow` layers.
///
/// Light: soft outside-only lift. Dark: no drop shadow — hairline borders on
/// the owning widget. Not Material 3 elevation. Not a Flutter glass clone
/// (no blur / inset highlight — iOS glass stays on UIKit overlays).
class OcElevation {
  const OcElevation._();

  /// Shared `--oc-mobile-float-shadow` without the inset highlight.
  /// Layers stay outside-only and more diffused than a 2px hairline ring so
  /// opaque WidgetTester cards read as soft lift, not a hard umbra.
  static List<BoxShadow> card(BuildContext context, {bool tight = false}) =>
      cardFor(OcTokens.of(context), tight: tight);

  static List<BoxShadow> cardFor(OcTokens tokens, {bool tight = false}) {
    if (tokens.isDark) return const [];
    // Official CSS is 0.04 / 0.05 / 0.10. Opaque cream cards paint that as a
    // heavier umbra than glass, so far wash sits under 0.08 with more
    // negative spread. Not flat, not a hard drop.
    return const [
      BoxShadow(color: Color(0x08000000), blurRadius: 2),
      BoxShadow(color: Color(0x0A000000), blurRadius: 12),
      BoxShadow(color: Color(0x14000000), blurRadius: 22, spreadRadius: -8, offset: Offset(0, 8)),
    ];
  }

  /// Chat file-change card — same float-shadow family as project cards.
  static List<BoxShadow> grouped(BuildContext context) => groupedFor(OcTokens.of(context));

  static List<BoxShadow> groupedFor(OcTokens tokens) => cardFor(tokens);

  /// Dock capsule — same float-shadow family (no glass fill).
  static List<BoxShadow> dock(BuildContext context) => dockFor(OcTokens.of(context));

  static List<BoxShadow> dockFor(OcTokens tokens) => cardFor(tokens);

  /// Search / + discs — `--oc-mobile-shadow-control`.
  static List<BoxShadow> control(BuildContext context) => controlFor(OcTokens.of(context));

  static List<BoxShadow> controlFor(OcTokens tokens) {
    if (tokens.isDark) return const [];
    // Search / + discs still need a visible plate. Softer than glass-shadow
    // 0.12 so they do not out-lift the cards.
    return const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 2),
      BoxShadow(color: Color(0x0C000000), blurRadius: 10),
      BoxShadow(color: Color(0x16000000), blurRadius: 16, spreadRadius: -6, offset: Offset(0, 6)),
    ];
  }

  /// Composer pill — same `--oc-mobile-float-shadow` as cards (not flatter).
  static List<BoxShadow> composer(BuildContext context) => composerFor(OcTokens.of(context));

  static List<BoxShadow> composerFor(OcTokens tokens) => cardFor(tokens);
}
