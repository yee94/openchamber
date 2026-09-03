import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../motion/selected_spring.dart';
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
    final tokens = context.oc;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
        child: DecoratedBox(
          key: Key('dock-selected-$selectedId'),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(OcOptical.dockCapsuleRadius),
            border: Border.all(color: tokens.mobileBorder, width: 0.5),
            boxShadow: OcElevation.dock(context),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(OcOptical.dockCapsuleRadius),
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
                        onTap: () => onSelect(item.id),
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
    final tokens = context.oc;
    return Pressable(
      key: Key('tab-$id'),
      haptic: HapticStrength.light,
      onPressed: onTap,
      borderRadius: BorderRadius.circular(OcOptical.dockCapsuleRadius),
      child: OcSelectedSpring(
        selected: selected,
        builder: (context, t) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: OcOptical.dockSquircle,
                height: OcOptical.dockSquircle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color.lerp(Colors.transparent, tokens.primary.withValues(alpha: 0.14), t),
                  borderRadius: BorderRadius.circular(OcOptical.dockSquircleRadius),
                ),
                child: OcGlyph(
                  glyph,
                  size: OcOptical.dockGlyph,
                  color: Color.lerp(tokens.mutedForeground, tokens.primary, t),
                  strokeWidth: OcOptical.dockGlyphStroke,
                ),
              ),
              SizedBox(height: OcOptical.dockLabelGap),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: OcOptical.dockLabel,
                  letterSpacing: OcOptical.dockLabelTracking,
                  height: 1.2,
                  fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w400,
                  color: Color.lerp(tokens.mutedForeground, tokens.primary, t),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
