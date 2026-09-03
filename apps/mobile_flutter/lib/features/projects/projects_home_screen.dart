import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/home_session.dart';
import '../../data/relative_time.dart';
import '../../data/session_index.dart';
import '../../l10n/app_strings.dart';
import '../../navigation/platform_route.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
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
  bool _pinnedExpanded = true;
  final Set<String> _collapsed = {};
  final Set<String> _expandedMore = {};
  final _haptics = NativeHaptics();

  AppController get controller => widget.controller;

  static const _visibleSlice = 4;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final rows = filterSessionsForSearch(controller.sessions, _query);
        final attention = rows.where((row) => row.kind != HomeSessionKind.catalog).toList();
        final groups = groupSessionsByProject(controller.sessions.where((row) {
          return sessionMatchesQuery(row, _query);
        }).toList());
        final inProgress = controller.sessions.where((row) => row.kind == HomeSessionKind.inProgress).toList();

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: controller.refreshSessions,
              child: ListView(
                padding: EdgeInsets.fromLTRB(0, 0, 0, 24 + widget.bottomOccupancy),
                children: [
                  if (inProgress.isNotEmpty)
                    StatusAttentionStrip(label: inProgress.first.title),
                  LargeTitleHeader(
                    title: t(context, 'tabs.projects'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularChromeButton(
                          key: const Key('projects-search-toggle'),
                          icon: _searchOpen ? CupertinoIcons.xmark : CupertinoIcons.search,
                          tooltip: t(context, 'projects.search.aria'),
                          onPressed: () {
                            _haptics.impact(HapticStrength.light);
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
                          child: Container(
                            width: OcChrome.headerButtonSize,
                            height: OcChrome.headerButtonSize,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(CupertinoIcons.add, size: 20, color: Colors.white),
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
                          prefixIcon: const Icon(CupertinoIcons.search, size: 18),
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
                    if (attention.isNotEmpty)
                      _projectCard(
                        context,
                        id: '__pinned__',
                        name: t(context, 'projects.section.pinned'),
                        icon: CupertinoIcons.pin_fill,
                        count: attention.length,
                        activity: attention.isEmpty ? null : formatRelativeTime(attention.first.updated),
                        pathHint: null,
                        expanded: _pinnedExpanded,
                        onToggle: () => setState(() => _pinnedExpanded = !_pinnedExpanded),
                        sessions: attention,
                        worktrees: const [],
                        assignSessionKeys: true,
                      ),
                    if (groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter, vertical: 24),
                        child: Text(t(context, 'projects.empty')),
                      )
                    else
                      for (final group in groups)
                        _projectCard(
                          context,
                          id: group.id,
                          name: group.name,
                          icon: CupertinoIcons.chevron_left_slash_chevron_right,
                          count: group.sessionCount,
                          activity: formatRelativeTime(group.latestUpdated),
                          pathHint: group.pathHint,
                          expanded: !_collapsed.contains(group.id),
                          onToggle: () => setState(() {
                            if (_collapsed.contains(group.id)) {
                              _collapsed.remove(group.id);
                            } else {
                              _collapsed.add(group.id);
                            }
                          }),
                          sessions: group.sessions,
                          worktrees: group.worktrees,
                          assignSessionKeys: true,
                          skipKeyedKinds: const {HomeSessionKind.pinned, HomeSessionKind.inProgress},
                        ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _projectCard(
    BuildContext context, {
    required String id,
    required String name,
    required IconData icon,
    required int count,
    required String? activity,
    required String? pathHint,
    required bool expanded,
    required VoidCallback onToggle,
    required List<HomeSessionRow> sessions,
    required List<WorktreeHomeGroup> worktrees,
    required bool assignSessionKeys,
    Set<HomeSessionKind> skipKeyedKinds = const {},
  }) {
    return GroupedInsetCard(
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: OcChrome.secondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HighlightedText(name, query: _query, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
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
                          style: const TextStyle(fontSize: 13, color: OcChrome.secondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                    size: 16,
                    color: OcChrome.secondary,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {},
                    icon: const Icon(CupertinoIcons.ellipsis, size: 16, color: OcChrome.secondary),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            ..._sessionSlice(context, id, sessions, assignSessionKeys, skipKeyedKinds),
            for (final tree in worktrees) _worktreeBlock(context, id, tree, assignSessionKeys, skipKeyedKinds),
          ],
        ],
      ),
    );
  }

  Widget _worktreeBlock(
    BuildContext context,
    String projectId,
    WorktreeHomeGroup tree,
    bool assignSessionKeys,
    Set<HomeSessionKind> skipKeyedKinds,
  ) {
    final key = '$projectId::${tree.name}';
    final expanded = !_collapsed.contains(key);
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            if (expanded) {
              _collapsed.add(key);
            } else {
              _collapsed.remove(key);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
            child: Row(
              children: [
                const Icon(CupertinoIcons.arrow_2_squarepath, size: 14, color: OcChrome.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: HighlightedText(
                    tree.name,
                    query: _query,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  tree.sessionCount == 1
                      ? t(context, 'projects.sessionsCount.one')
                      : t(context, 'projects.sessionsCount', {'count': '${tree.sessionCount}'}),
                  style: const TextStyle(fontSize: 13, color: OcChrome.secondary),
                ),
                const SizedBox(width: 6),
                Icon(
                  expanded ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                  size: 14,
                  color: OcChrome.secondary,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ..._sessionSlice(context, key, tree.sessions, assignSessionKeys, skipKeyedKinds),
      ],
    );
  }

  List<Widget> _sessionSlice(
    BuildContext context,
    String groupId,
    List<HomeSessionRow> sessions,
    bool assignSessionKeys,
    Set<HomeSessionKind> skipKeyedKinds,
  ) {
    final showAll = _expandedMore.contains(groupId) || sessions.length <= _visibleSlice;
    final visible = showAll ? sessions : sessions.take(_visibleSlice).toList();
    return [
      for (final row in visible)
        _sessionRow(
          context,
          row,
          key: assignSessionKeys && !skipKeyedKinds.contains(row.kind) ? Key('home-session-${row.id}') : null,
          unreadKey: assignSessionKeys && !skipKeyedKinds.contains(row.kind),
        ),
      if (!showAll)
        InkWell(
          onTap: () => setState(() => _expandedMore.add(groupId)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 16, 14),
            child: Row(
              children: [
                Text(t(context, 'projects.showMore'), style: const TextStyle(fontSize: 15, color: OcChrome.secondary)),
                const Spacer(),
                const Icon(CupertinoIcons.chevron_right, size: 14, color: OcChrome.secondary),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _sessionRow(BuildContext context, HomeSessionRow row, {Key? key, bool unreadKey = false}) {
    return InkWell(
      key: key ?? Key('home-session-${row.id}-nested'),
      onTap: () {
        _haptics.impact(HapticStrength.light);
        _openChat(context, row);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: row.unread ? Theme.of(context).colorScheme.primary : OcChrome.secondary.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: row.unread && unreadKey ? const SizedBox(key: Key('unread-dot')) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: HighlightedText(
                row.title,
                query: _query,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            if (formatRelativeTime(row.updated) != null)
              Text(
                formatRelativeTime(row.updated)!,
                style: const TextStyle(fontSize: 13, color: OcChrome.secondary),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {},
              icon: const Icon(CupertinoIcons.ellipsis, size: 16, color: OcChrome.secondary),
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
