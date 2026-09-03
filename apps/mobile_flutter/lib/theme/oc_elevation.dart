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
  /// Contact + tiny halo only — not a lifted plate and not a hairline ring.
  static List<BoxShadow> card(BuildContext context, {bool tight = false}) =>
      cardFor(OcTokens.of(context), tight: tight);

  static List<BoxShadow> cardFor(OcTokens tokens, {bool tight = false}) {
    if (tokens.isDark) return const [];
    // Official `--oc-mobile-float-shadow` near pair without the far
    // 10/24/-6 umbra. Prefer contact + a tiny halo over lift: a 12px
    // 0x08 wash still floated the project shell off the cream page.
    return const [
      BoxShadow(color: Color(0x08000000), blurRadius: 2),
      BoxShadow(color: Color(0x04000000), blurRadius: 8),
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

  /// Search / + discs — official `--oc-mobile-glass-shadow` (near pair
  /// + 8/20/-6 umbra). No primary 10/22 glow.
  static List<BoxShadow> control(BuildContext context) => controlFor(OcTokens.of(context));

  static List<BoxShadow> controlFor(OcTokens tokens) {
    if (tokens.isDark) return const [];
    return const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 2),
      BoxShadow(color: Color(0x0F000000), blurRadius: 12),
      BoxShadow(
        color: Color(0x1F000000),
        offset: Offset(0, 8),
        blurRadius: 20,
        spreadRadius: -6,
      ),
    ];
  }

  /// Composer pill — same `--oc-mobile-float-shadow` as cards (not flatter).
  static List<BoxShadow> composer(BuildContext context) => composerFor(OcTokens.of(context));

  static List<BoxShadow> composerFor(OcTokens tokens) => cardFor(tokens);
}
