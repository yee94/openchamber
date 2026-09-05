import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/project_id.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import 'action_dialogs.dart';
import 'project_groups.dart';

const projectEditIcons = <(String, OcGlyphKind)>[
  ('code', OcGlyphKind.code),
  ('terminal', OcGlyphKind.terminal),
  ('folder', OcGlyphKind.folder),
  ('server', OcGlyphKind.server),
  ('book', OcGlyphKind.bookOpen),
  ('heart', OcGlyphKind.sparkles),
  ('rocket', OcGlyphKind.bolt),
  ('palette', OcGlyphKind.palette),
];

List<(String, Color)> projectEditColors(OcTokens tokens) => [
      ('primary', tokens.primary),
      ('keyword', OcProductChrome.agentAccent),
      ('string', tokens.statusSuccess),
      ('number', tokens.chart4),
      ('type', tokens.chart3),
      ('constant', tokens.chart1),
      ('comment', tokens.mutedForeground),
      ('error', tokens.statusError),
      ('success', tokens.statusSuccess),
    ];

Future<void> showProjectEditSheet({
  required BuildContext context,
  required AppController controller,
  required ProjectHomeGroup group,
  required String projectId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => ProjectEditSheet(
      controller: controller,
      group: group,
      projectId: projectId,
    ),
  );
}

class ProjectEditSheet extends StatefulWidget {
  const ProjectEditSheet({
    super.key,
    required this.controller,
    required this.group,
    required this.projectId,
  });

  final AppController controller;
  final ProjectHomeGroup group;
  final String projectId;

  @override
  State<ProjectEditSheet> createState() => _ProjectEditSheetState();
}

class _ProjectEditSheetState extends State<ProjectEditSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.group.name);
  String? _icon;
  String? _color;
  bool _saving = false;
  bool _discovering = false;

  Map<String, Object?> get _record {
    for (final project in widget.controller.settingsProjectRecords()) {
      if (project['id']?.toString() == widget.projectId) return project;
      if (normalizeProjectDirectory(project['path']?.toString() ?? '') ==
          normalizeProjectDirectory(widget.group.path)) {
        return project;
      }
    }
    return const {};
  }

  @override
  void initState() {
    super.initState();
    final record = _record;
    _icon = record['icon']?.toString();
    _color = record['color']?.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.controller.editProjectMeta(
      projectId: widget.projectId,
      label: _name.text,
      icon: _icon,
      color: _color,
      clearIcon: _icon == null,
      clearColor: _color == null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _discover() async {
    setState(() => _discovering = true);
    await widget.controller.discoverProjectIcon(widget.projectId);
    if (!mounted) return;
    setState(() => _discovering = false);
  }

  Future<void> _deleteWorktree(WorktreeHomeGroup tree) async {
    final confirmed = await showConfirmDialog(
      context: context,
      titleKey: 'mobile.projectEdit.deleteWorktreeTitle',
      messageKey: 'mobile.projectEdit.deleteWorktreeConfirm',
      confirmKey: 'mobile.projectEdit.deleteWorktreeConfirmButton',
      cancelKey: 'sessions.sidebar.session.rename.cancel',
      messageParams: {'name': tree.name},
      confirmWidgetKey: const Key('project-edit-worktree-delete-confirm'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await widget.controller.deleteWorktree(projectDirectory: widget.group.path, worktreePath: tree.path);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final colors = projectEditColors(tokens);
    final worktrees = widget.group.worktrees;
    return Material(
      key: const Key('project-edit-sheet'),
      color: tokens.pageBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t(context, 'projectEditDialog.title'),
                      style: ocCssInk(TextStyle(
                        fontSize: OcTokens.textUiLabel,
                        fontWeight: FontWeight.w600,
                        color: tokens.foreground,
                      )),
                    ),
                  ),
                  Pressable(
                    haptic: HapticStrength.light,
                    onPressed: _saving ? null : () => unawaited(_save()),
                    child: Text(
                      t(context, 'projectEditDialog.actions.save'),
                      key: const Key('project-edit-save'),
                      style: TextStyle(color: tokens.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('project-edit-field'),
                controller: _name,
                decoration: InputDecoration(labelText: t(context, 'projectEditDialog.field.name')),
              ),
              const SizedBox(height: 6),
              Text(
                widget.group.path,
                style: TextStyle(fontSize: OcTokens.textMeta, color: tokens.mutedForeground),
              ),
              const SizedBox(height: 16),
              Text(t(context, 'projectEditDialog.field.color')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _swatch(
                    key: const Key('project-edit-color-none'),
                    selected: _color == null,
                    color: tokens.muted,
                    onTap: () => setState(() => _color = null),
                  ),
                  for (final entry in colors)
                    _swatch(
                      key: Key('project-edit-color-${entry.$1}'),
                      selected: _color == entry.$1,
                      color: entry.$2,
                      onTap: () => setState(() => _color = entry.$1),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(t(context, 'projectEditDialog.field.icon')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in projectEditIcons)
                    Pressable(
                      key: Key('project-edit-icon-${entry.$1}'),
                      haptic: HapticStrength.light,
                      onPressed: () => setState(() => _icon = _icon == entry.$1 ? null : entry.$1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: _icon == entry.$1 ? tokens.foreground : tokens.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: OcGlyph(entry.$2, size: 16, color: tokens.foreground),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Pressable(
                haptic: HapticStrength.light,
                onPressed: _discovering ? null : () => unawaited(_discover()),
                child: SizedBox(
                  key: const Key('project-edit-discover'),
                  height: 40,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t(
                        context,
                        _discovering
                            ? 'projectEditDialog.actions.discovering'
                            : 'projectEditDialog.actions.discoverFavicon',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(t(context, 'mobile.projectEdit.worktreesTitle')),
              if (worktrees.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    t(context, 'mobile.projectEdit.worktreesEmpty'),
                    style: TextStyle(color: tokens.mutedForeground, fontSize: OcTokens.textMeta),
                  ),
                )
              else
                for (final tree in worktrees)
                  ListTile(
                    key: Key('project-edit-worktree-${tree.path}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(tree.name),
                    subtitle: Text(tree.path, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      key: Key('project-edit-worktree-delete-${tree.path}'),
                      onPressed: () => unawaited(_deleteWorktree(tree)),
                      icon: OcGlyph(OcGlyphKind.xmark, size: 16, color: tokens.statusError),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swatch({
    required Key key,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Pressable(
      key: key,
      haptic: HapticStrength.light,
      onPressed: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? context.oc.foreground : Colors.transparent, width: 2),
        ),
        child: const SizedBox(width: 36, height: 36),
      ),
    );
  }
}
