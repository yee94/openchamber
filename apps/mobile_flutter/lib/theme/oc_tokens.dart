import 'package:flutter/material.dart';

import 'ios_hero.dart';
import 'oklch.dart';

/// Official Capacitor WebView semantic catalog for both brightnesses.
///
/// Color sources:
/// - `packages/ui/src/styles/design-system.css` `:root` / `.dark` OKLCH tokens
/// - `packages/ui/src/styles/mobile.css` `--oc-mobile-*` geometry + surface mixes
///
/// Mobile CSS does **not** override `--primary`. Appearance is Light / Dark /
/// System only (no theme picker), so Flutter uses the design-system defaults
/// rather than the Flexoki JSON ThemeSystem writes at WebView runtime.
///
/// Product-only chrome that is not a CSS token (agent purple) lives on
/// [OcProductChrome], not here.
@immutable
class OcTokens extends ThemeExtension<OcTokens> {
  const OcTokens({
    required this.brightness,
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    required this.ring,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
    required this.sidebar,
    required this.sidebarForeground,
    required this.sidebarPrimary,
    required this.sidebarPrimaryForeground,
    required this.sidebarAccent,
    required this.sidebarAccentForeground,
    required this.sidebarBorder,
    required this.sidebarRing,
  });

  final Brightness brightness;
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color border;
  final Color input;
  final Color ring;
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;
  final Color sidebar;
  final Color sidebarForeground;
  final Color sidebarPrimary;
  final Color sidebarPrimaryForeground;
  final Color sidebarAccent;
  final Color sidebarAccentForeground;
  final Color sidebarBorder;
  final Color sidebarRing;

  /// `--surface-background` fallback → `--background`
  Color get surfaceBackground => background;

  /// `--surface-foreground` fallback → `--foreground`
  Color get surfaceForeground => foreground;

  /// `--surface-elevated` fallback → `--card`
  Color get surfaceElevated => card;

  Color get surfaceElevatedForeground => cardForeground;

  /// `--surface-muted` fallback → `--muted`
  Color get surfaceMuted => muted;

  Color get surfaceMutedForeground => mutedForeground;

  /// `--surface-subtle` — quiet wash of muted on the page canvas
  Color get surfaceSubtle => Color.lerp(background, muted, 0.55)!;

  Color get unreadDot => primary;

  Color get statusError => destructive;

  Color get statusSuccess => chart2;

  Color get statusInfo => chart1;

  /// `--oc-mobile-page-background`: muted 18% over background.
  /// Warm sand on light (`oklch(0.97 0.02 85)` mix) — not iOS system gray.
  Color get pageBackground => Color.lerp(background, muted, 0.18)!;

  /// `--oc-settings-group-background`: muted 55% over elevated.
  Color get settingsGroupBackground => Color.lerp(surfaceElevated, muted, 0.55)!;

  /// Official `--oc-mobile-float-background`: elevated 45% over transparent.
  /// Pair with [OcFrosted] / `BackdropFilter` — not an opaque Material slab.
  Color get floatSurface => card.withValues(alpha: 0.45);

  /// Official `--oc-mobile-float-highlight` (elevated 92%).
  Color get floatHighlight => (isDark ? Colors.white : card).withValues(alpha: isDark ? 0.18 : 0.92);

  /// `--oc-mobile-border` (light 6% / dark 3% of foreground)
  Color get mobileBorder => foreground.withValues(alpha: isDark ? 0.03 : 0.06);

  Color get mobileDivider => foreground.withValues(alpha: isDark ? 0.02 : 0.06);

  Color get mobileControlBorder => foreground.withValues(alpha: isDark ? 0.05 : 0.09);

  Color get mobilePressFill => foreground.withValues(alpha: isDark ? 0.10 : 0.07);

  /// `--form-surface-border`
  Color get formSurfaceBorder => foreground.withValues(alpha: 0.08);

  /// `--form-row-divider`
  Color get formRowDivider => foreground.withValues(alpha: 0.06);

  /// `--oc-mobile-field-background` (elevated 70%).
  Color get fieldBackground => surfaceElevated.withValues(alpha: 0.70);

