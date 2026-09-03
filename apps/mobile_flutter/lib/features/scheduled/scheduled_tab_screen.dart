import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/assistant_scheduled.dart';
import '../../data/relative_time.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../navigation/platform_route.dart';
import '../../native/haptics.dart';
import '../../mobile/mobile_surface.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import '../chat/chat_screen.dart';

class ScheduledTabScreen extends StatefulWidget {
  const ScheduledTabScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ScheduledTabScreen> createState() => _ScheduledTabScreenState();
}

class _ScheduledTabScreenState extends State<ScheduledTabScreen> {
  int _view = 0;
  int _filter = 0;

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

  String _humanSchedule(BuildContext context, ScheduledTaskRecord task) {
    final kind = task.scheduleKind?.trim() ?? '';
    final time = task.scheduleTime?.trim() ?? '';
    if (kind == 'cron' && time.isNotEmpty) {
      return t(context, 'scheduled.schedule.cron', {'cron': time});
    }
    if (kind == 'daily' && time.isNotEmpty) {
      return t(context, 'scheduled.schedule.daily', {'time': time});
    }
    if (kind == 'weekly' && time.isNotEmpty) {
      return t(context, 'scheduled.schedule.weekly', {'time': time});
    }
    return task.scheduleLabel();
  }

  String _taskSubtitle(BuildContext context, ScheduledTaskRecord task) {
    final schedule = _humanSchedule(context, task);
    final next = formatRelativeCountdown(
      task.nextRunAt,
      inFuture: (duration) => t(context, 'scheduled.relative.in', {'duration': duration}),
    );
    final running = task.isRunning ? task.statusLabel() : null;
    return [schedule, if (next != null) next, if (running != null) running].join(' · ');
  }

  List<ScheduledTaskRecord> _filtered(List<ScheduledTaskRecord> tasks) {
    return tasks.where((task) {
      if (_filter == 1) return task.enabled;
      if (_filter == 2) return !task.enabled;
      return true;
    }).toList();
  }

  Future<void> _openTask(String projectId, String taskId) async {
    await widget.controller.loadScheduledRuns(projectId: projectId, taskId: taskId);
    if (mounted) setState(() => _view = 1);
  }

