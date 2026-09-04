import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

/// Official `getSettingsNavIcon` — Remix sprite names from SettingsView.
OcGlyphKind settingsNavIcon(String slug) {
  switch (slug) {
    case 'instances':
      return OcGlyphKind.server;
    case 'appearance':
      return OcGlyphKind.palette;
    case 'chat':
      return OcGlyphKind.chatAi;
    case 'notifications':
      return OcGlyphKind.notification;
    case 'sessions':
      return OcGlyphKind.chatHistory;
    case 'summary-ai':
    case 'magic-prompts':
      return OcGlyphKind.aiGenerate;
    case 'projects':
      return OcGlyphKind.folder;
    case 'git':
      return OcGlyphKind.branch;
    case 'providers':
      return OcGlyphKind.cloud;
    case 'agents':
      return OcGlyphKind.nodeTree;
    case 'assistants':
      return OcGlyphKind.robot;
    case 'behavior':
      return OcGlyphKind.brain;
    case 'commands':
      return OcGlyphKind.slashCommands;
    case 'mcp':
      return OcGlyphKind.mcp;
    case 'plugins':
      return OcGlyphKind.code;
    case 'snippets':
      return OcGlyphKind.chatThread;
    case 'skills.installed':
      return OcGlyphKind.bookOpen;
    case 'usage':
      return OcGlyphKind.barChart;
    case 'about':
      return OcGlyphKind.information;
    default:
      return OcGlyphKind.gear;
  }
}

/// Official `MobileSettingsGroup` — quiet label + one grouped card.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, OcTokens.sectionStackGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: OcTokens.sectionGap),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tokens.mutedForeground,
                    fontSize: OcTokens.textMicro,
                    fontWeight: FontWeight.w400,
                    height: 16 / 12,
                  ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.settingsGroupBackground,
              borderRadius: BorderRadius.circular(OcOptical.settingsGroupRadius),
              border: Border.all(color: tokens.formSurfaceBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(OcOptical.settingsGroupRadius - 1),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: tokens.formRowDivider)),
                        ),
                        child: const SizedBox(width: double.infinity, height: 0),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Official mobile Settings home row: leading icon + title + chevron.
/// Descriptions stay on detail pages (and search-result rows).
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.label,
    this.subtitle,
    this.icon,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String? subtitle;
  final OcGlyphKind? icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    return Pressable(
      haptic: onTap == null ? null : HapticStrength.light,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: OcOptical.settingsRowMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: OcOptical.settingsRowInset),
          child: Row(
            children: [
              if (icon != null) ...[
                OcGlyph(
                  icon!,
                  size: OcOptical.settingsNavIcon,
                  strokeWidth: OcOptical.settingsGlyphStrokeVisual,
                  color: tokens.foreground,
                ),
                const SizedBox(width: OcOptical.settingsRowGap),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: tokens.foreground,
                            fontWeight: FontWeight.w400,
                            fontSize: OcTokens.textUiLabel,
                          ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.mutedForeground.withValues(alpha: 0.7),
                              fontSize: OcTokens.textMicro,
                            ),
                      ),
                  ],
                ),
              ),
              trailing ??
                  OcGlyph(
                    OcGlyphKind.chevronRight,
                    size: OcOptical.settingsNavIcon,
                    strokeWidth: OcOptical.settingsGlyphStrokeVisual,
                    color: tokens.mutedForeground.withValues(alpha: 0.6),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Official `.oc-mobile-settings-search-field` — field bg + glass shadow.
class SettingsSearchField extends StatelessWidget {
  const SettingsSearchField({
    super.key,
    required this.onChanged,
    this.query = '',
    this.onClear,
  });

  final ValueChanged<String> onChanged;
  final String query;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, OcTokens.sectionStackGap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.fieldBackground,
          borderRadius: BorderRadius.circular(OcTokens.controlRadius),
          boxShadow: OcElevation.control(context),
        ),
        child: SizedBox(
          height: OcOptical.settingsSearchMinHeight,
          child: TextField(
            key: const Key('settings-search'),
            onChanged: onChanged,
            style: TextStyle(fontSize: OcTokens.textUiLabel, color: tokens.foreground),
            decoration: InputDecoration(
              hintText: t(context, 'settings.search.placeholder'),
              hintStyle: TextStyle(color: tokens.mutedForeground.withValues(alpha: 0.7)),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: OcGlyph(
                  OcGlyphKind.search,
                  size: OcOptical.searchFieldGlyph,
                  strokeWidth: OcOptical.settingsGlyphStrokeVisual,
                  color: tokens.mutedForeground,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 18),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: t(context, 'settings.search.clear'),
                      onPressed: onClear,
                      icon: OcGlyph(
                        OcGlyphKind.xmark,
                        size: 14,
                        strokeWidth: OcOptical.settingsGlyphStrokeVisual,
                        color: tokens.mutedForeground,
                      ),
                    ),
              filled: false,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              floatingLabelBehavior: FloatingLabelBehavior.never,
            ),
          ),
        ),
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
      backgroundColor: context.oc.pageBackground,
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
