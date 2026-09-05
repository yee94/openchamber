import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/file_preview.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

enum HtmlViewMode { preview, source }

Future<void> showHtmlPreviewSheet({
  required BuildContext context,
  required String path,
  required Future<String> Function(String path) loadContent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: false,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (sheetContext) {
      return SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height,
        child: HtmlPreviewSheet(path: path, loadContent: loadContent),
      );
    },
  );
}

class HtmlPreviewSheet extends StatefulWidget {
  const HtmlPreviewSheet({
    super.key,
    required this.path,
    required this.loadContent,
  });

  final String path;
  final Future<String> Function(String path) loadContent;

  @override
  State<HtmlPreviewSheet> createState() => _HtmlPreviewSheetState();
}

class _HtmlPreviewSheetState extends State<HtmlPreviewSheet> {
  HtmlViewMode _mode = HtmlViewMode.preview;
  bool _fullscreen = false;
  String? _content;
  String? _error;
  bool _loading = true;
  double _drag = 0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final content = await widget.loadContent(widget.path);
      if (!mounted) return;
      setState(() {
        _content = content;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = t(context, 'mobile.files.html.loadFailed');
      });
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == HtmlViewMode.preview ? HtmlViewMode.source : HtmlViewMode.preview;
    });
  }

  void _enterFullscreen() {
    setState(() => _fullscreen = true);
  }

  void _exitFullscreen() {
    if (!_fullscreen) return;
    setState(() => _fullscreen = false);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (shouldHandPreviewPanToSheet(notification.metrics.pixels, delta)) {
        setState(() => _drag = (_drag + delta).clamp(0, 240));
        return true;
      }
      if (_drag > 0 && delta < 0) {
        setState(() => _drag = (_drag + delta).clamp(0, 240));
        return true;
      }
    }
    if (notification is ScrollEndNotification) {
      if (_drag > 80) {
        Navigator.of(context).maybePop();
      } else if (_drag > 0) {
        setState(() => _drag = 0);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final tokens = context.oc;
    final filename = fileNameFromPath(widget.path);
    final sheet = _sheet(context, tokens, filename, viewPadding);

    if (_fullscreen) {
      return Material(
        key: const Key('html-preview-fullscreen-surface'),
        color: tokens.pageBackground,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _FullscreenHeader(
                title: filename,
                mode: _mode,
                onBack: _exitFullscreen,
                onToggleMode: _toggleMode,
              ),
              Expanded(child: _body(tokens)),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: SizedBox(
          key: const Key('html-preview-sheet'),
          width: size.width,
          height: size.height * 0.92,
          child: Material(
            color: tokens.pageBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: sheet,
          ),
        ),
      ),
    );
  }

  Widget _sheet(BuildContext context, OcTokens tokens, String filename, EdgeInsets viewPadding) {
    return Column(
      children: [
        _SheetHeader(
          title: filename,
          mode: _mode,
          onToggleMode: _toggleMode,
          onFullscreen: _enterFullscreen,
          onClose: () => Navigator.of(context).maybePop(),
        ),
        Expanded(child: _body(tokens)),
        SizedBox(height: 0, key: const Key('html-preview-physical-bottom')),
      ],
    );
  }

  Widget _body(OcTokens tokens) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final content = _content ?? '';
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: _mode == HtmlViewMode.source
          ? _SourceView(content: content, controller: _scroll)
          : _PreviewView(content: content, controller: _scroll),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.mode,
    required this.onToggleMode,
    required this.onFullscreen,
    required this.onClose,
  });

  final String title;
  final HtmlViewMode mode;
  final VoidCallback onToggleMode;
  final VoidCallback onFullscreen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: OcTokens.textUiHeader, fontWeight: FontWeight.w600, color: tokens.foreground),
              ),
            ),
            _IconAction(
              key: const Key('html-preview-source'),
              label: t(context, mode == HtmlViewMode.preview ? 'mobile.files.html.viewSourceAria' : 'mobile.files.html.viewPreviewAria'),
              glyph: mode == HtmlViewMode.preview ? OcGlyphKind.code : OcGlyphKind.file,
              onPressed: onToggleMode,
            ),
            _IconAction(
              key: const Key('html-preview-fullscreen'),
              label: t(context, 'mobile.files.html.fullscreenAria'),
              glyph: OcGlyphKind.layers,
              onPressed: onFullscreen,
            ),
            _IconAction(
              key: const Key('html-preview-close'),
              label: t(context, 'mobile.surface.closeAria'),
              glyph: OcGlyphKind.xmark,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenHeader extends StatelessWidget {
  const _FullscreenHeader({
    required this.title,
    required this.mode,
    required this.onBack,
    required this.onToggleMode,
  });

  final String title;
  final HtmlViewMode mode;
  final VoidCallback onBack;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _IconAction(
              key: const Key('html-preview-exit-fullscreen'),
              label: t(context, 'mobile.files.html.exitFullscreenAria'),
              glyph: OcGlyphKind.chevronBack,
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: OcTokens.textUiHeader, fontWeight: FontWeight.w600, color: tokens.foreground),
              ),
            ),
            _IconAction(
              key: const Key('html-preview-source'),
              label: t(context, mode == HtmlViewMode.preview ? 'mobile.files.html.viewSourceAria' : 'mobile.files.html.viewPreviewAria'),
              glyph: mode == HtmlViewMode.preview ? OcGlyphKind.code : OcGlyphKind.file,
              onPressed: onToggleMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    super.key,
    required this.label,
    required this.glyph,
    required this.onPressed,
  });

  final String label;
  final OcGlyphKind glyph;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      haptic: HapticStrength.light,
      onPressed: onPressed,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: OcGlyph(glyph, size: 16, strokeWidth: OcOptical.detailNavGlyphStroke, color: context.oc.foreground),
          ),
        ),
      ),
    );
  }
}

class _SourceView extends StatelessWidget {
  const _SourceView({required this.content, required this.controller});

  final String content;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('html-preview-source-body'),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        SelectableText(
          content,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: OcTokens.textCode,
            height: 1.35,
            color: context.oc.foreground,
          ),
        ),
      ],
    );
  }
}

class _PreviewView extends StatelessWidget {
  const _PreviewView({required this.content, required this.controller});

  final String content;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    // WidgetTester / Linux CI cannot host WKWebView. Device residual:
    // scripted HTML still needs the iOS/Android platform view.
    final inTest = Platform.environment['FLUTTER_TEST'] == 'true' ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    return ListView(
      key: const Key('html-preview-frame'),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      children: [
        Text(
          inTest || kDebugMode ? content : content,
          style: TextStyle(fontSize: OcTokens.textMarkdown, height: 1.4, color: context.oc.foreground),
        ),
      ],
    );
  }
}
