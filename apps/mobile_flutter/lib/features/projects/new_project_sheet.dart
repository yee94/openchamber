import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/openchamber_api.dart';
import '../../data/openchamber_http.dart';
import '../../data/project_id.dart';
import '../../data/settings_remote.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import 'explorer_paths.dart';

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
  final TextEditingController _cloneUrl = TextEditingController();
  List<FilesystemEntry> _entries = const [];
  List<SettingsNamedItem> _identities = const [];
  String? _identityId;
  String? _errorKey;
  bool _loading = true;
  bool _saving = false;
  bool _showHidden = false;
  bool _cloneMode = false;

  @override
  void initState() {
    super.initState();
    _loadHome();
    unawaited(_loadIdentities());
  }

  @override
  void dispose() {
    _path.dispose();
    _cloneUrl.dispose();
    super.dispose();
  }

  Future<void> _loadIdentities() async {
    final identities = await widget.controller.gitIdentities();
    if (!mounted) return;
    setState(() {
      _identities = identities;
      _identityId ??= identities.isEmpty ? null : identities.first.id;
    });
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

  Iterable<FilesystemEntry> get _visibleEntries {
    return _entries.where((entry) => _showHidden || !isHiddenDirectoryName(entry.name));
  }

  Future<void> _add() async {
    setState(() => _saving = true);
    final bool ok;
    if (_cloneMode) {
      ok = await widget.controller.cloneAndAddProject(
        remoteUrl: _cloneUrl.text,
        destinationPath: normalizeProjectDirectory(_path.text),
        gitIdentityId: _identityId,
      );
    } else {
      ok = await widget.controller.addProject(path: _path.text);
    }
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
    final added = widget.controller.settingsProjectRecords();
    final parent = browseParentPath(_path.text);
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    t(context, 'directoryExplorerDialog.title'),
                    style: ocCssInk(TextStyle(
                      fontSize: OcTokens.textUiLabel,
                      fontWeight: FontWeight.w600,
                      color: tokens.foreground,
                    )),
                  ),
                ),
                Pressable(
                  key: const Key('new-project-hidden'),
                  haptic: HapticStrength.light,
                  onPressed: () => setState(() => _showHidden = !_showHidden),
                  child: Text(
                    t(context, 'directoryExplorerDialog.toggle.showHidden'),
                    style: TextStyle(
                      fontSize: OcTokens.textMeta,
                      color: _showHidden ? tokens.primary : tokens.mutedForeground,
                    ),
                  ),
                ),
              ],
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
            if (_cloneMode) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('new-project-clone-url'),
                controller: _cloneUrl,
                decoration: InputDecoration(
                  hintText: t(context, 'directoryExplorerDialog.clone.remoteUrlPlaceholder'),
                ),
              ),
              if (_identities.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButton<String>(
                  key: const Key('new-project-git-identity'),
                  value: _identities.any((item) => item.id == _identityId) ? _identityId : _identities.first.id,
                  isExpanded: true,
                  items: [
                    for (final identity in _identities)
                      DropdownMenuItem(
                        value: identity.id,
                        child: Text(identity.subtitle == null ? identity.title : '${identity.title} · ${identity.subtitle}'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _identityId = value),
                ),
              ],
            ],
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
                    if (parent != null)
                      ListTile(
                        key: const Key('new-project-entry-up'),
                        leading: OcGlyph(
                          OcGlyphKind.chevronBack,
                          size: 16,
                          strokeWidth: OcOptical.detailNavGlyphStroke,
                          color: tokens.mutedForeground,
                        ),
                        title: Text(t(context, 'directoryExplorerDialog.browse.parentDirectory')),
                        onTap: () {
                          _path.text = parent;
                          unawaited(_list(parent));
                        },
                      ),
                    for (final entry in _visibleEntries)
                      ListTile(
                        key: Key('new-project-entry-${entry.name}'),
                        leading: OcGlyph(
                          OcGlyphKind.code,
                          size: 16,
                          strokeWidth: OcOptical.detailNavGlyphStroke,
                          color: tokens.mutedForeground,
                        ),
                        title: Text(entry.name),
                        trailing: pathAlreadyAdded(added, entry.path)
                            ? Text(
                                t(context, 'directoryExplorerDialog.browse.addedBadge'),
                                style: TextStyle(fontSize: OcTokens.textMeta, color: tokens.mutedForeground),
                              )
                            : null,
                        onTap: () {
                          _path.text = entry.path;
                          unawaited(_list(entry.path));
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Pressable(
                    haptic: HapticStrength.light,
                    onPressed: () => setState(() => _cloneMode = !_cloneMode),
                    child: SizedBox(
                      key: const Key('new-project-clone-toggle'),
                      height: 44,
                      child: Center(
                        child: Text(
                          t(
                            context,
                            _cloneMode
                                ? 'directoryExplorerDialog.actions.addLocalProject'
                                : 'directoryExplorerDialog.actions.cloneRepository',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Pressable(
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
                            t(
                              context,
                              _cloneMode
                                  ? 'directoryExplorerDialog.actions.cloneAndAdd'
                                  : 'directoryExplorerDialog.actions.addProject',
                            ),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