  /// Official `--oc-mobile-glass-fill`. Pair with [OcFrosted] /
  /// `BackdropFilter` — not a `UIGlassEffect` clone.
  Color get glassFill => (isDark ? const Color(0xFF26262C) : const Color(0xFFFFFFFF))
      .withValues(alpha: isDark ? 0.66 : 0.68);

  /// mobileGlass frost plate — under official 0.68 coin, above bare
  /// page-bleed. Chat / schedule discs stay this 0.34 plate.
  Color get glassChipFill => (isDark ? const Color(0xFF26262C) : const Color(0xFFFFFFFF))
      .withValues(alpha: isDark ? 0.34 : 0.34);

  /// Search header frost. 0.34 reads as a cream coin on the collapsing
  /// header (nothing behind to blur). 0.22 is through-frost — still a
  /// 36 plate + σ14, not page-bleed and not a 0.68 coin.
  Color get glassChipThrough => (isDark ? const Color(0xFF26262C) : const Color(0xFFFFFFFF))
      .withValues(alpha: 0.22);

  /// Official `--oc-mobile-glass-highlight` is white / 0.60
  /// (dark 0.18). Inset sheen on the elevated plate.
  Color get glassHighlight => const Color(0xFFFFFFFF)
      .withValues(alpha: isDark ? 0.18 : 0.60);

  /// Official dock fill is `--oc-mobile-float-background` (45%) plus
  /// control-scale `blur(20) saturate(1.25)`. WidgetTester cannot paint
  /// live glass. Any cream fill (milk stack or card@0.08) reads as a
  /// stadium plate — milk-0 only moved ~1 RGB. Fill 0: frost is
  /// BackdropFilter + official saturate + glass-shadow. Official 0.45
  /// `floatSurface` is too solid here. Selected `/55` stays mix-only.
  Color get dockPlate => card.withValues(alpha: 0);

  /// Legacy alias. Floating chrome uses [glassFill] + blur instead.
  Color get dockFill => dockPlate;

  /// Official `--interactive-selection` is a muted foreground wash
  /// (`#16121016` light / `#f1ece81f` dark), not primary orange.
  Color get interactiveSelection =>
      foreground.withValues(alpha: isDark ? 0.122 : 0.086);

  /// Official selected-tab fill is `bg-interactive-selection/55`.
  /// Mix the authored token at [OcOptical.dockIconWashAlpha] so the
  /// 58×r29 cell is a through-wash, not a second cream plate (wake-0747).
  /// Do not use RGB@0.55 or a nested frost.
  Color get selectedTabWash =>
      interactiveSelection.withValues(alpha: interactiveSelection.a * OcOptical.dockIconWashAlpha);

  /// `--oc-mobile-header-fade` = surface-background 85%.
  Color get headerFade => background.withValues(alpha: 0.85);

  bool get isDark => brightness == Brightness.dark;

  static OcTokens of(BuildContext context) {
    return Theme.of(context).extension<OcTokens>() ?? forBrightness(Theme.of(context).brightness);
  }

