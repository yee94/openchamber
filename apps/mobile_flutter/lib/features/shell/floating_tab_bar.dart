import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

/// Flutter-painted homepage dock for Android and WidgetTester.
/// Real iOS uses [IosTabBarHost] / UITabBarController — this is not a glass clone.
class FloatingCapsuleTabBar extends StatelessWidget {
  const FloatingCapsuleTabBar({
    super.key,
    required this.selectedId,
    required this.onSelect,
  });

  final String selectedId;
  final ValueChanged<String> onSelect;

  static const _items = <({String id, OcGlyphKind glyph, String labelKey})>[
    (id: 'projects', glyph: OcGlyphKind.folder, labelKey: 'tabs.projects'),
    (id: 'assistant', glyph: OcGlyphKind.sparkles, labelKey: 'tabs.assistant'),
    (id: 'scheduled', glyph: OcGlyphKind.calendar, labelKey: 'tabs.scheduled'),
    (id: 'settings', glyph: OcGlyphKind.gear, labelKey: 'tabs.settings'),
  ];

  @override
  Widget build(BuildContext context) {
    assert(_items.length == 4);
    final haptics = NativeHaptics();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Material(
          key: Key('dock-selected-$selectedId'),
          color: context.oc.dockFill,
          elevation: 6,
          shadowColor: context.oc.surfaceForeground.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(OcChrome.dockRadius),
          child: SizedBox(
            height: OcChrome.tabBarHeight,
            child: Row(
              children: [
                for (final item in _items)
                  Expanded(
                    child: _TabSlot(
                      id: item.id,
                      glyph: item.glyph,
                      label: t(context, item.labelKey),
                      selected: selectedId == item.id,
                      onTap: () {
                        haptics.impact(HapticStrength.light);
                        onSelect(item.id);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.id,
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final OcGlyphKind glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      key: Key('tab-$id'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(OcChrome.dockRadius),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? primary.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: OcGlyph(
              glyph,
              size: 20,
              color: selected ? primary : context.oc.mutedForeground,
              strokeWidth: selected ? 2.0 : 1.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? primary : context.oc.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
