import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/assistant_scheduled.dart';
import '../../data/openchamber_http.dart';
import '../../l10n/app_strings.dart';
import '../../theme/ios_chrome.dart';
import '../chat/chat_screen.dart';

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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            LargeTitleHeader(title: t(context, 'tabs.assistant')),
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
                GroupedInsetCard(
                  child: InkWell(
                    key: Key('assistant-item-${item.id}'),
                    onTap: () => _open(item.id),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                            child: Text(
                              item.name.isEmpty ? '?' : item.name.substring(0, 1),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _modeLabel(context, item),
                                      style: const TextStyle(fontSize: 13, color: OcChrome.secondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _summary(context, item),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: OcChrome.secondary, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
            else if (snapshot != null && !snapshot.enabled)
              GroupedInsetCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t(context, 'assistant.guide.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(t(context, 'assistant.guide.description'), style: const TextStyle(color: OcChrome.secondary)),
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
              GroupedInsetCard(
                child: ListTile(
                  key: const Key('assistant-empty'),
                  title: Text(t(context, 'assistant.empty.title')),
                  subtitle: Text(t(context, 'assistant.empty.description')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
