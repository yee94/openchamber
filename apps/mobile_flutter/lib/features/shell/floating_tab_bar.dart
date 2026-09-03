import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../native/haptics.dart';
import '../../theme/app_theme.dart';
import '../../theme/ios_chrome.dart';

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

  static const _items = <({String id, IconData icon, String labelKey})>[
    (id: 'projects', icon: CupertinoIcons.folder, labelKey: 'tabs.projects'),
    (id: 'assistant', icon: CupertinoIcons.sparkles, labelKey: 'tabs.assistant'),
    (id: 'scheduled', icon: CupertinoIcons.calendar, labelKey: 'tabs.scheduled'),
    (id: 'settings', icon: CupertinoIcons.gear, labelKey: 'tabs.settings'),
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
          color: Theme.of(context).brightness == Brightness.dark
              ? OcChrome.dockFillDark
              : OcChrome.dockFillLight,
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(OcChrome.dockRadius),
          child: SizedBox(
            height: OcChrome.tabBarHeight,
            child: Row(
              children: [
                for (final item in _items)
                  Expanded(
                    child: _TabSlot(
                      id: item.id,
                      icon: item.icon,
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
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final IconData icon;
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? primary.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected ? primary : OcTokens.mutedLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? primary : OcTokens.mutedLight,
            ),
          ),
        ],
      ),
    );
  }
}
