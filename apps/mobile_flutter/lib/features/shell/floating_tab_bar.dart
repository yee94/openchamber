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
    final hero = OcIosHero.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
        child: DecoratedBox(
          key: Key('dock-selected-$selectedId'),
          decoration: BoxDecoration(
            color: hero.card,
            borderRadius: BorderRadius.circular(OcChrome.dockRadius),
            border: Border.all(color: hero.separator, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: hero.isDark ? 0.40 : 0.08),
                blurRadius: 18,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(OcChrome.dockRadius),
            clipBehavior: Clip.antiAlias,
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
    final hero = OcIosHero.of(context);
    return InkWell(
      key: Key('tab-$id'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(OcChrome.dockRadius),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? hero.tintFill : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: OcGlyph(
              glyph,
              size: 17,
              color: selected ? hero.tint : hero.secondaryLabel,
              strokeWidth: selected ? 1.3 : 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? hero.tint : hero.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}
