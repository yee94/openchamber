import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/home_session.dart';
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
import 'project_groups.dart';

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
        final groups = groupSessionsByProject(controller.sessions.where((row) {
          return sessionMatchesQuery(row, _query);
        }).toList());

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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t(context, 'projects.newProject.todo'))),
                      );
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
                          boxShadow: OcElevation.control(context),
                        ),
                        child: SizedBox(
                          width: OcOptical.headerDisc,
                          height: OcOptical.headerDisc,
                          child: Center(
                            child: OcGlyph(
                              OcGlyphKind.plus,
                              size: OcOptical.headerGlyph,
                              strokeWidth: OcOptical.headerGlyphStroke,
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
                      child: OcGlyph(OcGlyphKind.search, size: 16, color: context.oc.mutedForeground),
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

  bool _isWorktreeExpanded(String id, WorktreeHomeGroup tree) {
    if (_query.trim().isNotEmpty) return true;
    if (tree.sessions.any((row) => row.kind != HomeSessionKind.catalog)) return true;
    if (_worktreeToggled.contains(id)) return _expandedWorktrees.contains(id);
    return tree.sessionCount >= 3;
  }

  /// Main-workspace rows only. Worktree sessions stay in their nested groups.
  List<HomeSessionRow> _mainSessions(ProjectHomeGroup group) {
    final seen = <String>{};
    final out = <HomeSessionRow>[];
    void add(HomeSessionRow row) {
      if (seen.add(row.id)) out.add(row);
    }
    for (final row in group.sessions) {
      if (row.kind != HomeSessionKind.catalog) add(row);
    }
    for (final row in group.sessions) {
      add(row);
    }
    return out;
  }

  Widget _projectSurface(BuildContext context, ProjectHomeGroup group) {
    final expanded = !_collapsed.contains(group.id);
    return Column(
      key: Key('home-project-stack-${group.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobileFloatingSurface(
          key: Key('home-project-${group.id}'),
          child: Column(
            children: [
              MobileProjectCard(
                name: group.name,
                count: group.sessionCount,
                activity: formatRelativeTime(group.latestUpdated),
                pathHint: group.pathHint,
                expanded: expanded,
                highlightQuery: _query,
                onToggle: () => setState(() {
                  if (_collapsed.contains(group.id)) {
                    _collapsed.remove(group.id);
                  } else {
                    _collapsed.add(group.id);
                  }
                }),
              ),
              if (expanded) ..._sessionSlice(context, group.id, _mainSessions(group), true),
            ],
          ),
        ),
        if (expanded)
          for (final tree in group.worktrees) _worktreeCard(context, group.id, tree),
      ],
    );
  }

  Widget _worktreeCard(BuildContext context, String projectId, WorktreeHomeGroup tree) {
    final id = '$projectId::${tree.name}';
    final expanded = _isWorktreeExpanded(id, tree);
    final activity = formatRelativeTime(
      tree.sessions.fold<num>(0, (latest, row) => row.updated > latest ? row.updated : latest),
    );
    return MobileFloatingSurface(
      key: Key('home-worktree-$id'),
      child: Column(
        children: [
          MobileProjectCard(
            name: tree.name,
            glyph: OcGlyphKind.branch,
            count: tree.sessionCount,
            activity: activity,
            expanded: expanded,
            compact: true,
            highlightQuery: _query,
            onToggle: () => setState(() {
              final next = !_isWorktreeExpanded(id, tree);
              _worktreeToggled.add(id);
              if (next) {
                _expandedWorktrees.add(id);
              } else {
                _expandedWorktrees.remove(id);
              }
            }),
          ),
          if (expanded) ..._sessionSlice(context, id, tree.sessions, true),
        ],
      ),
    );
  }

  List<Widget> _sessionSlice(
    BuildContext context,
    String groupId,
    List<HomeSessionRow> sessions,
    bool assignSessionKeys,
  ) {
    final showAll = _expandedMore.contains(groupId) || sessions.length <= _visibleSlice;
    final visible = showAll ? sessions : sessions.take(_visibleSlice).toList();
    return [
      for (var i = 0; i < visible.length; i += 1) ...[
        if (i > 0) Divider(height: 1, thickness: 0.5, indent: 18, endIndent: 12, color: context.oc.mobileBorder),
        MobileSessionRow(
          key: assignSessionKeys ? Key('home-session-${visible[i].id}') : Key('home-session-${visible[i].id}-nested'),
          row: visible[i],
          highlightQuery: _query,
          showUnreadKey: assignSessionKeys,
          onSelect: () => _openChat(context, visible[i]),
        ),
      ],
      if (!showAll)
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
                OcGlyph(OcGlyphKind.chevronRight, size: OcOptical.chevron, strokeWidth: OcOptical.listGlyphStroke, color: context.oc.mutedForeground),
              ],
            ),
          ),
        ),
    ];
  }

  Future<void> _createSession(BuildContext context) async {
    final row = await controller.createSession();
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

  void _openChat(BuildContext context, HomeSessionRow row) {
    Navigator.of(context).push(
      platformPageRoute<void>(
        builder: (_) => ChatScreen(session: row, appController: controller),
      ),
    );
  }
}
