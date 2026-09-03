import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'ios_hero.dart';
import 'oc_glyphs.dart';
import 'oc_tokens.dart';

export 'ios_hero.dart' show HeroSurface, OcIosHero;
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
      padding: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 4, OcChrome.pageGutter, 6),
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
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                    height: 1.05,
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
  });

  final OcGlyphKind glyph;
  final VoidCallback onPressed;
  final bool filled;
  final bool ink;
  final String? tooltip;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final hero = OcIosHero.of(context);
    final diameter = size ?? (filled ? 36.0 : 32.0);
    final fill = !filled
        ? hero.card
        : ink
            ? hero.navy
            : hero.tint;
    final child = Material(
      color: fill,
      shape: const CircleBorder(),
      elevation: filled ? 0.6 : 0.3,
      shadowColor: Colors.black.withValues(alpha: filled ? 0.10 : 0.06),
      surfaceTintColor: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Center(
            child: OcGlyph(
              glyph,
              size: filled ? 15 : 15,
              strokeWidth: 1.15,
              color: !filled
                  ? hero.secondaryLabel
                  : ink
                      ? hero.card
                      : Colors.white,
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
      margin: margin ?? const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, 8),
      padding: padding,
      decoration: BoxDecoration(
        color: OcIosHero.of(context).card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.36 : 0.055),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 6),
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
        color: OcIosHero.of(context).track,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i += 1)
            Expanded(
              child: InkWell(
                key: Key('segment-$i'),
                borderRadius: BorderRadius.circular(9),
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: selectedIndex == i ? OcIosHero.of(context).card : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: selectedIndex == i
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
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
                          size: 14,
                          strokeWidth: 1.2,
                          color: selectedIndex == i
                              ? OcIosHero.of(context).label
                              : OcIosHero.of(context).secondaryLabel,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selectedIndex == i ? FontWeight.w600 : FontWeight.w400,
                          color: selectedIndex == i
                              ? OcIosHero.of(context).label
                              : OcIosHero.of(context).secondaryLabel,
                        ),
                      ),
                    ],
                  ),
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
                    child: InkWell(
                      key: Key('filter-$i'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelected(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: selectedIndex == i ? FontWeight.w600 : FontWeight.w400,
                            color: selectedIndex == i
                                ? OcIosHero.of(context).label
                                : OcIosHero.of(context).secondaryLabel,
                          ),
                        ),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: OcIosHero.of(context).label,
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
          if (trailing != null) trailing! else SizedBox(width: OcChrome.headerButtonSize),
        ],
      ),
    );
  }
}
