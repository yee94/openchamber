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
    // Official `--oc-mobile-float-shadow` far is `0 10px 24px -6px`
    // light `rgb(0 0 0 / 0.1)` / dark `rgb(0 0 0 / 0.34)`. Geometry
    // stays 10/24/-6 — do not invent Material 8/20 or WidgetTester
    // -2 (that loudens the umbra on cream). Light alpha stays 10%.
    // Dark was incorrectly painted at light 10% (wash-out). Near
    // pair stays quieter on tight. Dock / chips stay near-pair only.
    final far = BoxShadow(
      color: Color.fromRGBO(0, 0, 0, tokens.isDark ? 0.34 : 0.10),
      offset: const Offset(0, 10),
      blurRadius: 24,
      spreadRadius: -6,
    );
    if (tokens.isDark) {
      if (tight) {
        return [
          const BoxShadow(color: Color(0x2E000000), blurRadius: 2),
          const BoxShadow(color: Color(0x2A000000), blurRadius: 12),
          far,
        ];
      }
      return [
        const BoxShadow(color: Color(0x42000000), blurRadius: 2),
        const BoxShadow(color: Color(0x3D000000), blurRadius: 12),
        far,
      ];
    }
    if (tight) {
      return [
        const BoxShadow(color: Color(0x08000000), blurRadius: 2),
        const BoxShadow(color: Color(0x0A000000), blurRadius: 12),
        far,
      ];
    }
    return [
      const BoxShadow(color: Color(0x0A000000), blurRadius: 2),
      const BoxShadow(color: Color(0x0D000000), blurRadius: 12),
      far,
    ];
  }

  /// Official `inset 0 1px 0 var(--oc-mobile-glass-highlight)` for
  /// elevated plates. The 34 search disc stays [chip] (wake-1440).
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

  /// Dock capsule — official `--oc-mobile-glass-shadow` near pair.
  /// Light `0 0 2px / 0.05` + `0 0 12px / 0.06`. Dark `0.30` / `0.28`.
  /// No 8/20 umbra (that painted a cream stadium) and no inset sheen.
  static List<BoxShadow> dock(BuildContext context) => dockFor(OcTokens.of(context));

  static List<BoxShadow> dockFor(OcTokens tokens) {
    if (tokens.isDark) {
      return const [
        BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.30), blurRadius: 2),
        BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.28), blurRadius: 12),
      ];
    }
    return const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 2),
      BoxShadow(color: Color(0x0F000000), blurRadius: 12),
    ];
  }

  /// Official `--oc-mobile-glass-shadow` near pair + 8/20/-6 umbra.
  /// Header discs do not use this — the 8px drop paints a second circle.
  /// Search / `+` use [chip] (near pair, no umbra).
  static List<BoxShadow> control(BuildContext context) => controlFor(OcTokens.of(context));

  static List<BoxShadow> controlFor(OcTokens tokens) {
    // Official `.oc-mobile-settings-search-field` uses
    // `--oc-mobile-glass-shadow` in both themes. Light already had
    // the trio. Dark was empty (same miss as dock before 0412).
    // Dock stays near-pair only (8/20 stadium). Settings search is
    // a field, not a disc — paint the official dark 8/20 @ 0.40.
    if (tokens.isDark) {
      return const [
        BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.30), blurRadius: 2),
        BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.28), blurRadius: 12),
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.40),
          offset: Offset(0, 8),
          blurRadius: 20,
          spreadRadius: -6,
        ),
      ];
    }
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

  /// Official glass-shadow near pair: `0 0 2px / 0.05` + `0 0 12px / 0.06`.
  /// Soft lift for search / `+` — no 8/20 umbra (that paints a second circle).
  static List<BoxShadow> chip(BuildContext context) => chipFor(OcTokens.of(context));

  static List<BoxShadow> chipFor(OcTokens tokens) {
    if (tokens.isDark) return const [];
    return const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 2),
      BoxShadow(color: Color(0x0F000000), blurRadius: 12),
    ];
  }

  /// Official `.oc-mobile-composer` / `.oc-mobile-composer-surface`:
  /// `box-shadow: none` — elevation under the input reads as a foot bar.
  static List<BoxShadow> composer(BuildContext context) => composerFor(OcTokens.of(context));

  static List<BoxShadow> composerFor(OcTokens tokens) => const [];
}
