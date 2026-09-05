import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/openchamber_api.dart';
import '../../data/openchamber_http.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

Future<bool> showNewProjectSheet({
  required BuildContext context,
  required AppController controller,
}) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => NewProjectSheet(controller: controller),
  );
  return added == true;
}

class NewProjectSheet extends StatefulWidget {
  const NewProjectSheet({super.key, required this.controller});

  final AppController controller;

  @override
  State<NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<NewProjectSheet> {
  final TextEditingController _path = TextEditingController();
  List<FilesystemEntry> _entries = const [];
  String? _errorKey;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _loadHome() async {
    if (!widget.controller.isConnected) {
      setState(() {
        _loading = false;
        _errorKey = 'projects.newProject.needsServer';
      });
      return;
    }
    try {
      final home = await widget.controller.filesystemHome();
      if (!mounted) return;
      _path.text = home;
      await _list(home);
    } on OpenChamberHttpException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorKey = 'directoryExplorerDialog.browseFailed';
      });
    }
  }

  Future<void> _list(String path) async {
    setState(() {
      _loading = true;
      _errorKey = null;
    });
    try {
      final entries = await widget.controller.listFilesystem(path);
      if (!mounted) return;
      setState(() {
        _entries = entries.where((entry) => entry.isDirectory).toList();
        _loading = false;
      });
    } on OpenChamberHttpException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorKey = 'directoryExplorerDialog.browseFailed';
      });
    }
  }

  Future<void> _add() async {
    setState(() => _saving = true);
    final ok = await widget.controller.addProject(path: _path.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _errorKey = widget.controller.lastMutationErrorKey ?? 'chat.mobileStatus.toast.addProjectFailed');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    return Material(
      key: const Key('new-project-sheet'),
      color: tokens.pageBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t(context, 'directoryExplorerDialog.title'),
              style: ocCssInk(TextStyle(
                fontSize: OcTokens.textUiLabel,
                fontWeight: FontWeight.w600,
                color: tokens.foreground,
              )),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('new-project-path'),
              controller: _path,
              decoration: InputDecoration(
                hintText: t(context, 'directoryExplorerDialog.pathInput.placeholder'),
              ),
              onSubmitted: _list,
            ),
            const SizedBox(height: 12),
            if (_errorKey != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t(context, _errorKey!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in _entries)
                      ListTile(
                        key: Key('new-project-entry-${entry.name}'),
                        leading: OcGlyph(
                          OcGlyphKind.code,
                          size: 16,
                          strokeWidth: OcOptical.detailNavGlyphStroke,
                          color: tokens.mutedForeground,
                        ),
                        title: Text(entry.name),
                        onTap: () {
                          _path.text = entry.path;
                          _list(entry.path);
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Pressable(
              haptic: HapticStrength.light,
              onPressed: _saving ? null : () => unawaited(_add()),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  key: const Key('new-project-add'),
                  height: 44,
                  child: Center(
                    child: Text(
                      t(context, 'directoryExplorerDialog.actions.addProject'),
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
