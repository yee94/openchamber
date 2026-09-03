import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'oc_glyphs.dart';

/// Official mobile chrome shared by iOS (Cupertino + UIKit overlays) and
/// Android (same IA, Material 3 surfaces, no fake liquid glass).
class OcChrome {
  static const Color groupedLight = Color(0xFFF2F2F7);
  static const Color groupedDark = Color(0xFF000000);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1C1C1E);
  static const Color title = Color(0xFF1C1C1E);
  static const Color secondary = Color(0xFF8E8E93);
  static const Color dockFillLight = Color(0xF2FFFFFF);
  static const Color dockFillDark = Color(0xE61C1C1E);
  static const double cardRadius = 22;
  static const double pillRadius = 28;
  static const double dockRadius = 34;
  static const double largeTitleSize = 34;
  static const double pageGutter = 16;
  static const double tabBarHeight = 64;
  static const double headerButtonSize = 40;
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
      padding: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 8, OcChrome.pageGutter, 8),
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: OcChrome.secondary),
                    ),
                  ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: OcChrome.largeTitleSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    height: 1.1,
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
    this.tooltip,
  });

  final OcGlyphKind glyph;
  final VoidCallback onPressed;
  final bool filled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final child = Material(
      color: filled ? primary : Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: filled ? 2 : 0,
      shadowColor: filled ? primary.withValues(alpha: 0.28) : Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: OcChrome.headerButtonSize,
          height: OcChrome.headerButtonSize,
          child: Center(
            child: OcGlyph(glyph, size: 18, color: filled ? Colors.white : Theme.of(context).colorScheme.onSurface),
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
      margin: margin ?? const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, 16),
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(OcChrome.cardRadius),
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
          Text(label, style: const TextStyle(fontSize: 13, color: OcChrome.secondary, fontWeight: FontWeight.w500)),
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
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 10, right: 4),
            child: OcGlyph(OcGlyphKind.search, size: 16, color: OcChrome.secondary),
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(OcChrome.pillRadius),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i += 1)
            Expanded(
              child: InkWell(
                key: Key('segment-$i'),
                borderRadius: BorderRadius.circular(OcChrome.pillRadius),
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(OcChrome.pillRadius),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icons != null) ...[
                        OcGlyph(
                          icons![i],
                          size: 16,
                          color: selectedIndex == i
                              ? Theme.of(context).colorScheme.onSurface
                              : OcChrome.secondary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: selectedIndex == i ? FontWeight.w600 : FontWeight.w500,
                          color: selectedIndex == i
                              ? Theme.of(context).colorScheme.onSurface
                              : OcChrome.secondary,
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
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(OcChrome.pillRadius),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i += 1)
                    Expanded(
                      child: InkWell(
                        key: Key('filter-$i'),
                        borderRadius: BorderRadius.circular(OcChrome.pillRadius),
                        onTap: () => onSelected(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            labels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selectedIndex == i ? FontWeight.w600 : FontWeight.w500,
                              color: selectedIndex == i
                                  ? Theme.of(context).colorScheme.onSurface
                                  : OcChrome.secondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class StatusAttentionStrip extends StatelessWidget {
  const StatusAttentionStrip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter, vertical: 8),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
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
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            CircularChromeButton(
              key: leadingKey,
              glyph: OcGlyphKind.chevronBack,
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: t(context, 'chat.back'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: OcChrome.headerButtonSize,
                  height: OcChrome.headerButtonSize,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (trailing != null) trailing! else const SizedBox(width: OcChrome.headerButtonSize),
          ],
        ),
    );
  }
}
