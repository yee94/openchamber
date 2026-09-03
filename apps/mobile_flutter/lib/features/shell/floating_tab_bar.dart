import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../motion/selected_spring.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

/// Flutter-painted homepage dock for Android and WidgetTester.
///
/// Official analogue: `MobileFloatingBottomBar` + `MobileTabBar` selected
/// `bg-interactive-selection/55` on the **whole** tab slot. Real iOS uses
/// [IosTabBarHost] / UITabBarController — this is not a glass clone.
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
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final radius = BorderRadius.circular(OcTokens.dockRadius);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        OcTokens.dockInlineInset,
        0,
        OcTokens.dockInlineInset,
        math.max(OcOptical.dockBottomPad, safeBottom),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: OcOptical.dockMaxWidth),
          child: DecoratedBox(
            key: Key('dock-selected-$selectedId'),
            decoration: BoxDecoration(
              color: tokens.dockFill,
              borderRadius: radius,
              border: Border.all(color: tokens.mobileBorder, width: 0.5),
              boxShadow: OcElevation.dock(context),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                key: const Key('dock-capsule'),
                height: OcTokens.dockHeight,
                child: Padding(
                  padding: const EdgeInsets.all(OcOptical.dockInnerInset),
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
    final tabRadius = BorderRadius.circular(OcOptical.dockTabRadius);
    return SizedBox.expand(
      child: Pressable(
        key: Key('tab-$id'),
        haptic: HapticStrength.light,
        onPressed: onTap,
        borderRadius: tabRadius,
        child: OcSelectedSpring(
          selected: selected,
          builder: (context, t) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(Colors.transparent, tokens.interactiveSelection, t),
                borderRadius: tabRadius,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OcGlyph(
                    glyph,
                    size: OcOptical.dockGlyph,
                    color: Color.lerp(tokens.mutedForeground, tokens.primary, t),
                    strokeWidth: OcOptical.dockGlyphStroke,
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
              ),
            );
          },
        ),
      ),
    );
  }
}
