import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/home_session.dart';
import '../../data/session_index.dart';
import '../../l10n/app_strings.dart';
import '../../navigation/platform_route.dart';
import '../../native/haptics.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';
import 'highlighted_text.dart';

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
  final _haptics = NativeHaptics();

  AppController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final rows = filterSessionsForSearch(controller.sessions, _query);
        final attention = rows.where((row) => row.kind != HomeSessionKind.catalog).toList();
        final catalog = rows.where((row) => row.kind == HomeSessionKind.catalog).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(t(context, 'tabs.projects')),
            actions: [
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.add_circle_outline),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: controller.refreshSessions,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + widget.bottomOccupancy),
              children: [
                TextField(
                  key: const Key('projects-search'),
                  decoration: InputDecoration(
                    hintText: t(context, 'projects.search.placeholder'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: OcTokens.sectionStackGap),
                if (controller.sessionsErrorKey != null)
                  Text(
                    t(context, controller.sessionsErrorKey!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  )
                else if (controller.sessionsLoading && controller.sessions.isEmpty)
                  Text(t(context, 'projects.loading'))
                else ...[
                  if (attention.isNotEmpty) ...[
                    _sectionLabel(context, 'projects.section.pinned'),
                    _card(
                      context,
                      children: attention.map((row) => _sessionTile(context, row)).toList(),
                    ),
                    const SizedBox(height: OcTokens.sectionStackGap),
                  ],
                  _sectionLabel(context, 'projects.section.sessions'),
                  if (catalog.isEmpty)
                    Text(t(context, 'projects.empty'))
                  else
                    _card(context, children: catalog.map((row) => _sessionTile(context, row)).toList()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String key) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: OcTokens.sectionGap),
      child: Text(
        t(context, key),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }

  Widget _card(BuildContext context, {required List<Widget> children}) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(OcTokens.groupRadius),
      child: Column(children: children),
    );
  }

  Widget _sessionTile(BuildContext context, HomeSessionRow row) {
    return ListTile(
      key: Key('home-session-${row.id}'),
      minVerticalPadding: 12,
      title: HighlightedText(row.title, query: _query),
      subtitle: HighlightedText(row.subtitle, query: _query),
      trailing: row.unread
          ? const Icon(Icons.circle, size: 8, color: OcTokens.unreadDot, key: Key('unread-dot'))
          : null,
      onTap: () {
        _haptics.impact(HapticStrength.light);
        _openChat(context, row);
      },
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
