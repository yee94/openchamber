import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../motion/pressable.dart';
import '../motion/selected_spring.dart';
import '../native/haptics.dart';
import 'ios_hero.dart';
import 'oc_elevation.dart';
import 'oc_glyphs.dart';
import 'oc_tokens.dart';

export 'ios_hero.dart' show OcOptical;
export 'oc_elevation.dart' show OcElevation;
export 'oc_tokens.dart' show OcProductChrome, OcTokens, OcTokensContext;

/// Geometry aliases of official `--oc-mobile-*` tokens.
/// Colors come from [OcTokens.of] so Light / Dark / System switch live.
class OcChrome {
  static const Color agentAccent = OcProductChrome.agentAccent;
  static const double cardRadius = OcTokens.surfaceRadius;
  static const double pillRadius = OcTokens.controlRadius;
  static const double dockRadius = OcTokens.dockRadius;
  static const double largeTitleSize = OcTokens.rootTitleSize;
  static const double pageGutter = OcTokens.pageInlineInset;
  static const double tabBarHeight = OcOptical.dockCapsuleHeight;
  static const double headerButtonSize = OcTokens.headerButtonSize;
}

/// Official `--oc-mobile-glass-fill` + `--oc-mobile-glass-blur` (20).
/// WidgetTester paints [BackdropFilter]; this is not a `UIGlassEffect` clone.
class OcFrosted extends StatelessWidget {
  const OcFrosted({
    super.key,
    required this.child,
    this.fill,
    this.sigma = OcOptical.glassBlur,
  });

  final Widget child;
  final Color? fill;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    final plate = ColoredBox(
      color: fill ?? context.oc.glassFill,
      child: child,
    );
    if (sigma <= 0) return plate;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: plate,
    );
  }
}

/// Official header / detail-nav `::after` fade. Not backdrop-filter glass.
class OcHeaderFade extends StatelessWidget {
  const OcHeaderFade({
    super.key,
    required this.safeTop,
    this.opacity = 1,
  });

  final double safeTop;
  final double opacity;

  static double heightFor(double safeTop) =>
      safeTop + OcOptical.detailNavigationHeight + OcOptical.headerFadeExtra;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    final fade = context.oc.headerFade;
    final fadeH = heightFor(safeTop);
    final mid = ((safeTop + fadeH * OcOptical.headerFadeMidStop) / fadeH).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fade, fade, fade.withValues(alpha: 0)],
              stops: [0, mid, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// Official `Button` `mobileGlass` + `mobileIcon` circular chip (40).
class OcGlassChip extends StatelessWidget {
  const OcGlassChip({
    super.key,
    required this.child,
    this.size = OcOptical.headerDiscVisual,
  });

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.oc.glassChipFill,
          // Official glass near-pair + quiet inset. No disc blur,
          // no 8px umbra, no + glow.
          boxShadow: [
            ...OcElevation.control(context),
            ...OcElevation.glassHighlight(context),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Compact glass stadium for agent / model chips — not a solid muted slab.
class OcGlassPill extends StatelessWidget {
  const OcGlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.oc.mobileBorder, width: 0.5),
        boxShadow: OcElevation.highlight(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: OcFrosted(
          fill: context.oc.glassChipFill,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class LargeTitleHeader extends StatelessWidget {
  const LargeTitleHeader({
    super.key,
    required this.title,
    this.trailing,
    this.eyebrow,
  });

  final String title;
  final Widget? trailing;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 8, OcChrome.pageGutter, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      eyebrow!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: OcTokens.textMicro, fontWeight: FontWeight.w500, color: context.oc.mutedForeground),
                    ),
                  ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: OcOptical.largeTitle,
                    fontWeight: FontWeight.w600,
                    letterSpacing: OcOptical.largeTitleTracking,
                    height: OcOptical.largeTitleHeight,
                    color: onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class CircularChromeButton extends StatelessWidget {
  const CircularChromeButton({
    super.key,
    required this.glyph,
    required this.onPressed,
    this.filled = false,
    this.ink = false,
    this.tooltip,
    this.size,
    this.haptic = HapticStrength.light,
  });

  final OcGlyphKind glyph;
  final VoidCallback onPressed;
  final bool filled;
  final bool ink;
  final String? tooltip;
  final double? size;
  final HapticStrength? haptic;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final hit = size ?? (filled ? OcOptical.addButton : OcOptical.searchButton);
    final disc = hit < OcOptical.headerDiscVisual ? hit : OcOptical.headerDiscVisual;
    final glyphWidget = OcGlyph(
      glyph,
      size: ink ? OcOptical.leadingGlyphCompact : OcOptical.headerGlyph,
      strokeWidth: OcOptical.headerGlyphStrokeVisual,
      color: !filled && !ink ? tokens.foreground : tokens.primaryForeground,
    );
    final plate = filled || ink
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: ink ? tokens.foreground : tokens.primary,
              shape: BoxShape.circle,
              boxShadow: OcElevation.control(context),
            ),
            child: SizedBox(
              width: disc,
              height: disc,
              child: Center(child: glyphWidget),
            ),
          )
        : OcGlassChip(size: disc, child: glyphWidget);
    final child = SizedBox(
      width: hit,
      height: hit,
      child: Pressable(
        onPressed: onPressed,
        haptic: haptic,
        highlight: false,
        borderRadius: BorderRadius.circular(hit),
        child: Center(child: plate),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip, child: child);
  }
}

class GroupedInsetCard extends StatelessWidget {
  const GroupedInsetCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.tight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  /// Kept for call-site compat. Elevation is one shared float-shadow family.
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(OcChrome.cardRadius);
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, 12),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: OcElevation.card(context, tight: tight),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: OcFrosted(
          fill: context.oc.floatSurface,
          child: padding == null ? child : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

class InsetTextField extends StatelessWidget {
  const InsetTextField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.obscureText = false,
    this.keyboardType,
    this.autofocus = false,
    this.onChanged,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: TextStyle(fontSize: OcTokens.textUiLabel, color: context.oc.mutedForeground, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            key: fieldKey ?? key,
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            autofocus: autofocus,
            autocorrect: false,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              helperText: helper,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              floatingLabelBehavior: FloatingLabelBehavior.never,
            ),
          ),
        ],
      ),
    );
  }
}

