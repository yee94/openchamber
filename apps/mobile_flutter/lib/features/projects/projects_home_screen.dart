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
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import '../chat/chat_screen.dart';
import 'highlighted_text.dart';
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
        final inProgress = controller.sessions.where((row) => row.kind == HomeSessionKind.inProgress).toList();

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: controller.refreshSessions,
              child: ListView(
                clipBehavior: Clip.none,
                padding: EdgeInsets.fromLTRB(0, 0, 0, 24 + widget.bottomOccupancy),
                children: [
                  if (inProgress.isNotEmpty)
                    StatusAttentionStrip(
                      label: inProgress.first.title,
                      moreLabel: t(context, 'projects.showMore'),
                    ),
                  LargeTitleHeader(
                    title: t(context, 'tabs.projects'),
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
                        const SizedBox(width: 10),
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
                          child: Pressable(
                            haptic: HapticStrength.light,
                            highlight: false,
                            child: Container(
                              width: OcOptical.addButton,
                              height: OcOptical.addButton,
                              decoration: BoxDecoration(
                                color: context.oc.primary,
                                shape: BoxShape.circle,
                                boxShadow: OcElevation.control(context),
                              ),
                              child: OcGlyph(
                                OcGlyphKind.plus,
                                size: OcOptical.headerGlyph,
                                strokeWidth: OcOptical.headerGlyphStroke,
                                color: context.oc.primaryForeground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  else ...[
                    if (groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter, vertical: 24),
                        child: Text(t(context, 'projects.empty')),
                      )
                    else
                      for (final group in groups)
                        _projectSurface(context, group),
                  ],
                ],
              ),
            ),
          ),
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
    return GroupedInsetCard(
      child: Column(
        children: [
          _groupHeader(
            context,
            name: group.name,
            glyph: OcGlyphKind.code,
            count: group.sessionCount,
            activity: formatRelativeTime(group.latestUpdated),
            pathHint: group.pathHint,
            expanded: expanded,
            onToggle: () => setState(() {
              if (_collapsed.contains(group.id)) {
                _collapsed.remove(group.id);
              } else {
                _collapsed.add(group.id);
              }
            }),
          ),
          if (expanded) ...[
            Divider(height: 1, thickness: 0.5, color: context.oc.mobileBorder),
            ..._sessionSlice(context, group.id, _mainSessions(group), true),
            for (final tree in group.worktrees) ...[
              Divider(height: 1, thickness: 0.5, color: context.oc.mobileBorder),
              _worktreeSection(context, group.id, tree),
            ],
          ],
        ],
      ),
    );
  }

  Widget _worktreeSection(BuildContext context, String projectId, WorktreeHomeGroup tree) {
    final id = '$projectId::${tree.name}';
    final expanded = _isWorktreeExpanded(id, tree);
    final activity = formatRelativeTime(
      tree.sessions.fold<num>(0, (latest, row) => row.updated > latest ? row.updated : latest),
    );
    return Column(
      children: [
        _groupHeader(
          context,
          name: tree.name,
          glyph: OcGlyphKind.branch,
          count: tree.sessionCount,
          activity: activity,
          pathHint: null,
          expanded: expanded,
          compact: true,
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
    );
  }

  Widget _groupHeader(
    BuildContext context, {
    required String name,
    required OcGlyphKind glyph,
    required int count,
    required String? activity,
    required String? pathHint,
    required bool expanded,
    required VoidCallback onToggle,
    bool compact = false,
  }) {
    return Pressable(
      haptic: HapticStrength.light,
      onPressed: onToggle,
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 14 : 14, compact ? 12 : 14, 10, compact ? 12 : 14),
        child: Row(
          children: [
            Container(
              width: compact ? OcOptical.leadingCircleCompact : OcOptical.leadingCircle,
              height: compact ? OcOptical.leadingCircleCompact : OcOptical.leadingCircle,
              decoration: BoxDecoration(
                color: context.oc.muted,
                shape: BoxShape.circle,
              ),
              child: OcGlyph(
                glyph,
                size: compact ? OcOptical.leadingGlyphCompact : OcOptical.leadingGlyph,
                strokeWidth: OcOptical.headerGlyphStroke,
                color: context.oc.mutedForeground,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HighlightedText(
                    name,
                    query: _query,
                    style: TextStyle(
                      fontSize: compact ? OcOptical.rowTitle : OcOptical.entityTitle,
                      fontWeight: FontWeight.w500,
                      letterSpacing: compact ? OcOptical.rowTitleTracking : OcOptical.entityTitleTracking,
                      height: compact ? OcOptical.rowTitleHeight : OcOptical.entityTitleHeight,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    [
                      count == 1
                          ? t(context, 'projects.sessionsCount.one')
                          : t(context, 'projects.sessionsCount', {'count': '$count'}),
                      if (activity != null) activity,
                      if (pathHint != null && pathHint.isNotEmpty) pathHint,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            OcGlyph(
              expanded ? OcGlyphKind.chevronDown : OcGlyphKind.chevronRight,
              size: OcOptical.chevron,
              strokeWidth: OcOptical.headerGlyphStroke,
              color: context.oc.mutedForeground,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 6),
              child: OcGlyph(OcGlyphKind.ellipsis, size: OcOptical.overflow, strokeWidth: OcOptical.headerGlyphStroke, color: context.oc.mutedForeground),
            ),
          ],
        ),
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
        _sessionRow(
          context,
          visible[i],
          key: assignSessionKeys ? Key('home-session-${visible[i].id}') : null,
          unreadKey: assignSessionKeys,
        ),
      ],
      if (!showAll)
        Pressable(
          haptic: HapticStrength.light,
          onPressed: () => setState(() => _expandedMore.add(groupId)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 14, 10),
            child: Row(
              children: [
                Text(
                  t(context, 'projects.showMore'),
                  style: TextStyle(
                    fontSize: OcOptical.rowTitle,
                    letterSpacing: OcOptical.rowTitleTracking,
                    height: OcOptical.rowTitleHeight,
                    color: context.oc.mutedForeground,
                  ),
                ),
                const Spacer(),
                OcGlyph(OcGlyphKind.chevronRight, size: OcOptical.chevron, strokeWidth: OcOptical.headerGlyphStroke, color: context.oc.mutedForeground),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _sessionRow(BuildContext context, HomeSessionRow row, {Key? key, bool unreadKey = false}) {
    return Pressable(
      key: key ?? Key('home-session-${row.id}-nested'),
      haptic: HapticStrength.light,
      onPressed: () => _openChat(context, row),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: OcOptical.sessionBullet,
              height: OcOptical.sessionBullet,
              decoration: BoxDecoration(
                color: row.unread ? context.oc.unreadDot : context.oc.mutedForeground.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: row.unread && unreadKey ? const SizedBox(key: Key('unread-dot')) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HighlightedText(
                row.title,
                query: _query,
                style: const TextStyle(
                  fontSize: OcOptical.rowTitle,
                  fontWeight: FontWeight.w400,
                  letterSpacing: OcOptical.rowTitleTracking,
                  height: OcOptical.rowTitleHeight,
                ),
              ),
            ),
            if (formatRelativeTime(row.updated) != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: Text(
                  formatRelativeTime(row.updated)!,
                  style: TextStyle(
                    fontSize: OcOptical.meta,
                    fontWeight: FontWeight.w400,
                    letterSpacing: OcOptical.metaTracking,
                    height: OcOptical.metaHeight,
                    color: context.oc.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