  static OcTokens forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  /// `:root` default light — `design-system.css`
  static final OcTokens light = OcTokens(
    brightness: Brightness.light,
    background: oklchColor(0.97, 0.02, 85),
    foreground: oklchColor(0.25, 0.02, 40),
    card: oklchColor(0.99, 0.01, 90),
    cardForeground: oklchColor(0.25, 0.02, 40),
    popover: oklchColor(0.99, 0.01, 90),
    popoverForeground: oklchColor(0.25, 0.02, 40),
    primary: oklchColor(0.65, 0.2, 55),
    primaryForeground: oklchColor(0.99, 0.01, 90),
    secondary: oklchColor(0.92, 0.02, 80),
    secondaryForeground: oklchColor(0.25, 0.02, 40),
    muted: oklchColor(0.9, 0.015, 75),
    mutedForeground: oklchColor(0.45, 0.02, 50),
    accent: oklchColor(0.92, 0.02, 80),
    accentForeground: oklchColor(0.25, 0.02, 40),
    destructive: oklchColor(0.55, 0.25, 25),
    destructiveForeground: oklchColor(0.99, 0.01, 90),
    border: oklchColor(0.85, 0.02, 70),
    input: oklchColor(0.88, 0.02, 75),
    ring: oklchColor(0.65, 0.2, 55),
    chart1: oklchColor(0.58, 0.15, 230),
    chart2: oklchColor(0.58, 0.15, 145),
    chart3: oklchColor(0.65, 0.2, 55),
    chart4: oklchColor(0.55, 0.18, 30),
    chart5: oklchColor(0.6, 0.16, 85),
    sidebar: oklchColor(0.95, 0.02, 80),
    sidebarForeground: oklchColor(0.25, 0.02, 40),
    sidebarPrimary: oklchColor(0.65, 0.2, 55),
    sidebarPrimaryForeground: oklchColor(0.99, 0.01, 90),
    sidebarAccent: oklchColor(0.9, 0.02, 75),
    sidebarAccentForeground: oklchColor(0.25, 0.02, 40),
    sidebarBorder: oklchColor(0.85, 0.02, 70),
    sidebarRing: oklchColor(0.65, 0.2, 55),
  );

  /// `.dark` default — `design-system.css`
  static final OcTokens dark = OcTokens(
    brightness: Brightness.dark,
    background: oklchColor(0.16, 0.01, 30),
    foreground: oklchColor(0.85, 0.02, 90),
    card: oklchColor(0.19, 0.01, 40),
    cardForeground: oklchColor(0.85, 0.02, 90),
    popover: oklchColor(0.24, 0.01, 40),
    popoverForeground: oklchColor(0.85, 0.02, 90),
    primary: oklchColor(0.77, 0.17, 85),
    primaryForeground: oklchColor(0.16, 0.01, 30),
    secondary: oklchColor(0.29, 0.01, 40),
    secondaryForeground: oklchColor(0.85, 0.02, 90),
    muted: oklchColor(0.33, 0.01, 40),
    mutedForeground: oklchColor(0.75, 0.02, 80),
    accent: oklchColor(0.29, 0.01, 40),
    accentForeground: oklchColor(0.85, 0.02, 90),
    destructive: oklchColor(0.65, 0.15, 30),
    destructiveForeground: oklchColor(0.9, 0.02, 80),
    border: oklchColor(0.31, 0.01, 35),
    input: oklchColor(0.33, 0.01, 40),
    ring: oklchColor(0.77, 0.17, 85),
    chart1: oklchColor(0.68, 0.12, 230),
    chart2: oklchColor(0.68, 0.12, 145),
    chart3: oklchColor(0.7, 0.13, 95),
    chart4: oklchColor(0.65, 0.14, 45),
    chart5: oklchColor(0.68, 0.12, 55),
    sidebar: oklchColor(0.16, 0.01, 30),
    sidebarForeground: oklchColor(0.85, 0.02, 90),
    sidebarPrimary: oklchColor(0.77, 0.17, 85),
    sidebarPrimaryForeground: oklchColor(0.16, 0.01, 30),
    sidebarAccent: oklchColor(0.24, 0.01, 40),
    sidebarAccentForeground: oklchColor(0.85, 0.02, 90),
    sidebarBorder: oklchColor(0.31, 0.01, 35),
    sidebarRing: oklchColor(0.77, 0.17, 85),
  );

  // Geometry — rem × 16 from design-system.css + mobile.css.
  // Mobile typography overrides (`:root.mobile-pointer`) win over desktop.

  /// `--radius` / `--radius-lg` / `--form-control-radius` = 0.625rem
  static const double radius = 10;

  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusXl = 12;

  /// `--oc-mobile-surface-radius` = 1.5rem
  static const double surfaceRadius = 24;

  /// `--oc-mobile-inset-radius` = 1rem
  static const double insetRadius = 16;

  /// `--oc-mobile-control-radius` = 1.25rem
  static const double controlRadius = 20;

  static const double formControlRadius = radius;