  Future<void> _openRun(String runId) async {
    final runs = widget.controller.scheduledRuns.value ?? const [];
    for (final run in runs) {
      if (run.id != runId) continue;
      final session = run.historySession;
      if (session == null || !mounted) return;
      await Navigator.of(context).push(
        platformPageRoute<void>(
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
    return MobileTabPageScaffold(
      title: t(context, 'tabs.scheduled'),
      children: [
            SegmentedPill(
              labels: [t(context, 'scheduled.views.tasks'), t(context, 'scheduled.views.history')],
              icons: const [OcGlyphKind.calendar, OcGlyphKind.clock],
              selectedIndex: _view,
              onSelected: (index) => setState(() => _view = index),
            ),
            if (_view == 0)
              FilterChipBar(
                labels: [
                  t(context, 'scheduled.filters.all'),
                  t(context, 'scheduled.filters.enabled'),
                  t(context, 'scheduled.filters.paused'),
                ],
                selectedIndex: _filter,
                onSelected: (index) => setState(() => _filter = index),
                trailing: CircularChromeButton(
                  key: const Key('scheduled-add'),
                  glyph: OcGlyphKind.plus,
                  filled: true,
                  size: OcOptical.addButton,
                  tooltip: t(context, 'scheduled.add'),
                  onPressed: () {},
                ),
              ),
            if (tasks.errorKey != null)
              ListTile(key: const Key('scheduled-error'), title: Text(t(context, tasks.errorKey!)))
            else if (tasks.loading && !tasks.hasValue)
              const Center(child: CircularProgressIndicator())
            else if (_view == 0 && (tasks.value == null || tasks.value!.isEmpty))
              GroupedInsetCard(
                child: ListTile(
                  key: const Key('scheduled-empty'),
                  title: Text(t(context, 'scheduled.empty.title')),
                  subtitle: Text(t(context, 'scheduled.empty.description')),
                ),
              )
            else if (_view == 0)
              for (final task in _filtered(tasks.value!)) _taskCard(context, task)
            else ...[
              if (filterId == null && (runs.value == null || runs.value!.isEmpty))
                GroupedInsetCard(
                  child: ListTile(
                    key: const Key('scheduled-runs-empty'),
                    title: Text(t(context, 'scheduled.history.empty')),
                  ),
                ),
              if (runs.errorKey != null)
                ListTile(key: const Key('scheduled-runs-error'), title: Text(t(context, runs.errorKey!)))
              else if (runs.loading && !runs.hasValue)
                const ListTile(title: LinearProgressIndicator())
              else if (runs.value != null)
                for (final run in runs.value!)
                  GroupedInsetCard(
                    child: Pressable(
                      key: Key('scheduled-run-${run.id}'),
                      haptic: run.sessionId == null || run.sessionId!.isEmpty ? null : HapticStrength.light,
                      onPressed: run.sessionId == null || run.sessionId!.isEmpty ? null : () => _openRun(run.id),
                      child: ListTile(
                        title: Text(run.taskName.isEmpty ? run.id : run.taskName),
                        subtitle: Text(
                          [
                            run.status.isEmpty ? t(context, 'scheduled.status.idle') : run.status,
                            if (run.error != null && run.error!.isNotEmpty) run.error,
                          ].join(' · '),
                        ),
                        trailing: OcGlyph(OcGlyphKind.ellipsis, size: 16, color: context.oc.mutedForeground),
                      ),
                    ),
                  ),
            ],
            if (widget.controller.scheduledFailedProjectIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
                child: Text(t(context, 'scheduled.partialFailure')),
              ),
      ],
    );
  }

  Widget _taskCard(BuildContext context, ScheduledTaskRecord task) {
    final paused = !task.enabled;
    final card = GroupedInsetCard(
      tight: true,
      child: Pressable(
        key: Key('scheduled-task-${task.id}'),
        haptic: HapticStrength.light,
        onPressed: () => _openTask(task.projectId, task.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, OcOptical.scheduleCardPadV, 8, OcOptical.scheduleCardPadV),
          child: Row(
            children: [
              Container(
                width: OcOptical.scheduleStatus,
                height: OcOptical.scheduleStatus,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: paused ? context.oc.mutedForeground : context.oc.statusSuccess,
                    width: 1.05,
                  ),
                ),
                child: OcGlyph(
                  paused ? OcGlyphKind.pause : OcGlyphKind.check,
                  size: OcOptical.scheduleStatusGlyph,
                  strokeWidth: OcOptical.listGlyphStroke,
                  color: paused ? context.oc.mutedForeground : context.oc.statusSuccess,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name.isEmpty ? task.id : task.name,
                      style: TextStyle(
                        fontSize: OcOptical.entityTitle,
                        fontWeight: FontWeight.w500,
                        letterSpacing: OcOptical.entityTitleTracking,
                        height: OcOptical.entityTitleHeight,
                        color: paused ? context.oc.mutedForeground : context.oc.foreground,
                      ),
                    ),
                    const SizedBox(height: OcOptical.scheduleTitleMetaGap),
                    Text(
                      paused
                          ? [_humanSchedule(context, task), '—'].join(' · ')
                          : _taskSubtitle(context, task),
                      style: TextStyle(
                        fontSize: OcOptical.meta,
                        fontWeight: FontWeight.w400,
                        letterSpacing: OcOptical.metaTracking,
                        height: OcOptical.metaHeight,
                        color: context.oc.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('scheduled-run-now-${task.id}'),
                tooltip: t(context, 'scheduled.runNow'),
                onPressed: () => widget.controller.runScheduledTaskNow(
                  projectId: task.projectId,
                  taskId: task.id,
                ),
                icon: OcGlyph(OcGlyphKind.ellipsis, size: OcOptical.overflow, strokeWidth: OcOptical.listGlyphStroke, color: context.oc.mutedForeground),
              ),
            ],
          ),
        ),
      ),
    );
    if (!paused) return card;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: Opacity(opacity: 0.78, child: card),
    );
  }
}
