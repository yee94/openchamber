import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/home_session.dart';
import '../../data/project_id.dart';
import '../../data/relative_time.dart';
import '../../data/session_index.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../navigation/platform_route.dart';
import '../../native/haptics.dart';
import '../../mobile/mobile_project_card.dart';
import '../../mobile/mobile_session_row.dart';
import '../../mobile/mobile_surface.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import '../chat/chat_screen.dart';
import '../chat/session_overflow_sheet.dart';
import 'action_dialogs.dart';
import 'highlighted_text.dart';
import 'new_project_sheet.dart';
import 'new_worktree_sheet.dart';
import 'project_edit_sheet.dart';
import 'project_groups.dart';
import 'project_home_overlay.dart';

class ProjectsHomeScreen extends StatefulWidget {
  const ProjectsHomeScreen({
    super.key,
    required this.controller,
    this.bottomOccupancy = 0,
  });

  final AppController controller;
  final double bottomOccupancy;

  @override
  State<ProjectsHomeScreen> createState() => _ProjectsHomeScreenState();
}

class _ProjectsHomeScreenState extends State<ProjectsHomeScreen> {
  String _query = '';
  bool _searchOpen = false;
  final Set<String> _collapsed = {};
  final Set<String> _expandedMore = {};
  final Set<String> _expandedWorktrees = {};
  final Set<String> _worktreeToggled = {};

  AppController get controller => widget.controller;

  static const _visibleSlice = 3;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final groups = overlaySettingsProjects(
          sessionGroups: groupSessionsByProject(
            controller.sessions.where((row) {
              return sessionMatchesQuery(row, _query);
            }).toList(),
            worktreeOrderByDirectory: controller.worktreeOrderByDirectory,
          ),
          settingsProjects: controller.settingsProjectRecords(),
        );

