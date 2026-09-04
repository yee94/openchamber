import 'package:flutter/material.dart';

import 'oc_tokens.dart';

/// Official `--oc-mobile-float-shadow` / `--oc-mobile-glass-shadow` layers.
///
/// Light and dark both paint the CSS outer trio. Inset highlight lives on
/// the clipped fill. Not Material 3 elevation. Not a Flutter glass clone.
class OcElevation {
  const OcElevation._();

  /// Official `--oc-mobile-float-shadow` outer layers. Inset highlight
  /// stays on the clipped fill via [highlight] so ClipRRect does not
  /// eat the drop. Header discs never use this (see [chip]).
  static List<BoxShadow> card(BuildContext context, {bool tight = false}) =>
      cardFor(OcTokens.of(context), tight: tight);

  static List<BoxShadow> cardFor(OcTokens tokens, {bool tight = false}) {
    // Official `--oc-mobile-float-shadow`: 2 / 12 / 10-24/-6.
    if (tokens.isDark) {
      return const [
        BoxShadow(color: Color(0x42000000), blurRadius: 2),
        BoxShadow(color: Color(0x3D000000), blurRadius: 12),
        BoxShadow(
          color: Color(0x57000000),
          offset: Offset(0, 10),
          blurRadius: 24,
          spreadRadius: -6,
        ),
      ];
    }
    return const [
      BoxShadow(color: Color(0x06000000), blurRadius: 2),
      BoxShadow(color: Color(0x08000000), blurRadius: 12),
      BoxShadow(
        color: Color(0x0E000000),
        offset: Offset(0, 10),
        blurRadius: 24,
        spreadRadius: -6,
      ),
    ];
  }

  /// Official `inset 0 1px 0 var(--oc-mobile-glass-highlight)` for
  /// elevated plates. The 36 search disc stays [chip] (wake-0706).
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
      BoxShadow(color: Color(0x05000000), blurRadius: 2),
      BoxShadow(color: Color(0x07000000), blurRadius: 12),
    ];
  }

  /// Official `--oc-mobile-glass-shadow` near pair + 8/20/-6 umbra.
  /// Header discs do not use this — the 8px drop paints a second circle.
  /// Primary `+` and glass chips use [chip] (contact only).
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

  /// Official glass-shadow contact: `0 0 2px rgb(0 0 0 / 0.05)`.
  /// Halo + 8/20 umbra paint a coin around the 36 disc.
  static List<BoxShadow> chip(BuildContext context) => chipFor(OcTokens.of(context));

  static List<BoxShadow> chipFor(OcTokens tokens) {
    if (tokens.isDark) return const [];
    return const [
      BoxShadow(color: Color(0x05000000), blurRadius: 2),
    ];
  }

  /// Official `.oc-mobile-composer` / `.oc-mobile-composer-surface`:
  /// `box-shadow: none` — elevation under the input reads as a foot bar.
  static List<BoxShadow> composer(BuildContext context) => composerFor(OcTokens.of(context));

  static List<BoxShadow> composerFor(OcTokens tokens) => const [];
}
