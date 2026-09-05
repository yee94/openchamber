import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/assistant_scheduled.dart';
import '../../data/openchamber_http.dart';
import '../../l10n/app_strings.dart';
import '../../navigation/platform_route.dart';
import '../../mobile/mobile_assistant_card.dart';
import '../../mobile/mobile_surface.dart';
import '../../theme/ios_chrome.dart';
import '../chat/chat_screen.dart';
import '../projects/action_dialogs.dart';

class AssistantTabScreen extends StatefulWidget {
  const AssistantTabScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AssistantTabScreen> createState() => _AssistantTabScreenState();
}

class _AssistantTabScreenState extends State<AssistantTabScreen> {
  String? _actionError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.loadAssistantSnapshot();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _showAssistantMenu(AssistantRecord item) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Material(
          key: Key('assistant-menu-${item.id}'),
          color: context.oc.pageBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: Key('assistant-menu-edit-${item.id}'),
                title: Text(t(context, 'assistants.menu.edit')),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.controller.requestSettingsSlug('assistants');
                },
              ),
              ListTile(
                key: Key('assistant-menu-delete-${item.id}'),
                title: Text(t(context, 'assistants.settings.delete')),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final confirmed = await showConfirmDialog(
                    context: context,
                    titleKey: 'assistants.settings.delete',
                    messageKey: 'assistants.settings.deleteConfirm',
                    messageParams: {'name': item.name},
                    confirmKey: 'assistants.settings.delete',
                    cancelKey: 'sessions.sidebar.session.rename.cancel',
                    confirmWidgetKey: Key('assistant-delete-confirm-${item.id}'),
                    destructive: true,
                  );
                  if (!confirmed || !mounted) return;
                  await widget.controller.deleteAssistantRecord(item);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _open(String id) async {
    final snapshot = widget.controller.assistantSnapshot.value;
    if (snapshot == null) return;
    AssistantRecord? match;
    for (final item in snapshot.assistants) {
      if (item.id == id) match = item;
    }
    if (match == null) return;
    try {
      final session = await widget.controller.openAssistant(match);
      if (!mounted || session == null) return;
      await Navigator.of(context).push(
        platformPageRoute<void>(
          builder: (_) => ChatScreen(session: session, appController: widget.controller),
        ),
      );
    } on OpenChamberHttpException {
      if (mounted) setState(() => _actionError = 'settings.error.loadFailed');
    }
  }

  String _modeLabel(BuildContext context, AssistantRecord item) {
    return item.mode == 'stateless'
        ? t(context, 'assistant.mode.stateless')
        : t(context, 'assistant.mode.continuous');
  }

  String _summary(BuildContext context, AssistantRecord item) {
    final prompt = item.defaultPrompt?.trim() ?? '';
    if (prompt.isNotEmpty) return prompt;
    return item.mode == 'stateless'
        ? t(context, 'assistant.hint.stateless')
        : t(context, 'assistant.hint.continuous');
  }

  @override
  Widget build(BuildContext context) {
    final resource = widget.controller.assistantSnapshot;
    final snapshot = resource.value;
    return MobileTabPageScaffold(
      title: t(context, 'tabs.assistant'),
      children: [
            if (_actionError != null)
              ListTile(title: Text(t(context, _actionError!), style: TextStyle(color: Theme.of(context).colorScheme.error))),
            if (resource.errorKey != null)
              ListTile(key: const Key('assistant-error'), title: Text(t(context, resource.errorKey!)))
            else if (resource.loading && snapshot == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot != null && snapshot.enabled && snapshot.assistants.isNotEmpty)
              for (final item in snapshot.assistants)
                MobileAssistantCard(
                  pressKey: Key('assistant-item-${item.id}'),
                  seed: item.id,
                  name: item.name,
                  modeLabel: _modeLabel(context, item),
                  summary: _summary(context, item),
                  onOpen: () => _open(item.id),
                  onLongPress: () => unawaited(_showAssistantMenu(item)),
                )
            else if (snapshot != null && !snapshot.enabled)
              MobileFloatingSurface(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t(context, 'assistant.guide.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(t(context, 'assistant.guide.description'), style: TextStyle(color: context.oc.mutedForeground)),
                      const SizedBox(height: 14),
                      FilledButton(
                        key: const Key('assistant-enabled'),
                        onPressed: () async {
                          try {
                            await widget.controller.setAssistantsFeatureEnabled(true);
                          } on OpenChamberHttpException {
                            if (mounted) setState(() => _actionError = 'settings.error.saveFailed');
                          }
                        },
                        child: Text(t(context, 'assistant.guide.enable')),
                      ),
                    ],
                  ),
                ),
              )
            else
              MobileFloatingSurface(
                child: ListTile(
                  key: const Key('assistant-empty'),
                  title: Text(t(context, 'assistant.empty.title')),
                  subtitle: Text(t(context, 'assistant.empty.description')),
                ),
              ),
      ],
    );
  }
}
