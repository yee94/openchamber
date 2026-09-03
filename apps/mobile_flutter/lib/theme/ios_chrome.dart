import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../motion/pressable.dart';
import '../motion/selected_spring.dart';
import '../native/haptics.dart';
import 'ios_hero.dart';
import 'oc_glyphs.dart';
import 'oc_tokens.dart';

export 'ios_hero.dart' show OcOptical;
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
  static const double tabBarHeight = OcTokens.dockHeight;
  static const double headerButtonSize = OcTokens.headerButtonSize;
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
    final diameter = size ?? (filled ? OcOptical.addButton : OcOptical.searchButton);
    final fill = !filled
        ? tokens.card
        : ink
            ? tokens.foreground
            : tokens.primary;
    final child = Material(
      color: fill,
      shape: const CircleBorder(),
      elevation: filled ? 0.6 : 0.3,
      shadowColor: Colors.black.withValues(alpha: filled ? 0.10 : 0.06),
      surfaceTintColor: Colors.transparent,
      child: Pressable(
        onPressed: onPressed,
        haptic: haptic,
        highlight: false,
        borderRadius: BorderRadius.circular(diameter),
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Center(
            child: OcGlyph(
              glyph,
              size: OcOptical.headerGlyph,
              strokeWidth: OcOptical.headerGlyphStroke,
              color: !filled ? tokens.mutedForeground : tokens.primaryForeground,
            ),
          ),
        ),
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
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, 12),
      padding: padding,
      decoration: BoxDecoration(
        color: context.oc.card,
        borderRadius: BorderRadius.circular(OcChrome.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.032),
            blurRadius: 12,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.oc.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i += 1)
            Expanded(
              child: Pressable(
                key: Key('segment-$i'),
                haptic: HapticStrength.light,
                onPressed: () => onSelected(i),
                borderRadius: BorderRadius.circular(9),
                child: OcSelectedSpring(
                  selected: selectedIndex == i,
                  builder: (context, t) {
                    final tokens = context.oc;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: Color.lerp(Colors.transparent, tokens.card, t),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: t > 0.01
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04 * t),
                                  blurRadius: 2,
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
                              size: 12,
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
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i += 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pressable(
                      key: Key('filter-$i'),
                      haptic: HapticStrength.light,
                      onPressed: () => onSelected(i),
                      borderRadius: BorderRadius.circular(16),
                      child: OcSelectedSpring(
                        selected: selectedIndex == i,
                        builder: (context, t) {
                          final tokens = context.oc;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Color.lerp(Colors.transparent, tokens.muted, t * 0.9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 0.55,
                                height: 1.25,
                                fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w400,
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
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatusAttentionStrip extends StatelessWidget {
  const StatusAttentionStrip({super.key, required this.label, this.moreLabel});

  final String label;
  final String? moreLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('projects-attention-strip'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter, vertical: 8),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500),
            ),
          ),
          if (moreLabel != null) ...[
            Text(moreLabel!, style: TextStyle(fontSize: OcTokens.textUiLabel, color: context.oc.mutedForeground)),
            OcGlyph(OcGlyphKind.chevronRight, size: 13, color: context.oc.mutedForeground),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: Row(
        children: [
          CircularChromeButton(
            key: leadingKey,
            glyph: OcGlyphKind.chevronBack,
            tooltip: t(context, 'chat.back'),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.45,
                      height: 1.28,
                      color: context.oc.foreground,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            Padding(
              key: const Key('chat-busy'),
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.oc.mutedForeground,
                ),
              ),
            ),
          if (trailing != null) trailing! else const SizedBox(width: OcOptical.searchButton),
        ],
      ),
    );
  }
}