class SearchPillField extends StatelessWidget {
  const SearchPillField({
    super.key,
    required this.onChanged,
    this.hint,
    this.initialValue,
  });

  final ValueChanged<String> onChanged;
  final String? hint;
  final String? initialValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, 12),
      child: TextField(
        key: key,
        controller: initialValue == null ? null : TextEditingController(text: initialValue),
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 10, right: 4),
            child: OcGlyph(OcGlyphKind.search, size: 16, color: context.oc.mutedForeground),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 18),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(OcChrome.pillRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(OcChrome.pillRadius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(OcChrome.pillRadius),
            borderSide: BorderSide.none,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
      ),
    );
  }
}

class SegmentedPill extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.icons,
  });

  final List<String> labels;
  final List<OcGlyphKind>? icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const trackRadius = OcTokens.surfaceRadius;
    const pad = 4.0;
    const gap = 4.0;
    const itemHeight = 40.0;
    const itemRadius = 20.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, OcTokens.pageGap),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(trackRadius),
        boxShadow: OcElevation.highlight(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(trackRadius),
        child: OcFrosted(
          fill: context.oc.glassChipFill,
          child: Padding(
            padding: const EdgeInsets.all(pad),
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i += 1) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(
                    child: Pressable(
                      key: Key('segment-$i'),
                      haptic: HapticStrength.light,
                      onPressed: () => onSelected(i),
                      borderRadius: BorderRadius.circular(itemRadius),
                      child: OcSelectedSpring(
                        selected: selectedIndex == i,
                        builder: (context, t) {
                          final tokens = context.oc;
                          return SizedBox(
                            height: itemHeight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color.lerp(
                                  Colors.transparent,
                                  tokens.card.withValues(alpha: 0.55),
                                  t,
                                ),
                                borderRadius: BorderRadius.circular(itemRadius),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (icons != null) ...[
                                    OcGlyph(
                                      icons![i],
                                      size: 16,
                                      strokeWidth: OcOptical.listGlyphStroke,
                                      color: Color.lerp(tokens.mutedForeground, tokens.foreground, t),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Text(
                                      labels[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: OcTokens.textUiHeader,
                                        height: 1.0,
                                        fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w400,
                                        color: Color.lerp(tokens.mutedForeground, tokens.foreground, t),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.trailing,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, 12),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(OcTokens.surfaceRadius),
                boxShadow: OcElevation.highlight(context),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(OcTokens.surfaceRadius),
                child: OcFrosted(
                  fill: context.oc.glassChipFill,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        for (var i = 0; i < labels.length; i += 1) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Expanded(
                            child: Pressable(
                              key: Key('filter-$i'),
                              haptic: HapticStrength.light,
                              onPressed: () => onSelected(i),
                              borderRadius: BorderRadius.circular(20),
                              child: OcSelectedSpring(
                                selected: selectedIndex == i,
                                builder: (context, t) {
                                  final tokens = context.oc;
                                  return SizedBox(
                                    height: 40,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color.lerp(
                                  Colors.transparent,
                                  tokens.card.withValues(alpha: 0.55),
                                  t,
                                ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Center(
                                        child: Text(
                                          labels[i],
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: OcTokens.textUiLabel,
                                            height: 1.0,
                                            fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w400,
                                            color: Color.lerp(tokens.mutedForeground, tokens.foreground, t),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Official `.oc-mobile-detail-navigation`: sticky, transparent, 56px band
/// under the status bar. Content scrolls underneath. Not a frosted banner.
class PushedNavBar extends StatelessWidget implements PreferredSizeWidget {
  const PushedNavBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingKey,
    this.trailing,
    this.busy = false,
  });

  final String title;
  final String? subtitle;
  final Key? leadingKey;
  final Widget? trailing;
  final bool busy;

  static double overlayHeight(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).top + OcOptical.detailNavigationHeight;

  @override
  Size get preferredSize => const Size.fromHeight(OcOptical.detailNavigationHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final view = MediaQuery.viewPaddingOf(context);
    final inlineLeft = view.left > OcOptical.detailActionEdgeInset
        ? view.left
        : OcOptical.detailActionEdgeInset;
    final inlineRight = view.right > OcOptical.detailActionEdgeInset
        ? view.right
        : OcOptical.detailActionEdgeInset;
    final fadeH = OcHeaderFade.heightFor(view.top);
    final bandH = view.top + OcOptical.detailNavigationHeight;
    final disc = OcOptical.headerDisc;

    Widget actionDisc({required Widget child, Key? key, VoidCallback? onPressed}) {
      final chip = OcGlassChip(size: OcOptical.headerDiscVisual, child: child);
      final hit = SizedBox(
        width: disc,
        height: disc,
        child: Center(child: chip),
      );
      if (onPressed == null) return hit;
      return Pressable(
        key: key,
        haptic: HapticStrength.light,
        highlight: false,
        onPressed: onPressed,
        child: hit,
      );
    }

    return SizedBox(
      height: bandH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: fadeH,
            child: OcHeaderFade(safeTop: view.top, opacity: 0.58),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(inlineLeft, view.top, inlineRight, 0),
            child: SizedBox(
              height: OcOptical.detailNavigationHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: OcOptical.detailActionColumn,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Tooltip(
                        message: t(context, 'chat.back'),
                        child: actionDisc(
                          key: leadingKey,
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: OcGlyph(
                            OcGlyphKind.chevronBack,
                            size: OcOptical.headerGlyph,
                            strokeWidth: OcOptical.headerGlyphStrokeVisual,
                            color: tokens.foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: OcOptical.chatTitle,
                            fontWeight: FontWeight.lerp(FontWeight.w600, FontWeight.w700, 0.5),
                            letterSpacing: OcOptical.chatTitleTracking,
                            height: OcOptical.chatTitleHeight,
                            color: tokens.foreground,
                          ),
                        ),
                        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: OcOptical.detailSubtitleGap),
                          Text(
                            key: const Key('chat-header-subtitle'),
                            subtitle!,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: OcOptical.detailSubtitle,
                              fontWeight: FontWeight.w400,
                              height: OcOptical.detailSubtitleHeight,
                              color: tokens.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: trailing == null && !busy
                        ? OcOptical.detailActionColumn
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (busy)
                          SizedBox(
                            width: disc,
                            height: disc,
                            child: Center(
                              child: OcGlassChip(
                                size: OcOptical.headerDiscVisual,
                                child: SizedBox(
                                  key: const Key('chat-busy'),
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: tokens.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (busy && trailing != null) const SizedBox(width: 8),
                        if (trailing != null) trailing!,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
