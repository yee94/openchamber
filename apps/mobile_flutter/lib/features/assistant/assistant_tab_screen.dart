import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/assistant_scheduled.dart';
import '../../data/openchamber_http.dart';
import '../../l10n/app_strings.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_primitives.dart';

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
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(session: session, appController: widget.controller),
        ),
      );
    } on OpenChamberHttpException {
      if (mounted) setState(() => _actionError = 'settings.error.loadFailed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final resource = widget.controller.assistantSnapshot;
    final snapshot = resource.value;
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'tabs.assistant'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_actionError != null)
            ListTile(title: Text(t(context, _actionError!), style: TextStyle(color: Theme.of(context).colorScheme.error))),
          if (resource.errorKey != null)
            ListTile(key: const Key('assistant-error'), title: Text(t(context, resource.errorKey!)))
          else if (resource.loading && snapshot == null)
            const Center(child: CircularProgressIndicator())
          else if (snapshot == null || snapshot.assistants.isEmpty)
            SettingsGroup(
              label: t(context, 'tabs.assistant'),
              children: [
                ListTile(
                  key: const Key('assistant-empty'),
                  title: Text(t(context, 'assistant.empty.title')),
                  subtitle: Text(t(context, 'assistant.empty.description')),
                ),
              ],
            )
          else ...[
            SettingsGroup(
              label: t(context, 'tabs.assistant'),
              children: [
                SettingsToggleRow(
                  key: const Key('assistant-enabled'),
                  label: t(context, 'assistant.enabled'),
                  value: snapshot.enabled,
                  onChanged: (value) async {
                    try {
                      await widget.controller.setAssistantsFeatureEnabled(value);
                    } on OpenChamberHttpException {
                      if (mounted) setState(() => _actionError = 'settings.error.saveFailed');
                    }
                  },
                ),
              ],
            ),
            SettingsGroup(
              label: t(context, 'assistant.list'),
              children: [
                for (final item in snapshot.assistants)
                  SettingsNavRow(
                    key: Key('assistant-item-${item.id}'),
                    label: item.name,
                    subtitle: item.modelLabel,
                    onTap: () => _open(item.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
