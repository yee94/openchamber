import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/project_id.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';

Future<bool> showScheduledTaskSheet({
  required BuildContext context,
  required AppController controller,
}) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => ScheduledTaskSheet(controller: controller),
  );
  return created == true;
}

class ScheduledTaskSheet extends StatefulWidget {
  const ScheduledTaskSheet({super.key, required this.controller});

  final AppController controller;

  @override
  State<ScheduledTaskSheet> createState() => _ScheduledTaskSheetState();
}

class _ScheduledTaskSheetState extends State<ScheduledTaskSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _prompt = TextEditingController();
  final TextEditingController _time = TextEditingController(text: '09:00');
  String? _projectId;
  bool _saving = false;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    final projects = widget.controller.settingsProjectRecords();
    _projectId = projects.isEmpty ? null : projects.first['id']?.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _prompt.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final prompt = _prompt.text.trim();
    final projectId = _projectId?.trim() ?? '';
    if (name.isEmpty || prompt.isEmpty || projectId.isEmpty) {
      setState(() => _errorKey = 'scheduled.create.required');
      return;
    }
    setState(() {
      _saving = true;
      _errorKey = null;
    });
    final ok = await widget.controller.createScheduledTask(
      projectId: projectId,
      name: name,
      prompt: prompt,
      scheduleTime: _time.text.trim().isEmpty ? '09:00' : _time.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _errorKey = widget.controller.lastMutationErrorKey ?? 'scheduled.create.failed');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final projects = widget.controller.settingsProjectRecords();
    return Material(
      key: const Key('scheduled-create-sheet'),
      color: tokens.pageBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t(context, 'scheduled.add'),
              style: ocCssInk(TextStyle(
                fontSize: OcTokens.textUiLabel,
                fontWeight: FontWeight.w600,
                color: tokens.foreground,
              )),
            ),
            const SizedBox(height: 12),
            if (projects.isNotEmpty)
              DropdownButton<String>(
                key: const Key('scheduled-create-project'),
                value: projects.any((item) => item['id']?.toString() == _projectId)
                    ? _projectId
                    : projects.first['id']?.toString(),
                isExpanded: true,
                items: [
                  for (final project in projects)
                    DropdownMenuItem(
                      value: project['id']?.toString(),
                      child: Text(
                        (project['label']?.toString().trim().isNotEmpty ?? false)
                            ? project['label'].toString()
                            : deriveProjectLabel(project['path']?.toString() ?? ''),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _projectId = value),
              ),
            TextField(
              key: const Key('scheduled-create-name'),
              controller: _name,
              decoration: InputDecoration(labelText: t(context, 'scheduled.create.name')),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('scheduled-create-prompt'),
              controller: _prompt,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: t(context, 'scheduled.create.prompt')),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('scheduled-create-time'),
              controller: _time,
              decoration: InputDecoration(labelText: t(context, 'scheduled.create.dailyTime')),
            ),
            if (_errorKey != null) ...[
              const SizedBox(height: 8),
              Text(t(context, _errorKey!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Pressable(
              haptic: HapticStrength.light,
              onPressed: _saving ? null : () => unawaited(_save()),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  key: const Key('scheduled-create-save'),
                  height: 44,
                  child: Center(
                    child: Text(
                      t(context, 'scheduled.create.save'),
                      style: ocCssInk(TextStyle(
                        fontSize: OcTokens.textUiLabel,
                        fontWeight: FontWeight.w600,
                        color: tokens.primaryForeground,
                      )),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