  /// `--form-control-height` = 2.25rem
  static const double formControlHeight = 36;

  /// `--oc-mobile-dock-height` = 4.25rem
  static const double dockHeight = 68;

  /// `--oc-mobile-dock-radius` = dock-height / 2
  static const double dockRadius = 34;

  /// `--oc-mobile-dock-inline-inset` = 1rem
  static const double dockInlineInset = 16;

  /// `--oc-mobile-dock-inner-inset` = 0.3125rem
  static const double dockInnerInset = 5;

  /// `--oc-mobile-dock-gap` = 0.1875rem
  static const double dockGap = 3;

  /// `--oc-mobile-dock-max-width` = 26rem
  static const double dockMaxWidth = 416;

  /// `--oc-mobile-tab-height` = 68 − 5×2
  static const double tabHeight = 58;

  /// `--oc-mobile-tab-radius` = 34 − 5
  static const double tabRadius = 29;

  /// `--oc-mobile-detail-navigation-height` = 3.5rem
  static const double detailNavigationHeight = 56;

  /// `--oc-mobile-detail-action-edge-inset` = 1rem
  static const double detailActionEdgeInset = 16;

  /// Official detail-nav back column `2.75rem`.
  static const double detailActionColumn = 44;

  /// Header `::after` extra below the 56px band = 1.75rem
  static const double headerFadeExtra = 28;

  /// Tabpanel `pb` extra after the dock = 2.5rem
  static const double pageScrollBottomExtra = 40;

  /// `--oc-mobile-page-gap` = 1.25rem
  static const double pageGap = 20;

  /// `--oc-mobile-page-inline-inset` = 1.125rem
  static const double pageInlineInset = 18;

  /// `--oc-mobile-root-title-size` = 2rem
  static const double rootTitleSize = 32;

  /// Mobile `--text-markdown` = 0.9375rem
  static const double textMarkdown = 15;

  /// Mobile `--text-ui-header` = 0.875rem
  static const double textUiHeader = 14;

  /// Mobile `--text-ui-label` / `--text-meta` = 0.8125rem
  static const double textUiLabel = 13;
  static const double textMeta = 13;

  /// Mobile `--text-code` = 0.8125rem
  static const double textCode = 13;

  /// Mobile `--text-micro` = 0.75rem
  static const double textMicro = 12;

  /// `--oc-mobile-entity-title-size` = 1rem
  static const double entityTitleSize = 16;

  /// `--oc-mobile-entity-meta-size` = 0.8125rem
  static const double entityMetaSize = 13;

  /// `--oc-mobile-detail-title-size` = 0.9375rem
  static const double detailTitleSize = 15;

  /// `--oc-mobile-detail-subtitle-size` = 0.625rem
  static const double detailSubtitleSize = 10;

  /// `--oc-mobile-project-action-size` = 2.25rem
  static const double projectActionSize = 36;

  /// Root `--oc-mobile-session-row-height` = 2.875rem. Project-shell CSS
  /// is 2.5rem (40); [OcOptical.sessionRowVisualHeight] is 54 with a
  /// 3.5px CJK half-lead — still not 7.5/70.
  static const double sessionRowHeight = 46;

  static const double groupRadius = surfaceRadius;
  static const double rowMinHeight = 52;
  static const double sectionGap = 8;
  static const double sectionStackGap = 20;
  static const double headerButtonSize = projectActionSize;

