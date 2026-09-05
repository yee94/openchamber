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

Future<void> showChangesSheet({
  required BuildContext context,
  required AppController controller,
  required String directory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.92,
      child: ChangesSheet(controller: controller, directory: directory),
    ),
  );
}

class ChangesSheet extends StatefulWidget {
  const ChangesSheet({super.key, required this.controller, required this.directory});

  final AppController controller;
  final String directory;

  @override
  State<ChangesSheet> createState() => _ChangesSheetState();
}

class _ChangesSheetState extends State<ChangesSheet> {
  GitStatusSnapshot? _status;
  String? _diffPath;
  String? _diffText;
  String? _errorKey;
  bool _loading = true;
  bool _saving = false;
  final TextEditingController _message = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _errorKey = null;
      _diffPath = null;
    });
    try {
      final status = await widget.controller.loadGitStatus(widget.directory);
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } on OpenChamberHttpException {
      if (!mounted) return;
      setState(() {
        _errorKey = 'mobile.changes.diffDetail.loadFailed';
        _loading = false;
      });
    }
  }

  Future<void> _openDiff(GitChangeFile file, {required bool staged}) async {
    try {
      final diff = await widget.controller.loadGitDiff(
        directory: widget.directory,
        path: file.path,
        staged: staged,
      );
      if (!mounted) return;
      setState(() {
        _diffPath = file.path;
        _diffText = diff;
      });
    } on OpenChamberHttpException {
      if (!mounted) return;
      setState(() => _errorKey = 'mobile.changes.diffDetail.loadFailed');
    }
  }

  Future<void> _toggleStage(GitChangeFile file) async {
    setState(() => _saving = true);
    final ok = file.staged
        ? await widget.controller.unstageGitPaths(widget.directory, [file.path])
        : await widget.controller.stageGitPaths(widget.directory, [file.path]);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      final error = widget.controller.lastMutationErrorKey;
      if (error != null) setState(() => _errorKey = error);
      return;
    }
    await _reload();
  }

  Future<void> _commit() async {
    setState(() => _saving = true);
    final ok = await widget.controller.commitGitChanges(widget.directory, _message.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      final error = widget.controller.lastMutationErrorKey;
      if (error != null) setState(() => _errorKey = error);
      return;
    }
    _message.clear();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final status = _status;
    final staged = status?.files.where((file) => file.staged).toList() ?? const [];
    final unstaged = status?.files.where((file) => file.unstaged).toList() ?? const [];
    return Material(
      key: const Key('changes-sheet'),
      color: tokens.pageBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + MediaQuery.viewPaddingOf(context).bottom),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t(context, 'mobile.menu.changes'),
                    style: ocCssInk(TextStyle(
                      fontSize: OcTokens.textUiLabel,
                      fontWeight: FontWeight.w600,
                      color: tokens.foreground,
                    )),
                  ),
                ),
                if (_diffPath != null)
                  Pressable(
                    key: const Key('changes-back'),
                    haptic: HapticStrength.light,
                    onPressed: () => setState(() => _diffPath = null),
                    child: const SizedBox(width: 36, height: 36, child: Center(child: OcGlyph(OcGlyphKind.chevronBack, size: 16))),
                  ),
                Pressable(
                  key: const Key('changes-close'),
                  haptic: HapticStrength.light,
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Semantics(
                    button: true,
                    label: t(context, 'mobile.surface.closeAria'),
                    child: const SizedBox(width: 36, height: 36, child: Center(child: OcGlyph(OcGlyphKind.xmark, size: 16))),
                  ),
                ),
              ],
            ),
            if (status != null && status.current.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t(context, 'mobile.changes.branchLabel', {'branch': status.current}),
                  style: TextStyle(fontSize: OcTokens.textMeta, color: tokens.mutedForeground),
                ),
              ),
            if (_errorKey != null) Text(t(context, _errorKey!), style: TextStyle(color: tokens.statusError)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _diffPath != null
                      ? ListView(
                          key: const Key('changes-diff'),
                          children: [
                            Text(
                              _diffPath!,
                              style: ocCssInk(TextStyle(fontWeight: FontWeight.w600, color: tokens.foreground)),
                            ),
                            Text(
                              t(context, 'mobile.changes.diffDetail.subtitle'),
                              style: TextStyle(color: tokens.mutedForeground, fontSize: OcTokens.textMeta),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              _diffText?.isEmpty == true
                                  ? t(context, 'mobile.changes.diffDetail.missingDescription')
                                  : _diffText!,
                              style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: tokens.foreground),
                            ),
                          ],
                        )
                      : (status == null || status.files.isEmpty)
                          ? Center(child: Text(t(context, 'mobile.changes.cleanDescription')))
                          : ListView(
                              key: const Key('changes-list'),
                              children: [
                                if (staged.isNotEmpty) ...[
                                  Text(t(context, 'gitView.changes.stagedTitle'), style: ocCssInk(TextStyle(fontWeight: FontWeight.w600, color: tokens.foreground))),
                                  for (final file in staged) _fileRow(file, staged: true),
                                ],
                                if (unstaged.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(t(context, 'gitView.changes.unstagedTitle'), style: ocCssInk(TextStyle(fontWeight: FontWeight.w600, color: tokens.foreground))),
                                  for (final file in unstaged) _fileRow(file, staged: false),
                                ],
                              ],
                            ),
            ),
            if (_diffPath == null) ...[
              TextField(
                key: const Key('changes-commit-message'),
                controller: _message,
                decoration: InputDecoration(hintText: t(context, 'gitView.commit.placeholder')),
              ),
              const SizedBox(height: 8),
              Pressable(
                key: const Key('changes-commit'),
                haptic: HapticStrength.medium,
                onPressed: _saving || staged.isEmpty ? null : () => unawaited(_commit()),
                child: Text(t(context, 'gitView.commit.commit')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fileRow(GitChangeFile file, {required bool staged}) {
    return Row(
      children: [
        Expanded(
          child: Pressable(
            key: Key('changes-file-${file.path}'),
            haptic: HapticStrength.light,
            onPressed: () => unawaited(_openDiff(file, staged: staged)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(file.path, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ),
        Pressable(
          key: Key(staged ? 'changes-unstage-${file.path}' : 'changes-stage-${file.path}'),
          haptic: HapticStrength.light,
          onPressed: _saving ? null : () => unawaited(_toggleStage(file)),
          child: Text(t(context, staged ? 'gitView.changes.unstage' : 'gitView.changes.stage')),
        ),
      ],
    );
  }
}
