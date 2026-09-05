import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_controller.dart';
import '../../data/file_preview.dart';
import '../../data/openchamber_api.dart';
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
  final TextEditingController _search = TextEditingController();
  List<FilesystemEntry> _entries = const [];
  List<FileSearchResult> _results = const [];
  String? _previewPath;
  String? _previewText;
  Uint8List? _previewBytes;
  bool _previewTruncated = false;
  String? _errorKey;
  bool _loading = true;
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(_load(_path));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String path) async {
    _debounce?.cancel();
    setState(() {
      _loading = true;
      _errorKey = null;
      _previewPath = null;
      _previewText = null;
      _previewBytes = null;
      _previewTruncated = false;
      _results = const [];
      _searching = false;
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
        _errorKey = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () => unawaited(_runSearch(query)));
  }

  Future<void> _runSearch(String query) async {
    try {
      final results = await widget.controller.searchFilesystemFiles(directory: _path, query: query);
      if (!mounted || _search.text.trim() != query) return;
      setState(() {
        _results = results;
        _searching = false;
        _errorKey = null;
      });
    } on OpenChamberHttpException {
      if (!mounted || _search.text.trim() != query) return;
      setState(() {
        _errorKey = 'mobile.files.error.listFailed';
        _searching = false;
      });
    }
  }

  Future<void> _openPath(String path, {bool directory = false}) async {
    if (directory) {
      _search.clear();
      await _load(path);
      return;
    }
    if (isHtmlFile(path)) {
      await showHtmlPreviewSheet(
        context: context,
        path: path,
        loadContent: widget.controller.readWorkspaceFile,
      );
      return;
    }
    setState(() {
      _errorKey = null;
      _previewPath = path;
      _previewText = null;
      _previewBytes = null;
      _previewTruncated = false;
    });
    try {
      if (isRasterPreviewImage(path)) {
        final bytes = await widget.controller.readWorkspaceRawFile(path);
        if (!mounted) return;
        setState(() => _previewBytes = bytes);
        return;
      }
      final text = await widget.controller.readWorkspaceFile(path);
      if (!mounted) return;
      final truncated = text.length > mobileFilePreviewCharLimit;
      setState(() {
        _previewText = truncated ? text.substring(0, mobileFilePreviewCharLimit) : text;
        _previewTruncated = truncated;
      });
    } on OpenChamberHttpException {
      if (!mounted) return;
      setState(() => _errorKey = 'mobile.files.error.readUnavailable');
    }
  }

  Future<void> _openEntry(FilesystemEntry entry) {
    return _openPath(entry.path, directory: entry.isDirectory);
  }

  Future<void> _copy(String value, String successKey) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, successKey))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, 'mobile.files.toast.copyFailed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final parent = browseParentPath(_path);
    final query = _search.text.trim();
    final searching = query.isNotEmpty;
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
                if (_previewPath != null)
                  Pressable(
                    key: const Key('files-browser-back'),
                    haptic: HapticStrength.light,
                    onPressed: () => setState(() {
                      _previewPath = null;
                      _previewText = null;
                      _previewBytes = null;
                      _previewTruncated = false;
                    }),
                    child: const SizedBox(width: 36, height: 36, child: Center(child: OcGlyph(OcGlyphKind.chevronBack, size: 16))),
                  )
                else if (parent != null)
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
                  key: const Key('files-browser-refresh'),
                  haptic: HapticStrength.light,
                  onPressed: () => unawaited(_load(_path)),
                  child: Semantics(
                    button: true,
                    label: t(context, 'mobile.files.refreshAria'),
                    child: const SizedBox(width: 36, height: 36, child: Center(child: OcGlyph(OcGlyphKind.cloud, size: 16))),
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
            if (_previewPath == null)
              TextField(
                key: const Key('files-browser-search'),
                controller: _search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: t(context, 'mobile.files.search.placeholder'),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 8, right: 4),
                    child: OcGlyph(OcGlyphKind.search, size: 16),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ),
            if (_errorKey != null)
              Text(t(context, _errorKey!), style: TextStyle(color: tokens.statusError)),
            Expanded(child: _body(tokens, searching: searching)),
          ],
        ),
      ),
    );
  }

  Widget _body(OcTokens tokens, {required bool searching}) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_previewPath != null) return _preview(tokens);
    if (searching) {
      if (_searching) return Center(child: Text(t(context, 'common.loading')));
      if (_results.isEmpty) return Center(child: Text(t(context, 'mobile.files.search.empty')));
      return ListView.builder(
        key: const Key('files-browser-search-list'),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final result = _results[index];
          return Pressable(
            key: Key('files-browser-search-${fileNameFromPath(result.path)}'),
            haptic: HapticStrength.light,
            onPressed: () => unawaited(_openPath(result.path)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(fileNameFromPath(result.path), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(result.relativePath, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: OcTokens.textMeta, color: tokens.mutedForeground)),
                ],
              ),
            ),
          );
        },
      );
    }
    if (_entries.isEmpty) return Center(child: Text(t(context, 'mobile.files.empty.directory')));
    return ListView.builder(
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
    );
  }

  Widget _preview(OcTokens tokens) {
    final path = _previewPath!;
    final image = isRasterPreviewImage(path);
    return ListView(
      key: const Key('files-browser-preview'),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                fileNameFromPath(path),
                style: ocCssInk(TextStyle(fontWeight: FontWeight.w600, color: tokens.foreground)),
              ),
            ),
            Pressable(
              key: const Key('files-browser-copy-path'),
              haptic: HapticStrength.light,
              onPressed: () => unawaited(_copy(path, 'mobile.files.toast.pathCopied')),
              child: Semantics(
                button: true,
                label: t(context, 'mobile.files.copyPathAria'),
                child: const SizedBox(width: 36, height: 36, child: Center(child: OcGlyph(OcGlyphKind.copy, size: 16))),
              ),
            ),
            if (!image)
              Pressable(
                key: const Key('files-browser-copy-content'),
                haptic: HapticStrength.light,
                onPressed: _previewText == null
                    ? null
                    : () => unawaited(_copy(_previewText!, 'mobile.files.toast.contentCopied')),
                child: Semantics(
                  button: true,
                  label: t(context, 'mobile.files.copyContentAria'),
                  child: const SizedBox(width: 36, height: 36, child: Center(child: OcGlyph(OcGlyphKind.copy, size: 16))),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (image)
          _previewBytes == null
              ? Text(t(context, 'common.loading'))
              : Image.memory(key: const Key('files-browser-image'), _previewBytes!)
        else ...[
          if (_previewTruncated)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(t(context, 'mobile.files.file.truncated'), style: TextStyle(color: tokens.mutedForeground)),
            ),
          SelectableText(_previewText ?? '', style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: tokens.foreground)),
        ],
      ],
    );
  }
}
