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
    // Official `--oc-mobile-float-shadow` outside-only layers (no inset
    // highlight — WidgetTester cannot paint glass). Soft contact, not flat
    // and not a hard umbra.
    return const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 2),
      BoxShadow(color: Color(0x0D000000), blurRadius: 12),
      BoxShadow(color: Color(0x1A000000), blurRadius: 24, spreadRadius: -6, offset: Offset(0, 10)),
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
    // Official `--oc-mobile-glass-shadow` without the inset highlight —
    // search / + discs need outside lift so the light plate reads as a disc.
    return const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 2),
      BoxShadow(color: Color(0x0F000000), blurRadius: 12),
      BoxShadow(color: Color(0x1F000000), blurRadius: 20, spreadRadius: -6, offset: Offset(0, 8)),
    ];
  }

  /// Composer pill — same `--oc-mobile-float-shadow` as cards (not flatter).
  static List<BoxShadow> composer(BuildContext context) => composerFor(OcTokens.of(context));

  static List<BoxShadow> composerFor(OcTokens tokens) => cardFor(tokens);
}
