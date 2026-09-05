import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/github_worktree.dart';
import '../../l10n/app_strings.dart';
import '../../theme/ios_chrome.dart';

Future<GitHubWorktreeItem?> showGitHubItemSheet({
  required BuildContext context,
  required AppController controller,
  required String directory,
}) {
  return showModalBottomSheet<GitHubWorktreeItem>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => GitHubItemSheet(controller: controller, directory: directory),
  );
}

class GitHubItemSheet extends StatefulWidget {
  const GitHubItemSheet({super.key, required this.controller, required this.directory});

  final AppController controller;
  final String directory;

  @override
  State<GitHubItemSheet> createState() => _GitHubItemSheetState();
}

class _GitHubItemSheetState extends State<GitHubItemSheet> {
  int _tab = 0;
  bool _loading = true;
  bool _connected = true;
  List<GitHubWorktreeItem> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final connected = await widget.controller.githubAuthConnected();
    if (!mounted) return;
    if (!connected) {
      setState(() {
        _connected = false;
        _loading = false;
        _items = const [];
      });
      return;
    }
    final items = await widget.controller.listGithubItems(
      directory: widget.directory,
      kind: _tab == 1 ? 'pr' : 'issue',
    );
    if (!mounted) return;
    setState(() {
      _connected = true;
      _loading = false;
      _items = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    return Material(
      key: const Key('github-item-sheet'),
      color: tokens.pageBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t(context, 'session.newWorktree.actions.startFromGitHubIssuePr'),
              style: ocCssInk(TextStyle(
                fontSize: OcTokens.textUiLabel,
                fontWeight: FontWeight.w600,
                color: tokens.foreground,
              )),
            ),
            const SizedBox(height: 12),
            SegmentedPill(
              labels: [
                t(context, 'session.githubIntegration.tabs.issues'),
                t(context, 'session.githubIntegration.tabs.prs'),
              ],
              selectedIndex: _tab,
              onSelected: (index) {
                setState(() => _tab = index);
                unawaited(_load());
              },
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_connected)
              Text(
                key: const Key('github-item-disconnected'),
                t(context, 'session.githubIntegration.error.notConnected'),
                style: TextStyle(color: tokens.mutedForeground),
              )
            else if (_items.isEmpty)
              Text(
                key: const Key('github-item-empty'),
                t(context, 'session.githubIntegration.empty'),
                style: TextStyle(color: tokens.mutedForeground),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in _items)
                      ListTile(
                        key: Key('github-item-${githubItemKey(item)}'),
                        title: Text('#${item.number} ${item.title}'),
                        subtitle: item.head == null ? null : Text(item.head!),
                        onTap: () => Navigator.of(context).pop(item),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
