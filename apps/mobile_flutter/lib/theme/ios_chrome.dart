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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: ColoredBox(
        color: fill ?? context.oc.glassFill,
        child: child,
      ),
    );
  }
}

/// Official `Button` `mobileGlass` + `mobileIcon` circular chip.
class OcGlassChip extends StatelessWidget {
  const OcGlassChip({
    super.key,
    required this.child,
    this.size = OcOptical.chatChip,
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
          boxShadow: OcElevation.control(context),
        ),
        child: ClipOval(
          child: OcFrosted(
            fill: context.oc.glassChipFill,
            child: Center(child: child),
          ),
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
    final disc = hit < OcOptical.headerDisc ? hit : OcOptical.headerDisc;
    final glyphWidget = OcGlyph(
      glyph,
      size: OcOptical.headerGlyph,
      strokeWidth: OcOptical.headerGlyphStroke,
      color: !filled ? tokens.foreground : tokens.primaryForeground,
    );
    final plate = filled
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
    final dark = context.oc.isDark;
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, 12),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: OcElevation.card(context, tight: tight),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: context.oc.card,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: dark ? Border.all(color: context.oc.mobileBorder, width: 0.5) : null,
            ),
            child: padding == null ? child : Padding(padding: padding!, child: child),
          ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 4, OcChrome.pageGutter, 12),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.oc.muted,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i += 1)
            Expanded(
              child: Pressable(
                key: Key('segment-$i'),
                haptic: HapticStrength.light,
                onPressed: () => onSelected(i),
                borderRadius: BorderRadius.circular(10),
                child: OcSelectedSpring(
                  selected: selectedIndex == i,
                  builder: (context, t) {
                    final tokens = context.oc;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Color.lerp(Colors.transparent, tokens.card, t),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: t > 0.01
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.025 * t),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icons != null) ...[
                            OcGlyph(
                              icons![i],
                              size: OcOptical.toolbarGlyph,
                              strokeWidth: OcOptical.headerGlyphStroke,
                              color: Color.lerp(tokens.mutedForeground, tokens.foreground, t),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 0.35,
                              height: 1.25,
                              fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w400,
                              color: Color.lerp(tokens.mutedForeground, tokens.foreground, t),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
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
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: context.oc.muted.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i += 1)
                    Expanded(
                      child: Pressable(
                        key: Key('filter-$i'),
                        haptic: HapticStrength.light,
                        onPressed: () => onSelected(i),
                        borderRadius: BorderRadius.circular(14),
                        child: OcSelectedSpring(
                          selected: selectedIndex == i,
                          builder: (context, t) {
                            final tokens = context.oc;
                            return Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              decoration: BoxDecoration(
                                color: Color.lerp(Colors.transparent, tokens.card.withValues(alpha: 0.92), t),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                labels[i],
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 0.28,
                                  height: 1.2,
                                  fontWeight: t > 0.5 ? FontWeight.w500 : FontWeight.w400,
                                  color: Color.lerp(tokens.mutedForeground, tokens.foreground, t),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
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

class PushedNavBar extends StatelessWidget implements PreferredSizeWidget {
  const PushedNavBar({
    super.key,
    required this.title,
    this.leadingKey,
    this.trailing,
    this.busy = false,
  });

  final String title;
  final Key? leadingKey;
  final Widget? trailing;
  final bool busy;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final top = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: OcFrosted(
        fill: tokens.background.withValues(alpha: 0.55),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, top + 6, 12, 6),
          child: Row(
            children: [
              Tooltip(
                message: t(context, 'chat.back'),
                child: Pressable(
                  key: leadingKey,
                  haptic: HapticStrength.light,
                  highlight: false,
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: OcGlassChip(
                    child: OcGlyph(
                      OcGlyphKind.chevronBack,
                      size: OcOptical.headerGlyph,
                      strokeWidth: OcOptical.headerGlyphStroke,
                      color: tokens.foreground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: OcOptical.chatTitle,
                    fontWeight: FontWeight.w600,
                    letterSpacing: OcOptical.chatTitleTracking,
                    height: OcOptical.chatTitleHeight,
                    color: tokens.foreground,
                  ),
                ),
              ),
              if (busy) ...[
                const SizedBox(width: 8),
                OcGlassChip(
                  child: SizedBox(
                    key: const Key('chat-busy'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: tokens.mutedForeground,
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else
                const SizedBox(width: OcOptical.chatChip),
            ],
          ),
        ),
      ),
    );
  }
}
