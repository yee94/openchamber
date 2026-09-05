import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/assistant_scheduled.dart';
import '../../data/project_id.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';

Future<bool> showScheduledTaskSheet({
  required BuildContext context,
  required AppController controller,
  ScheduledTaskRecord? task,
}) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => ScheduledTaskSheet(controller: controller, task: task),
  );
  return created == true;
}

class ScheduledTaskSheet extends StatefulWidget {
  const ScheduledTaskSheet({super.key, required this.controller, this.task});

  final AppController controller;
  final ScheduledTaskRecord? task;

  @override
  State<ScheduledTaskSheet> createState() => _ScheduledTaskSheetState();
}

class _ScheduledTaskSheetState extends State<ScheduledTaskSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.task?.name ?? '');
  late final TextEditingController _prompt = TextEditingController(text: widget.task?.prompt ?? '');
  late final TextEditingController _time = TextEditingController(text: widget.task?.scheduleTime ?? '09:00');
  String? _projectId;
  String _kind = 'daily';
  List<int> _weekdays = const [1];
  bool _saving = false;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    final projects = widget.controller.settingsProjectRecords();
    _projectId = widget.task?.projectId ?? (projects.isEmpty ? null : projects.first['id']?.toString());
    _kind = widget.task?.scheduleKind ?? 'daily';
    final weekdays = widget.task?.weekdays;
    if (weekdays != null && weekdays.isNotEmpty) {
      _weekdays = List<int>.from(weekdays);
    }
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
      taskId: widget.task?.id,
      name: name,
      prompt: prompt,
      scheduleKind: _kind,
      scheduleTime: _time.text.trim().isEmpty ? (_kind == 'cron' ? '0 9 * * *' : '09:00') : _time.text.trim(),
      cron: _kind == 'cron' ? _time.text.trim() : null,
      weekdays: _kind == 'weekly' ? (_weekdays.isEmpty ? const [1] : _weekdays) : null,
      enabled: widget.task?.enabled ?? true,
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
              t(context, widget.task == null ? 'sessions.scheduledTasks.editor.title.new' : 'sessions.scheduledTasks.editor.title.edit'),
              style: ocCssInk(TextStyle(
                fontSize: OcTokens.textUiLabel,
                fontWeight: FontWeight.w600,
                color: tokens.foreground,
              )),
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              key: const Key('scheduled-create-kind'),
              value: _kind,
              isExpanded: true,
              items: [
                for (final kind in const ['daily', 'weekly', 'cron'])
                  DropdownMenuItem(value: kind, child: Text(t(context, 'sessions.scheduledTasks.editor.scheduleType.$kind'))),
              ],
              onChanged: (value) => setState(() => _kind = value ?? 'daily'),
            ),
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
            if (_kind == 'weekly') ...[
              const SizedBox(height: 8),
              Text(t(context, 'sessions.scheduledTasks.editor.weekdays.label')),
              Wrap(
                spacing: 8,
                children: [
                  for (var weekday = 0; weekday < 7; weekday += 1)
                    FilterChip(
                      key: Key('scheduled-weekday-$weekday'),
                      label: Text(t(context, 'scheduled.weekday.$weekday')),
                      selected: _weekdays.contains(weekday),
                      onSelected: (selected) {
                        setState(() {
                          final next = {..._weekdays};
                          if (selected) {
                            next.add(weekday);
                          } else {
                            next.remove(weekday);
                          }
                          _weekdays = next.toList()..sort();
                        });
                      },
                    ),
                ],
              ),
            ],
            TextField(
              key: const Key('scheduled-create-time'),
              controller: _time,
              decoration: InputDecoration(
                labelText: t(
                  context,
                  _kind == 'cron'
                      ? 'sessions.scheduledTasks.editor.cronExpression.label'
                      : 'sessions.scheduledTasks.editor.time.label',
                ),
              ),
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
                      t(context, widget.task == null ? 'scheduled.create.save' : 'sessions.scheduledTasks.editor.actions.save'),
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
