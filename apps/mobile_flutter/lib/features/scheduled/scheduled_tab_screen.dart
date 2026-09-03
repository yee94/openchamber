import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/assistant_scheduled.dart';
import '../../l10n/app_strings.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_primitives.dart';

class ScheduledTabScreen extends StatefulWidget {
  const ScheduledTabScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ScheduledTabScreen> createState() => _ScheduledTabScreenState();
}

class _ScheduledTabScreenState extends State<ScheduledTabScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.loadScheduledTasks();
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

  String _taskSubtitle(BuildContext context, ScheduledTaskRecord task) {
    final status = task.enabled ? task.statusLabel() : t(context, 'scheduled.disabled');
    final schedule = task.scheduleLabel();
    final next = task.nextRunAt == null ? null : t(context, 'scheduled.nextRun');
    final error = task.lastError;
    return [
      status,
      if (schedule != status) schedule,
      if (next != null) next,
      if (error != null && error.isNotEmpty) error,
    ].join(' · ');
  }

  Future<void> _openTask(String projectId, String taskId) async {
    await widget.controller.loadScheduledRuns(projectId: projectId, taskId: taskId);
  }

  Future<void> _openRun(String runId) async {
    final runs = widget.controller.scheduledRuns.value ?? const [];
    for (final run in runs) {
      if (run.id != runId) continue;
      final session = run.historySession;
      if (session == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(session: session, appController: widget.controller),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.controller.scheduledTasks;
    final runs = widget.controller.scheduledRuns;
    final filterId = widget.controller.scheduledFilterTaskId;
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'tabs.scheduled'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (tasks.errorKey != null)
            ListTile(key: const Key('scheduled-error'), title: Text(t(context, tasks.errorKey!)))
          else if (tasks.loading && !tasks.hasValue)
            const Center(child: CircularProgressIndicator())
          else if (tasks.value == null || tasks.value!.isEmpty)
            SettingsGroup(
              label: t(context, 'tabs.scheduled'),
              children: [
                ListTile(
                  key: const Key('scheduled-empty'),
                  title: Text(t(context, 'scheduled.empty.title')),
                  subtitle: Text(t(context, 'scheduled.empty.description')),
                ),
              ],
            )
          else
            SettingsGroup(
              label: t(context, 'scheduled.list'),
              children: [
                for (final task in tasks.value!)
                  SettingsNavRow(
                    key: Key('scheduled-task-${task.id}'),
                    label: task.name.isEmpty ? task.id : task.name,
                    subtitle: _taskSubtitle(context, task),
                    trailing: IconButton(
                      key: Key('scheduled-run-now-${task.id}'),
                      tooltip: t(context, 'scheduled.runNow'),
                      onPressed: () => widget.controller.runScheduledTaskNow(
                        projectId: task.projectId,
                        taskId: task.id,
                      ),
                      icon: Icon(task.isRunning ? Icons.hourglass_top : Icons.play_arrow),
                    ),
                    onTap: () => _openTask(task.projectId, task.id),
                  ),
              ],
            ),
          if (widget.controller.scheduledFailedProjectIds.isNotEmpty)
            ListTile(title: Text(t(context, 'scheduled.partialFailure'))),
          if (filterId != null)
            SettingsGroup(
              label: t(context, 'scheduled.history'),
              children: [
                if (runs.errorKey != null)
                  ListTile(key: const Key('scheduled-runs-error'), title: Text(t(context, runs.errorKey!)))
                else if (runs.loading && !runs.hasValue)
                  const ListTile(title: LinearProgressIndicator())
                else if (runs.value == null || runs.value!.isEmpty)
                  ListTile(key: const Key('scheduled-runs-empty'), title: Text(t(context, 'scheduled.history.empty')))
                else
                  for (final run in runs.value!)
                    SettingsNavRow(
                      key: Key('scheduled-run-${run.id}'),
                      label: run.taskName.isEmpty ? run.id : run.taskName,
                      subtitle: [
                        run.status.isEmpty ? t(context, 'scheduled.status.idle') : run.status,
                        if (run.error != null && run.error!.isNotEmpty) run.error,
                      ].join(' · '),
                      onTap: run.sessionId == null || run.sessionId!.isEmpty ? null : () => _openRun(run.id),
                    ),
              ],
            ),
        ],
      ),
    );
  }
}