        return MobileTabPageScaffold(
          title: t(context, 'tabs.projects'),
          onRefresh: controller.refreshSessions,
          bottomOccupancy: widget.bottomOccupancy,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularChromeButton(
                key: const Key('projects-search-toggle'),
                glyph: _searchOpen ? OcGlyphKind.xmark : OcGlyphKind.search,
                size: OcOptical.searchButton,
                tooltip: t(context, 'projects.search.aria'),
                onPressed: () {
                  setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) _query = '';
                  });
                },
              ),
              const SizedBox(width: 14),
              PopupMenuButton<String>(
                key: const Key('projects-plus-menu'),
                tooltip: t(context, 'projects.menu.label'),
                onSelected: (value) {
                  switch (value) {
                    case 'new-chat':
                      unawaited(_createSession(context));
                    case 'scan':
                      controller.scanAndConnect();
                    case 'switch':
                      controller.switchToConnect();
                    case 'new-project':
                      unawaited(_openNewProject(context));
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'new-chat', child: Text(t(context, 'projects.menu.newChat'))),
                  PopupMenuItem(value: 'new-project', child: Text(t(context, 'projects.menu.newProject'))),
                  PopupMenuItem(value: 'scan', child: Text(t(context, 'projects.menu.scanQr'))),
                  PopupMenuItem(value: 'switch', child: Text(t(context, 'projects.menu.switchInstance'))),
                ],
                child: SizedBox(
                  width: OcOptical.addButton,
                  height: OcOptical.addButton,
                  child: Pressable(
                    haptic: HapticStrength.light,
                    highlight: false,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.oc.primary,
                          shape: BoxShape.circle,
                          boxShadow: OcElevation.primaryAdd(context),
                        ),
                        child: SizedBox(
                          width: OcOptical.addButton,
                          height: OcOptical.addButton,
                          child: Center(
                            child: OcGlyph(
                              OcGlyphKind.plus,
                              size: OcOptical.headerGlyph,
                              strokeWidth: OcOptical.headerGlyphStrokeVisual,
                              color: context.oc.primaryForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          children: [
            // Large-title 空档 is shared on MobileTabPageScaffold
            // (20 + 10 + 20). pageProjectGap is card-stack spacing on
            // each project surface, not here.
            if (_searchOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, 12),
                child: TextField(
                  key: const Key('projects-search'),
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: t(context, 'projects.search.placeholder'),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 4),
                      child: OcGlyph(
                        OcGlyphKind.search,
                        size: OcOptical.searchFieldGlyph,
                        strokeWidth: OcOptical.listGlyphStroke,
                        color: context.oc.mutedForeground,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 18),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OcChrome.pillRadius),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OcChrome.pillRadius),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OcChrome.pillRadius),
                      borderSide: BorderSide.none,
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                ),
              ),
            if (controller.sessionsErrorKey != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
                child: Text(
                  t(context, controller.sessionsErrorKey!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else if (controller.sessionsLoading && controller.sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
                child: Text(t(context, 'projects.loading')),
              )
            else if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter, vertical: 24),
                child: Text(t(context, 'projects.empty')),
              )
            else
              for (final group in groups) _projectSurface(context, group),
          ],
        );
      },
    );
  }

  /// Official linked worktrees start collapsed; only search or an explicit
  /// toggle opens them (`useMobileProjectsHomeModel` `expanded` for `kind !== 'main'`).
  bool _isWorktreeExpanded(String id) {
    if (_query.trim().isNotEmpty) return true;
    if (_worktreeToggled.contains(id)) return _expandedWorktrees.contains(id);
    return false;
  }

  /// Main-workspace rows only. Same-directory branches stay here — they are
  /// not extra cards. Official: `mainWorkspace.sessions` under one shell.
  List<HomeSessionRow> _mainSessions(ProjectHomeGroup group) => group.sessions;

  Widget _projectSurface(BuildContext context, ProjectHomeGroup group) {
    final expanded = !_collapsed.contains(group.id);
    final mains = _mainSessions(group);
    // Official: one `MobileFloatingSurface` / project-shell. Main sessions and
    // linked worktrees share `.oc-mobile-project-groups` padding + gap.
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: OcTokens.dockMaxWidth),
        child: MobileFloatingSurface(
          key: Key('home-project-${group.id}'),
          margin: const EdgeInsets.fromLTRB(
            OcChrome.pageGutter,
            0,
            OcChrome.pageGutter,
            OcOptical.pageProjectGap,
          ),
          child: Column(
            key: Key('home-project-stack-${group.id}'),
            children: [
              MobileProjectCard(
                name: group.name,
                count: group.sessionCount,
                activity: formatRelativeTime(group.latestUpdated),
                pathHint: group.pathHint,
                expanded: expanded,
                highlightQuery: _query,
                onOpenActions: () => unawaited(_openProjectActions(context, group)),
                onToggle: () => setState(() {
                  if (_collapsed.contains(group.id)) {
                    _collapsed.remove(group.id);
                  } else {
                    _collapsed.add(group.id);
                  }
                }),
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    OcOptical.projectGroupsPadInline,
                    OcOptical.projectGroupsPadTop,
                    OcOptical.projectGroupsPadInline,
                    OcOptical.projectGroupsPadBottom,
                  ),
                  child: Column(
                    children: [
                      if (mains.isNotEmpty)
                        _insetGroup(
                          children: _sessionSlice(context, group.id, mains, true, clipFirst: true),
                        ),
                      for (var i = 0; i < group.worktrees.length; i += 1) ...[
                        if (mains.isNotEmpty || i > 0) const SizedBox(height: OcOptical.projectGroupGap),
                        _worktreeGroup(context, group, group.worktrees[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insetGroup({Widget? label, required List<Widget> children}) {
    return MobileLabeledSurfaceGroup(label: label, children: children);
  }

  Widget _worktreeGroup(BuildContext context, ProjectHomeGroup group, WorktreeHomeGroup tree) {
    final id = '${group.id}::${tree.path}';
    final expanded = _isWorktreeExpanded(id);
    return _insetGroup(
      label: _worktreeLabel(context, id, group, tree, expanded),
      children: expanded ? _sessionSlice(context, id, tree.sessions, true, clipFirst: false) : const [],
    );
  }

  Widget _worktreeLabel(
    BuildContext context,
    String id,
    ProjectHomeGroup group,
    WorktreeHomeGroup tree,
    bool expanded,
  ) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(
          OcOptical.worktreeLabelPadLeft,
          OcOptical.worktreeLabelPadV,
          OcOptical.worktreeLabelPadRight,
          OcOptical.worktreeLabelPadV,
        ),
        child: Row(
          children: [
            Expanded(
              child: Pressable(
                key: Key('home-worktree-$id'),
                haptic: HapticStrength.light,
                onPressed: () => setState(() {
                  final next = !_isWorktreeExpanded(id);
                  _worktreeToggled.add(id);
                  if (next) {
                    _expandedWorktrees.add(id);
                  } else {
                    _expandedWorktrees.remove(id);
                  }
                }),
                child: Row(
                  children: [
            SizedBox(
              width: OcOptical.worktreeIconBox,
              height: OcOptical.worktreeIconBox,
              child: Center(
                child: OcGlyph(
                  OcGlyphKind.branch,
                  size: OcOptical.worktreeGlyphVisual,
                  strokeWidth: OcOptical.headerGlyphStrokeVisual,
                  color: context.oc.mutedForeground,
                ),
              ),
            ),
            const SizedBox(width: OcOptical.worktreeLabelGap),
            Expanded(
              child: HighlightedText(
                tree.name,
                query: _query,
                // Official worktree name is project-shell
                // `oc-mobile-entity-title` (14/18 + semibold), not
                // session 12/16 Regular. Same CJK band as project titles.
                halfLead: OcOptical.cardTitleHalfLeadPaint,
                stem: OcOptical.sessionTitleStem,
                style: TextStyle(
                  fontSize: OcOptical.projectTitle,
                  fontWeight: FontWeight.w600,
                  letterSpacing: OcOptical.projectTitleTrackingOfficial,
                  height: OcOptical.projectTitleHeight,
                  color: context.oc.foreground,
                ),
              ),
            ),
            OcCssLine(
              expand: false,
              // Official `.typography-small` override is 11/14.
              // Default 4.7 sat in the 42px label like the old meta bug.
              halfLead: 0,
              style: const TextStyle(
                fontSize: OcOptical.worktreeMeta,
                height: OcOptical.worktreeMetaHeight,
              ),
              child: Text(
                tree.sessionCount == 1
                    ? t(context, 'projects.sessionsCount.one')
                    : t(context, 'projects.sessionsCount', {'count': '${tree.sessionCount}'}),
                style: ocCssInk(TextStyle(
                  fontSize: OcOptical.worktreeMeta,
                  height: OcOptical.worktreeMetaHeight,
                  color: context.oc.mutedForeground,
                )),
              ),
            ),
            const SizedBox(width: 6),
            OcGlyph(
              expanded ? OcGlyphKind.chevronDown : OcGlyphKind.chevronRight,
              size: OcOptical.chevron,
              strokeWidth: OcOptical.sessionMoreStroke,
              color: context.oc.mutedForeground,
            ),
                  ],
                ),
              ),
            ),
            Pressable(
              key: Key('home-worktree-actions-$id'),
              haptic: HapticStrength.light,
              onPressed: () => unawaited(_openWorktreeActions(context, group, tree)),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: OcGlyph(
                    OcGlyphKind.ellipsis,
                    size: OcOptical.sessionMore,
                    strokeWidth: OcOptical.sessionMoreStroke,
                    color: context.oc.mutedForeground,
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  List<Widget> _sessionSlice(
    BuildContext context,
    String groupId,
    List<HomeSessionRow> sessions,
    bool assignSessionKeys, {
    required bool clipFirst,
  }) {
    final showAll = _expandedMore.contains(groupId) || sessions.length <= _visibleSlice;
    final visible = showAll ? sessions : sessions.take(_visibleSlice).toList();
    final hasMore = !showAll;
    return [
      for (var i = 0; i < visible.length; i += 1)
        MobileSessionRow(
          key: assignSessionKeys ? Key('home-session-${visible[i].id}') : Key('home-session-${visible[i].id}-nested'),
          row: visible[i],
          highlightQuery: _query,
          showUnreadKey: assignSessionKeys,
          showBottomDivider: i < visible.length - 1 || hasMore,
          clipStart: clipFirst && i == 0,
          clipEnd: !hasMore && i == visible.length - 1,
          onSelect: () => _openChat(context, visible[i]),
          onOpenActions: () => unawaited(_openSessionActions(context, visible[i])),
        ),
      if (hasMore)
        Column(
          children: [
            Pressable(
              haptic: HapticStrength.light,
              onPressed: () => setState(() => _expandedMore.add(groupId)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, OcOptical.moreLinkPadV, 14, OcOptical.moreLinkPadV),
                child: Row(
                  children: [
                    Text(
                      t(context, 'projects.showMore'),
                      style: TextStyle(
                        fontSize: OcTokens.textUiLabel,
                        letterSpacing: OcOptical.metaTracking,
                        height: OcOptical.rowTitleHeight,
                        color: context.oc.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    OcGlyph(OcGlyphKind.chevronRight, size: OcOptical.chevron, strokeWidth: OcOptical.headerGlyphStrokeVisual, color: context.oc.mutedForeground),
                  ],
                ),
              ),
            ),
          ],
        ),
    ];
  }

  Future<void> _createSession(BuildContext context, {String? directory}) async {
    final row = await controller.createSession(directory: directory);
    if (!context.mounted) return;
    if (row != null) {
      _openChat(context, row);
      return;
    }
    final errorKey = controller.createSessionErrorKey;
    if (errorKey != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, errorKey))),
      );
    }
  }

  Future<void> _openNewProject(BuildContext context) async {
    final added = await showNewProjectSheet(context: context, controller: controller);
    if (!context.mounted || !added) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'projects.newProject.added'))),
    );
  }

  Future<void> _openSessionActions(BuildContext context, HomeSessionRow session) async {
    final hydrated = await controller.hydrateSessionShare(session);
    if (!context.mounted) return;
    await showSessionOverflowSheet(
      context: context,
      title: hydrated.title,
      items: buildSessionOverflowItems(
        pinned: hydrated.kind == HomeSessionKind.pinned,
        shared: hydrated.isShared,
        onRename: () => unawaited(_renameSession(context, hydrated)),
        onTogglePin: () => unawaited(_runMutation(() => controller.toggleSessionPin(hydrated))),
        onShare: () => unawaited(_shareSession(context, hydrated)),
        onCopyLink: hydrated.isShared ? () => unawaited(_copyShareUrl(context, hydrated.shareUrl!)) : null,
        onUnshare: () => unawaited(_runMutation(() => controller.unshareSession(hydrated))),
        onRefreshTranscript: () => unawaited(_runMutation(() => controller.syncProjectSessions())),
        onArchive: () => unawaited(_archiveSession(context, hydrated)),
        onDelete: () => unawaited(_deleteSession(context, hydrated)),
      ),
    );
  }

  Future<void> _shareSession(BuildContext context, HomeSessionRow session) async {
    final ok = await controller.shareSession(session);
    if (!context.mounted) return;
    if (!ok) {
      await _runMutation(() async => false);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'sessions.sidebar.session.share.successTitle'))),
    );
  }

  Future<void> _copyShareUrl(BuildContext context, String url) async {
    final ok = await copyTextToClipboard(url);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(context, ok ? 'sessions.sidebar.session.menu.copied' : 'sessions.sidebar.session.share.copyUrlError'),
        ),
      ),
    );
  }

  Future<void> _openProjectActions(BuildContext context, ProjectHomeGroup group) async {
    final git = await controller.isGitRepository(group.path);
    if (!context.mounted) return;
    await showSessionOverflowSheet(
      context: context,
      title: group.name,
      sheetKey: const Key('project-overflow-sheet'),
      items: buildProjectOverflowItems(
        gitRepository: git,
        onNewSession: () => unawaited(_createSession(context, directory: group.path)),
        onNewWorktree: () => unawaited(_createWorktree(context, group)),
        onSyncSessions: () => unawaited(_runMutation(controller.syncProjectSessions)),
        onEditProject: () => unawaited(_editProjectSurface(context, group)),
        onCloseProject: () => unawaited(_closeProject(context, group)),
      ),
    );
  }

  Future<void> _openWorktreeActions(BuildContext context, ProjectHomeGroup group, WorktreeHomeGroup tree) async {
    await showSessionOverflowSheet(
      context: context,
      title: tree.name,
      sheetKey: const Key('worktree-overflow-sheet'),
      items: buildWorktreeOverflowItems(
        onNewSession: () => unawaited(_createSession(context, directory: tree.path)),
        onDeleteWorktree: () => unawaited(_deleteWorktree(context, parentDirectory: group.path, tree: tree)),
      ),
    );
  }

  Future<void> _renameSession(BuildContext context, HomeSessionRow session) async {
    final next = await showTextPromptDialog(
      context: context,
      titleKey: 'sessions.sidebar.session.menu.rename',
      fieldLabelKey: 'sessions.sidebar.session.menu.rename',
      confirmKey: 'sessions.sidebar.session.rename.save',
      cancelKey: 'sessions.sidebar.session.rename.cancel',
      initial: session.title,
      fieldKey: const Key('session-rename-field'),
      confirmWidgetKey: const Key('session-rename-save'),
    );
    if (next == null || !context.mounted) return;
    await _runMutation(() => controller.renameSession(session, next));
  }

  Future<void> _deleteSession(BuildContext context, HomeSessionRow session) async {
    final confirmed = await showConfirmDialog(
      context: context,
      titleKey: 'sessions.sidebar.dialogs.deleteSession.title',
      messageKey: 'sessions.sidebar.dialogs.deleteSession.single',
      confirmKey: 'sessions.sidebar.bulkActions.delete',
      cancelKey: 'sessions.sidebar.session.rename.cancel',
      messageParams: {'sessionTitle': session.title},
      confirmWidgetKey: const Key('session-delete-confirm'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _runMutation(() => controller.deleteSession(session));
  }

  Future<void> _editProjectSurface(BuildContext context, ProjectHomeGroup group) async {
    await showProjectEditSheet(
      context: context,
      controller: controller,
      group: group,
      projectId: _settingsProjectId(group),
    );
  }

  Future<void> _closeProject(BuildContext context, ProjectHomeGroup group) async {
    final confirmed = await showConfirmDialog(
      context: context,
      titleKey: 'sessions.sidebar.project.actions.closeProject',
      messageKey: 'mobile.projects.closeConfirmMessage',
      confirmKey: 'sessions.sidebar.project.actions.closeProject',
      cancelKey: 'sessions.sidebar.session.rename.cancel',
      messageParams: {'title': group.name},
      confirmWidgetKey: const Key('project-close-confirm'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _runMutation(() => controller.closeProject(_settingsProjectId(group)));
  }

  Future<void> _createWorktree(BuildContext context, ProjectHomeGroup group) async {
    final created = await showNewWorktreeSheet(
      context: context,
      controller: controller,
      directory: group.path,
    );
    if (!context.mounted || !created) return;
  }

  Future<void> _deleteWorktree(
    BuildContext context, {
    required String parentDirectory,
    required WorktreeHomeGroup tree,
  }) async {
    final confirmed = await showConfirmDialog(
      context: context,
      titleKey: 'mobile.projectEdit.deleteWorktreeTitle',
      messageKey: 'mobile.projectEdit.deleteWorktreeConfirm',
      confirmKey: 'mobile.projectEdit.deleteWorktreeConfirmButton',
      cancelKey: 'sessions.sidebar.session.rename.cancel',
      messageParams: {'name': tree.name},
      confirmWidgetKey: const Key('worktree-delete-confirm'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _runMutation(() => controller.deleteWorktree(projectDirectory: parentDirectory, worktreePath: tree.path));
  }

  String _settingsProjectId(ProjectHomeGroup group) {
    final path = normalizeProjectDirectory(group.path);
    for (final project in controller.settingsProjectRecords()) {
      if (normalizeProjectDirectory(project['path']?.toString() ?? '') == path) {
        final id = project['id']?.toString() ?? '';
        if (id.isNotEmpty) return id;
      }
    }
    return group.id;
  }

  Future<void> _archiveSession(BuildContext context, HomeSessionRow session) async {
    final ok = await controller.archiveSession(session);
    if (!context.mounted) return;
    if (!ok) {
      await _runMutation(() async => false);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(context, 'sessions.sidebar.session.archive.success')),
        action: SnackBarAction(
          key: const Key('session-archive-undo'),
          label: t(context, 'sessions.sidebar.undo'),
          onPressed: () => unawaited(controller.unarchiveSession(session)),
        ),
      ),
    );
  }

  Future<void> _runMutation(Future<bool> Function() run) async {
    final ok = await run();
    if (!mounted) return;
    final error = controller.lastMutationErrorKey;
    if (!ok && error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, error))));
    }
  }

  void _openChat(BuildContext context, HomeSessionRow row) {
    Navigator.of(context).push(
      platformPageRoute<void>(
        builder: (_) => ChatScreen(session: row, appController: controller),
      ),
    );
  }
}
