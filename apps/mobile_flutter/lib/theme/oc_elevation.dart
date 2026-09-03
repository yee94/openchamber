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
    // Official CSS is 0.04 / 0.05 / 0.10 with a 10px drop. On opaque cream
    // that far stop reads as a heavy umbra — keep 0-offset contact + halo,
    // and a short tucked far wash (more negative spread, low alpha, small
    // offset) so lift is soft contact, not a drop. Same path cards/dock/composer.
    return const [
      BoxShadow(color: Color(0x06000000), blurRadius: 2),
      BoxShadow(color: Color(0x07000000), blurRadius: 8),
      BoxShadow(color: Color(0x08000000), blurRadius: 14, spreadRadius: -10, offset: Offset(0, 2)),
    ];
  }

  /// Chat file-change card — same float-shadow family as project cards.
  static List<BoxShadow> grouped(BuildContext context) => groupedFor(OcTokens.of(context));

  static List<BoxShadow> groupedFor(OcTokens tokens) => cardFor(tokens);

  /// Dock capsule — same float-shadow family. Fill/blur live on [OcFrosted].
  static List<BoxShadow> dock(BuildContext context) => dockFor(OcTokens.of(context));

  static List<BoxShadow> dockFor(OcTokens tokens) => cardFor(tokens);

  /// Search / + discs — `--oc-mobile-shadow-control`.
  static List<BoxShadow> control(BuildContext context) => controlFor(OcTokens.of(context));

  static List<BoxShadow> controlFor(OcTokens tokens) {
    if (tokens.isDark) return const [];
    // Search / + discs still need a visible plate, but must not out-lift cards.
    return const [
      BoxShadow(color: Color(0x06000000), blurRadius: 2),
      BoxShadow(color: Color(0x08000000), blurRadius: 6),
      BoxShadow(color: Color(0x09000000), blurRadius: 8, spreadRadius: -6, offset: Offset(0, 1)),
    ];
  }

  /// Composer pill — same `--oc-mobile-float-shadow` as cards (not flatter).
  static List<BoxShadow> composer(BuildContext context) => composerFor(OcTokens.of(context));

  static List<BoxShadow> composerFor(OcTokens tokens) => cardFor(tokens);
}
