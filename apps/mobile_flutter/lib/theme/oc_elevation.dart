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
    // Official `--oc-mobile-float-shadow` near pair (0 0 2px / 0.04,
    // 0 0 12px / 0.05). The far 10/24/-6 stop is a contact umbra on
    // small schedule plates and the project shell — drop it so both
    // share the same near-shadowless family.
    return const [
      BoxShadow(color: Color(0x06000000), blurRadius: 2),
      BoxShadow(color: Color(0x08000000), blurRadius: 12),
    ];
  }

  /// Official `inset 0 1px 0 var(--oc-mobile-glass-highlight)` for chips.
  static List<BoxShadow> glassHighlight(BuildContext context) =>
      glassHighlightFor(OcTokens.of(context));

  static List<BoxShadow> glassHighlightFor(OcTokens tokens) {
    return [
      BoxShadow(
        color: tokens.glassHighlight,
        offset: const Offset(0, 1),
        blurStyle: BlurStyle.inner,
      ),
    ];
  }

  /// Official `inset 0 1px 0 var(--oc-mobile-float-highlight)`.
  static List<BoxShadow> highlight(BuildContext context) => highlightFor(OcTokens.of(context));

  static List<BoxShadow> highlightFor(OcTokens tokens) {
    if (tokens.isDark) {
      return [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.18),
          offset: const Offset(0, 1),
          blurStyle: BlurStyle.inner,
        ),
      ];
    }
    return [
      BoxShadow(
        color: tokens.floatHighlight,
        offset: const Offset(0, 1),
        blurStyle: BlurStyle.inner,
      ),
    ];
  }

  /// Chat file-change card — same float-shadow family as project cards.
  static List<BoxShadow> grouped(BuildContext context) => groupedFor(OcTokens.of(context));

  static List<BoxShadow> groupedFor(OcTokens tokens) => cardFor(tokens);

  /// Dock capsule — glass-shadow contact + halo only (no 8px umbra).
  static List<BoxShadow> dock(BuildContext context) => dockFor(OcTokens.of(context));

  /// Dock sits in the page, not a floating Material stadium. Keep the
  /// contact + halo from glass-shadow; drop the 8px umbra.
  static List<BoxShadow> dockFor(OcTokens tokens) {
    if (tokens.isDark) return const [];
    return const [
      BoxShadow(color: Color(0x08000000), blurRadius: 2),
      BoxShadow(color: Color(0x0A000000), blurRadius: 12),
    ];
  }

  /// Search / project discs — glass-shadow contact + halo only.
  /// The official 8px umbra reads as a Material coin in WidgetTester.
  static List<BoxShadow> control(BuildContext context) => controlFor(OcTokens.of(context));

  static List<BoxShadow> controlFor(OcTokens tokens) => dockFor(tokens);

  /// Composer pill — same `--oc-mobile-float-shadow` as cards (not flatter).
  static List<BoxShadow> composer(BuildContext context) => composerFor(OcTokens.of(context));

  static List<BoxShadow> composerFor(OcTokens tokens) => cardFor(tokens);
}
