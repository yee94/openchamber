import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/home_session.dart';
import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';

class ProjectsHomeScreen extends StatelessWidget {
  const ProjectsHomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final rows = demoHomeSessions();
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
                  _openChat(
                    context,
                    const HomeSessionRow(
                      id: 'sess-new',
                      title: 'New Session',
                      projectLabel: 'openchamber',
                      kind: HomeSessionKind.catalog,
                    ),
                  );
                case 'scan':
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t(context, 'connect.qr.todo'))),
                  );
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (attention.isNotEmpty) ...[
            _sectionLabel(context, 'projects.section.pinned'),
            _card(
              context,
              children: attention
                  .map((row) => _sessionTile(context, row))
                  .toList(),
            ),
            const SizedBox(height: OcTokens.sectionStackGap),
          ],
          _sectionLabel(context, 'projects.section.sessions'),
          if (catalog.isEmpty)
            Text(t(context, 'projects.empty'))
          else
            _card(context, children: catalog.map((row) => _sessionTile(context, row)).toList()),
        ],
      ),
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
      title: Text(row.title),
      // 1.19.3-beta.4: pinned / in-progress share "项目 · 分支".
      subtitle: Text(row.subtitle),
      // 1.19.2: unread rows keep the unread dot.
      trailing: row.unread
          ? const Icon(Icons.circle, size: 8, color: OcTokens.unreadDot, key: Key('unread-dot'))
          : null,
      onTap: () => _openChat(context, row),
    );
  }

  void _openChat(BuildContext context, HomeSessionRow row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(session: row),
      ),
    );
  }
}