  ColorScheme get colorScheme => ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: primaryForeground,
        secondary: secondary,
        onSecondary: secondaryForeground,
        error: destructive,
        onError: destructiveForeground,
        surface: card,
        onSurface: cardForeground,
        outline: border,
        outlineVariant: muted,
        surfaceTint: const Color(0x00000000),
      );

  @override
  OcTokens copyWith({
    Brightness? brightness,
    Color? background,
    Color? foreground,
    Color? card,
    Color? cardForeground,
    Color? popover,
    Color? popoverForeground,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? accentForeground,
    Color? destructive,
    Color? destructiveForeground,
    Color? border,
    Color? input,
    Color? ring,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chart5,
    Color? sidebar,
    Color? sidebarForeground,
    Color? sidebarPrimary,
    Color? sidebarPrimaryForeground,
    Color? sidebarAccent,
    Color? sidebarAccentForeground,
    Color? sidebarBorder,
    Color? sidebarRing,
  }) {
    return OcTokens(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
      popover: popover ?? this.popover,
      popoverForeground: popoverForeground ?? this.popoverForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      destructive: destructive ?? this.destructive,
      destructiveForeground: destructiveForeground ?? this.destructiveForeground,
      border: border ?? this.border,
      input: input ?? this.input,
      ring: ring ?? this.ring,
      chart1: chart1 ?? this.chart1,
      chart2: chart2 ?? this.chart2,
      chart3: chart3 ?? this.chart3,
      chart4: chart4 ?? this.chart4,
      chart5: chart5 ?? this.chart5,
      sidebar: sidebar ?? this.sidebar,
      sidebarForeground: sidebarForeground ?? this.sidebarForeground,
      sidebarPrimary: sidebarPrimary ?? this.sidebarPrimary,
      sidebarPrimaryForeground: sidebarPrimaryForeground ?? this.sidebarPrimaryForeground,
      sidebarAccent: sidebarAccent ?? this.sidebarAccent,
      sidebarAccentForeground: sidebarAccentForeground ?? this.sidebarAccentForeground,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      sidebarRing: sidebarRing ?? this.sidebarRing,
    );
  }

  @override
  OcTokens lerp(ThemeExtension<OcTokens>? other, double t) {
    if (other is! OcTokens) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return OcTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      foreground: mix(foreground, other.foreground),
      card: mix(card, other.card),
      cardForeground: mix(cardForeground, other.cardForeground),
      popover: mix(popover, other.popover),
      popoverForeground: mix(popoverForeground, other.popoverForeground),
      primary: mix(primary, other.primary),
      primaryForeground: mix(primaryForeground, other.primaryForeground),
      secondary: mix(secondary, other.secondary),
      secondaryForeground: mix(secondaryForeground, other.secondaryForeground),
      muted: mix(muted, other.muted),
      mutedForeground: mix(mutedForeground, other.mutedForeground),
      accent: mix(accent, other.accent),
      accentForeground: mix(accentForeground, other.accentForeground),
      destructive: mix(destructive, other.destructive),
      destructiveForeground: mix(destructiveForeground, other.destructiveForeground),
      border: mix(border, other.border),
      input: mix(input, other.input),
      ring: mix(ring, other.ring),
      chart1: mix(chart1, other.chart1),
      chart2: mix(chart2, other.chart2),
      chart3: mix(chart3, other.chart3),
      chart4: mix(chart4, other.chart4),
      chart5: mix(chart5, other.chart5),
      sidebar: mix(sidebar, other.sidebar),
      sidebarForeground: mix(sidebarForeground, other.sidebarForeground),
      sidebarPrimary: mix(sidebarPrimary, other.sidebarPrimary),
      sidebarPrimaryForeground: mix(sidebarPrimaryForeground, other.sidebarPrimaryForeground),
      sidebarAccent: mix(sidebarAccent, other.sidebarAccent),
      sidebarAccentForeground: mix(sidebarAccentForeground, other.sidebarAccentForeground),
      sidebarBorder: mix(sidebarBorder, other.sidebarBorder),
      sidebarRing: mix(sidebarRing, other.sidebarRing),
    );
  }
}

/// Colors that are product chrome, not a design-system / mobile.css token.
class OcProductChrome {
  /// Agent-count chip. Not in the semantic OKLCH catalog.
  static const Color agentAccent = Color(0xFF7A5CFF);
}

extension OcTokensContext on BuildContext {
  OcTokens get oc => OcTokens.of(this);
}

Brightness resolveOcBrightness(ThemeMode mode, Brightness platform) {
  switch (mode) {
    case ThemeMode.light:
      return Brightness.light;
    case ThemeMode.dark:
      return Brightness.dark;
    case ThemeMode.system:
      return platform;
  }
}
