import 'package:flutter/material.dart';

import 'oc_tokens.dart';

/// Official `--oc-mobile-float-shadow` / `--oc-mobile-glass-shadow` layers.
///
/// Light: soft outside-only lift. Dark: no drop shadow — hairline borders on
/// the owning widget. Not Material 3 elevation. Not a Flutter glass clone
/// (no blur / inset highlight — iOS glass stays on UIKit overlays).
class OcElevation {
  const OcElevation._();

  /// Shared `--oc-mobile-float-shadow` without the inset highlight
  /// (`0 0 2px / 0.04`, `0 0 12px / 0.05`, `0 10px 24px -6px / 0.1`).
  /// Far wash is a hair quieter than the CSS 0.10 so opaque WidgetTester
  /// cards do not read as Material elevation.
  static List<BoxShadow> card(BuildContext context, {bool tight = false}) =>
      cardFor(OcTokens.of(context), tight: tight);

  static List<BoxShadow> cardFor(OcTokens tokens, {bool tight = false}) {
    if (tokens.isDark) return const [];
    if (tight) {
      return const [
        BoxShadow(color: Color(0x07000000), blurRadius: 4),
        BoxShadow(color: Color(0x09000000), blurRadius: 14),
        BoxShadow(color: Color(0x0A000000), blurRadius: 22, spreadRadius: -8, offset: Offset(0, 4)),
      ];
    }
    return const [
      BoxShadow(color: Color(0x07000000), blurRadius: 5),
      BoxShadow(color: Color(0x09000000), blurRadius: 16),
      BoxShadow(color: Color(0x0B000000), blurRadius: 28, spreadRadius: -8, offset: Offset(0, 6)),
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
    return const [
      BoxShadow(color: Color(0x06000000), blurRadius: 3),
      BoxShadow(color: Color(0x09000000), blurRadius: 6, offset: Offset(0, 1)),
    ];
  }

  /// Composer pill — same `--oc-mobile-float-shadow` as cards (not flatter).
  static List<BoxShadow> composer(BuildContext context) => composerFor(OcTokens.of(context));

  static List<BoxShadow> composerFor(OcTokens tokens) => cardFor(tokens);
}
