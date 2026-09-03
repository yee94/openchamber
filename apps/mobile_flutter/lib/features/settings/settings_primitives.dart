import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, OcTokens.sectionStackGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: OcTokens.sectionGap),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                  ),
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(OcChrome.cardRadius),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.label,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      haptic: onTap == null ? null : HapticStrength.light,
      onPressed: onTap,
      child: ListTile(
        minVerticalPadding: 11,
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing ?? OcGlyph(OcGlyphKind.chevronRight, size: 16, color: context.oc.mutedForeground),
      ),
    );
  }
}

class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class SettingsValueRow extends StatelessWidget {
  const SettingsValueRow({
    super.key,
    required this.label,
    this.subtitle,
  });

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
    );
  }
}

class SettingsPageScaffold extends StatelessWidget {
  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navH = PushedNavBar.overlayHeight(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: navH),
              child: child,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PushedNavBar(
              title: title,
              leadingKey: const Key('settings-back'),
            ),
          ),
        ],
      ),
    );
  }
}

String groupLabel(BuildContext context, Enum group) {
  switch (group.name) {
    case 'connection':
      return t(context, 'settings.group.connection');
    case 'personalization':
      return t(context, 'settings.group.personalization');
    case 'workspace':
      return t(context, 'settings.group.workspace');
    case 'opencode':
      return t(context, 'settings.group.opencode');
    case 'content':
      return t(context, 'settings.group.content');
    default:
      return t(context, 'settings.group.system');
  }
}
