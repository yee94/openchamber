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
  List<GitRemote> _remotes = const [];
  String? _diffPath;
  String? _diffText;
  String? _errorKey;
  List<String> _highlights = const [];
  bool _loading = true;
  bool _saving = false;
  bool _generating = false;
  bool _syncing = false;
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

  void _toast(String key, [Map<String, String>? params]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, key, params))));
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _errorKey = null;
      _diffPath = null;
    });
    try {
      final status = await widget.controller.loadGitStatus(widget.directory);
      List<GitRemote> remotes = const [];
      try {
        remotes = await widget.controller.loadGitRemotes(widget.directory);
      } on OpenChamberHttpException {
        remotes = const [];
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _remotes = remotes;
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

  Future<void> _commit({required bool pushAfter}) async {
    final staged = _status?.files.where((file) => file.staged).map((file) => file.path).toList() ?? const [];
    if (_message.text.trim().isEmpty) {
      _toast('gitView.toast.enterCommitMessage');
      return;
    }
    if (staged.isEmpty) {
      _toast('gitView.toast.selectFileToCommit');
      return;
    }
    setState(() => _saving = true);
    final ok = pushAfter
        ? await widget.controller.commitAndPushGitChanges(widget.directory, _message.text, files: staged..sort())
        : await widget.controller.commitGitChanges(widget.directory, _message.text, files: staged..sort());
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      final error = widget.controller.lastMutationErrorKey;
      if (error != null) {
        setState(() => _errorKey = error);
        _toast(error, error == 'gitView.toast.syncActionFailed' ? {'action': t(context, 'gitView.sync.syncChanges')} : null);
      }
      return;
    }
    _message.clear();
    _highlights = const [];
    _toast('gitView.toast.commitCreated');
    if (pushAfter) _toast('gitView.toast.alreadyUpToDate');
    await _reload();
  }

  Future<void> _generate() async {
    final staged = _status?.files.where((file) => file.staged).map((file) => file.path).toList() ?? const [];
    if (staged.isEmpty) {
      _toast('gitView.toast.selectFileToDescribe');
      return;
    }
    setState(() => _generating = true);
    final generated = await widget.controller.generateGitCommitMessage(directory: widget.directory, files: staged..sort());
    if (!mounted) return;
    setState(() => _generating = false);
    if (generated == null) {
      final error = widget.controller.lastMutationErrorKey ?? 'gitView.toast.generateCommitMessageFailed';
      _toast(error);
      return;
    }
    setState(() {
      _message.text = generated.subject;
      _highlights = generated.highlights;
    });
  }

  Future<void> _sync() async {
    final status = _status;
    final remote = _effectiveRemote;
    if (remote == null || status == null) {
      _toast('mobile.changes.noRemote');
      return;
    }
    if (status.behind > 0 && status.files.isNotEmpty) return;
    setState(() => _syncing = true);
    final ok = await widget.controller.syncGitChanges(widget.directory);
    if (!mounted) return;
    setState(() => _syncing = false);
    if (!ok) {
      final error = widget.controller.lastMutationErrorKey ?? 'gitView.toast.syncActionFailed';
      _toast(error, error == 'gitView.toast.syncActionFailed' ? {'action': t(context, 'gitView.sync.syncChanges')} : null);
      return;
    }
    _toast('gitView.toast.alreadyUpToDate');
    await _reload();
  }

  Future<void> _revert(String path) async {
    setState(() => _saving = true);
    final ok = await widget.controller.revertGitChanges(widget.directory, path);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      _toast(widget.controller.lastMutationErrorKey ?? 'gitView.toast.revertFailed');
      return;
    }
    _toast('gitView.toast.revertedFile', {'path': path});
    await _reload();
  }

  Future<void> _revertAll(List<String> paths) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'gitView.changes.revertAllDialogTitle')),
        content: Text(
          t(
            context,
            paths.length == 1 ? 'gitView.changes.revertAllDescriptionSingle' : 'gitView.changes.revertAllDescriptionPlural',
            {'count': '${paths.length}'},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t(context, 'gitView.common.cancel')),
          ),
          TextButton(
            key: const Key('changes-revert-all-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t(context, 'gitView.changes.revertAll')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    for (final path in paths) {
      final ok = await widget.controller.revertGitChanges(widget.directory, path);
      if (!ok) {
        if (mounted) {
          setState(() => _saving = false);
          _toast(widget.controller.lastMutationErrorKey ?? 'gitView.toast.revertFailed');
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _toast(
      paths.length == 1 ? 'gitView.toast.revertedFilesSingle' : 'gitView.toast.revertedFilesPlural',
      {'count': '${paths.length}'},
    );
    await _reload();
  }

  GitRemote? get _effectiveRemote {
    final trackingName = _status?.tracking?.split('/').first;
    if (trackingName != null && trackingName.isNotEmpty) {
      for (final remote in _remotes) {
        if (remote.name == trackingName) return remote;
      }
      if (_remotes.isEmpty) return GitRemote(name: trackingName);
    }
    return _remotes.isEmpty ? null : _remotes.first;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final status = _status;
    final staged = status?.files.where((file) => file.staged).toList() ?? const [];
    final unstaged = status?.files.where((file) => file.unstaged).toList() ?? const [];
    final ahead = status?.ahead ?? 0;
    final behind = status?.behind ?? 0;
    final blocksRebase = behind > 0 && (status?.files.isNotEmpty ?? false);
    final syncDisabled = _saving || _syncing || _effectiveRemote == null || blocksRebase;
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
                  )
                else
                  Pressable(
                    key: const Key('changes-sync'),
                    haptic: HapticStrength.light,
                    onPressed: syncDisabled ? null : () => unawaited(_sync()),
                    child: Semantics(
                      button: true,
                      label: (ahead > 0 || behind > 0)
                          ? t(context, 'gitView.sync.syncChangesTooltip', {'ahead': '$ahead', 'behind': '$behind'})
                          : t(context, 'gitView.sync.syncChanges'),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            OcGlyph(_syncing ? OcGlyphKind.hourglass : OcGlyphKind.cloud, size: 16),
                            if (ahead > 0 || behind > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(color: tokens.statusError, shape: BoxShape.circle),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
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
            if (_errorKey != null) Text(t(context, _errorKey!, _errorKey == 'gitView.toast.syncActionFailed' ? {'action': t(context, 'gitView.sync.syncChanges')} : null), style: TextStyle(color: tokens.statusError)),
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
                                  Wrap(
                                    spacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(t(context, 'gitView.changes.title'), style: ocCssInk(TextStyle(fontWeight: FontWeight.w600, color: tokens.foreground))),
                                      Pressable(
                                        key: const Key('changes-revert-all'),
                                        haptic: HapticStrength.light,
                                        onPressed: _saving ? null : () => unawaited(_revertAll(unstaged.map((file) => file.path).toList())),
                                        child: Text(t(context, 'gitView.changes.revertAll')),
                                      ),
                                    ],
                                  ),
                                  for (final file in unstaged) _fileRow(file, staged: false),
                                ],
                              ],
                            ),
            ),
            if (_diffPath == null) ...[
              if (_highlights.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t(context, 'gitView.commit.aiHighlights.title')}: ${_highlights.join(' · ')}',
                          key: const Key('changes-highlights'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Pressable(
                        key: const Key('changes-highlight-insert'),
                        haptic: HapticStrength.light,
                        onPressed: () {
                          final current = _message.text.trim();
                          _message.text = current.isEmpty ? _highlights.join('\n') : '$current\n\n${_highlights.join('\n')}';
                          setState(() => _highlights = const []);
                        },
                        child: Text(t(context, 'gitView.commit.aiHighlights.insertAria')),
                      ),
                    ],
                  ),
                ),
              TextField(
                key: const Key('changes-commit-message'),
                controller: _message,
                decoration: InputDecoration(hintText: t(context, 'gitView.commit.messagePlaceholder')),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Pressable(
                    key: const Key('changes-generate'),
                    haptic: HapticStrength.light,
                    onPressed: _saving || _generating ? null : () => unawaited(_generate()),
                    child: Text(t(context, 'gitView.commit.generate')),
                  ),
                  Pressable(
                    key: const Key('changes-commit'),
                    haptic: HapticStrength.medium,
                    onPressed: _saving || staged.isEmpty ? null : () => unawaited(_commit(pushAfter: false)),
                    child: Text(_saving ? t(context, 'gitView.commit.committing') : t(context, 'gitView.commit.commit')),
                  ),
                  Pressable(
                    key: const Key('changes-commit-push'),
                    haptic: HapticStrength.medium,
                    onPressed: _saving || staged.isEmpty ? null : () => unawaited(_commit(pushAfter: true)),
                    child: Text(t(context, 'gitView.commit.push')),
                  ),
                ],
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
        if (!staged)
          Pressable(
            key: Key('changes-revert-${file.path}'),
            haptic: HapticStrength.light,
            onPressed: _saving ? null : () => unawaited(_revert(file.path)),
            child: Semantics(
              button: true,
              label: t(context, 'gitView.changes.revertFileAria', {'path': file.path}),
              child: const SizedBox(width: 36, height: 36, child: Center(child: OcGlyph(OcGlyphKind.undo, size: 16))),
            ),
          ),
      ],
    );
  }
}
