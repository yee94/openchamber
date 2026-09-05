import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';

Future<bool> showNewWorktreeSheet({
  required BuildContext context,
  required AppController controller,
  required String directory,
}) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => NewWorktreeSheet(controller: controller, directory: directory),
  );
  return created == true;
}

class NewWorktreeSheet extends StatefulWidget {
  const NewWorktreeSheet({super.key, required this.controller, required this.directory});

  final AppController controller;
  final String directory;

  @override
  State<NewWorktreeSheet> createState() => _NewWorktreeSheetState();
}

class _NewWorktreeSheetState extends State<NewWorktreeSheet> {
  final TextEditingController _branch = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _startRef = TextEditingController();
  bool _saving = false;
  String? _errorKey;
  bool _syncName = true;

  @override
  void dispose() {
    _branch.dispose();
    _name.dispose();
    _startRef.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final branch = _branch.text.trim();
    final name = (_syncName ? branch : _name.text).trim();
    if (branch.isEmpty || name.isEmpty) {
      setState(() => _errorKey = 'session.newWorktree.error.branchNameRequired');
      return;
    }
    setState(() {
      _saving = true;
      _errorKey = null;
    });
    final ok = await widget.controller.createWorktree(
      directory: widget.directory,
      worktreeName: name,
      branchName: branch,
      startRef: _startRef.text.trim().isEmpty ? null : _startRef.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _errorKey = widget.controller.lastMutationErrorKey ?? 'sessions.sidebar.project.actions.worktreeCreateFailed');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    return Material(
      key: const Key('new-worktree-sheet'),
      color: tokens.pageBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t(context, 'session.newWorktree.title'),
              style: ocCssInk(TextStyle(
                fontSize: OcTokens.textUiLabel,
                fontWeight: FontWeight.w600,
                color: tokens.foreground,
              )),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('worktree-branch-field'),
              controller: _branch,
              decoration: InputDecoration(
                labelText: t(context, 'session.newWorktree.branchName'),
                hintText: t(context, 'session.newWorktree.branchNamePlaceholder'),
              ),
              onChanged: (value) {
                if (_syncName) _name.text = value;
              },
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('worktree-name-field'),
              controller: _name,
              decoration: InputDecoration(
                labelText: t(context, 'sessions.sidebar.project.actions.worktreeName'),
              ),
              onChanged: (_) => _syncName = false,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('worktree-start-ref-field'),
              controller: _startRef,
              decoration: InputDecoration(
                labelText: t(context, 'session.newWorktree.sourceBranch'),
                hintText: t(context, 'session.newWorktree.selectSourceBranchPlaceholder'),
              ),
            ),
            if (_errorKey != null) ...[
              const SizedBox(height: 8),
              Text(t(context, _errorKey!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Pressable(
              haptic: HapticStrength.light,
              onPressed: _saving ? null : () => unawaited(_create()),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  key: const Key('worktree-name-save'),
                  height: 44,
                  child: Center(
                    child: Text(
                      t(context, 'session.newWorktree.actions.createWorktree'),
                      style: ocCssInk(TextStyle(
                        fontSize: OcTokens.textUiLabel,
                        fontWeight: FontWeight.w600,
                        color: tokens.primaryForeground,
                      )),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
