import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/file_preview.dart';
import '../../data/openchamber_api.dart';
import '../../data/openchamber_http.dart';
import '../../data/project_id.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import '../projects/explorer_paths.dart';
import 'html_preview_sheet.dart';

Future<void> showFilesBrowserSheet({
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
      child: FilesBrowserSheet(controller: controller, root: directory),
    ),
  );
}

class FilesBrowserSheet extends StatefulWidget {
  const FilesBrowserSheet({super.key, required this.controller, required this.root});

  final AppController controller;
  final String root;

  @override
  State<FilesBrowserSheet> createState() => _FilesBrowserSheetState();
}

class _FilesBrowserSheetState extends State<FilesBrowserSheet> {
  late String _path = normalizeProjectDirectory(widget.root);
  List<FilesystemEntry> _entries = const [];
  String? _previewPath;
  String? _previewText;
  String? _errorKey;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load(_path));
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _errorKey = null;
      _previewPath = null;
      _previewText = null;
    });
    try {
      final entries = await widget.controller.listFilesystem(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = entries;
        _loading = false;
      });
    } on OpenChamberHttpException {
      if (!mounted) return;
      setState(() {
        _errorKey = 'mobile.files.error.listFailed';
        _loading = false;
      });
    }
  }

  Future<void> _openEntry(FilesystemEntry entry) async {
    if (entry.isDirectory) {
      await _load(entry.path);
      return;
    }
    if (isHtmlFile(entry.path)) {
      await showHtmlPreviewSheet(
        context: context,
        path: entry.path,
        loadContent: widget.controller.readWorkspaceFile,
      );
      return;
    }
    try {
      final text = await widget.controller.readWorkspaceFile(entry.path);
      if (!mounted) return;
      setState(() {
        _previewPath = entry.path;
        _previewText = text;
      });
    } on OpenChamberHttpException {
      if (!mounted) return;
      setState(() => _errorKey = 'mobile.files.error.readUnavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final parent = browseParentPath(_path);
    return Material(
      key: const Key('files-browser-sheet'),
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
                    t(context, 'mobile.menu.files'),
                    style: ocCssInk(TextStyle(
                      fontSize: OcTokens.textUiLabel,
                      fontWeight: FontWeight.w600,
                      color: tokens.foreground,
                    )),
                  ),
                ),
                if (parent != null)
                  Pressable(
                    key: const Key('files-browser-up'),
                    haptic: HapticStrength.light,
                    onPressed: () => unawaited(_load(parent)),
                    child: Semantics(
                      button: true,
                      label: t(context, 'mobile.files.parentDirectory'),
                      child: const SizedBox(width: 36, height: 36, child: Center(child: OcGlyph(OcGlyphKind.chevronBack, size: 16))),
                    ),
                  ),
                Pressable(
                  key: const Key('files-browser-close'),
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _path.isEmpty ? t(context, 'mobile.files.rootDirectory') : _path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: OcTokens.textMeta, color: tokens.mutedForeground),
              ),
            ),
            const SizedBox(height: 8),
            if (_errorKey != null)
              Text(t(context, _errorKey!), style: TextStyle(color: tokens.statusError)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _previewPath != null
                      ? ListView(
                          key: const Key('files-browser-preview'),
                          children: [
                            Text(
                              fileNameFromPath(_previewPath!),
                              style: ocCssInk(TextStyle(fontWeight: FontWeight.w600, color: tokens.foreground)),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(_previewText ?? '', style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: tokens.foreground)),
                          ],
                        )
                      : _entries.isEmpty
                          ? Center(child: Text(t(context, 'mobile.files.empty.directory')))
                          : ListView.builder(
                              key: const Key('files-browser-list'),
                              itemCount: _entries.length,
                              itemBuilder: (context, index) {
                                final entry = _entries[index];
                                return Pressable(
                                  key: Key('files-browser-entry-${entry.name}'),
                                  haptic: HapticStrength.light,
                                  onPressed: () => unawaited(_openEntry(entry)),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(minHeight: 48),
                                    child: Row(
                                      children: [
                                        OcGlyph(
                                          entry.isDirectory ? OcGlyphKind.folder : OcGlyphKind.file,
                                          size: 16,
                                          color: tokens.foreground,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        if (entry.isDirectory)
                                          OcGlyph(OcGlyphKind.chevronRight, size: 14, color: tokens.mutedForeground),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
