import 'package:flutter/material.dart';

import '../../data/composer_session_pick.dart';
import '../../data/settings_remote.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

Future<ComposerModelOption?> showComposerModelPicker({
  required BuildContext context,
  required List<ComposerModelOption> models,
  required String selectedId,
}) {
  return showModalBottomSheet<ComposerModelOption>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _PickerSheet<ComposerModelOption>(
        sheetKey: const Key('composer-model-sheet'),
        titleKey: 'chat.modelControls.selectModel',
        items: models,
        selectedId: selectedId,
        idOf: (item) => item.id,
        titleOf: (item) => item.title,
        subtitleOf: (item) => item.providerName,
      );
    },
  );
}

class ComposerSessionChips extends StatelessWidget {
  const ComposerSessionChips({
    super.key,
    required this.pick,
    required this.models,
    required this.agents,
    required this.onChanged,
  });

  final ComposerSessionPick pick;
  final List<ComposerModelOption> models;
  final List<SettingsNamedItem> agents;
  final ValueChanged<ComposerSessionPick> onChanged;

  @override
  Widget build(BuildContext context) {
    var modelLabel = pick.modelId;
    for (final item in models) {
      if (item.id == pick.modelKey) {
        modelLabel = item.title;
        break;
      }
    }
    final agentLabel = pick.agent ?? t(context, 'chat.modelControls.noAgentSelected');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          Flexible(
            child: _Chip(
              id: 'composer-model',
              label: modelLabel,
              glyph: OcGlyphKind.sparkles,
              onPressed: () => _showModelSheet(context),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _Chip(
              id: 'composer-agent',
              label: agentLabel,
              glyph: OcGlyphKind.robot,
              onPressed: () => _showAgentSheet(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showModelSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<ComposerModelOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _PickerSheet<ComposerModelOption>(
          sheetKey: const Key('composer-model-sheet'),
          titleKey: 'chat.modelControls.selectModel',
          items: models,
          selectedId: pick.modelKey,
          idOf: (item) => item.id,
          titleOf: (item) => item.title,
          subtitleOf: (item) => item.providerName,
        );
      },
    );
    if (selected == null) return;
    onChanged(pick.copyWith(providerId: selected.providerId, modelId: selected.modelId));
  }

  Future<void> _showAgentSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<SettingsNamedItem>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _PickerSheet<SettingsNamedItem>(
          sheetKey: const Key('composer-agent-sheet'),
          titleKey: 'chat.modelControls.selectAgent',
          items: agents,
          selectedId: pick.agent,
          idOf: (item) => item.id,
          titleOf: (item) => item.title,
          subtitleOf: (item) => item.subtitle,
        );
      },
    );
    if (selected == null) return;
    onChanged(pick.copyWith(agent: selected.id));
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.id,
    required this.label,
    required this.glyph,
    required this.onPressed,
  });

  final String id;
  final String label;
  final OcGlyphKind glyph;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: Key(id),
      haptic: HapticStrength.light,
      highlight: false,
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.oc.surfaceSubtle,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OcGlyph(glyph, size: 12, color: context.oc.mutedForeground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.oc.foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.sheetKey,
    required this.titleKey,
    required this.items,
    required this.selectedId,
    required this.idOf,
    required this.titleOf,
    required this.subtitleOf,
  });

  final Key sheetKey;
  final String titleKey;
  final List<T> items;
  final String? selectedId;
  final String Function(T item) idOf;
  final String Function(T item) titleOf;
  final String? Function(T item) subtitleOf;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: sheetKey,
      color: context.oc.pageBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t(context, titleKey), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.oc.foreground)),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(t(context, 'chat.modelControls.noModelsFound'), style: TextStyle(color: context.oc.mutedForeground)),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in items)
                        ListTile(
                          key: Key('composer-pick-${idOf(item)}'),
                          title: Text(titleOf(item)),
                          subtitle: subtitleOf(item) == null ? null : Text(subtitleOf(item)!),
                          selected: idOf(item) == selectedId,
                          onTap: () => Navigator.of(context).pop(item),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
