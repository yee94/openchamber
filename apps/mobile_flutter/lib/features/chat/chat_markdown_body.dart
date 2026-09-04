import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../data/chat_markdown_cache.dart';
import '../../native/external_browser.dart';
import '../../theme/ios_chrome.dart';

/// Official mobile chat Markdown (`--text-markdown` / 15 / 1.45).
///
/// Uses `flutter_markdown_plus.MarkdownBody` (shrink-wrap, no nested
/// scrollable). Streaming updates are debounced at the official Markdown
/// pace (64ms) so a partial fence cannot thrash parse on every token.
class ChatMarkdownBody extends StatefulWidget {
  const ChatMarkdownBody({
    super.key,
    required this.text,
    this.cacheKey,
    this.isLive = false,
    this.browser,
  });

  final String text;
  final String? cacheKey;
  final bool isLive;
  final ExternalBrowser? browser;

  /// Official `streamingRenderCadence.markdownPaceMs` for iOS / web / desktop.
  static const Duration livePace = Duration(milliseconds: 64);

  @override
  State<ChatMarkdownBody> createState() => _ChatMarkdownBodyState();
}

class _ChatMarkdownBodyState extends State<ChatMarkdownBody> {
  late String _committed = widget.text;
  String? _builtIdentity;
  Widget? _builtBody;
  MarkdownStyleSheet? _styleSheet;
  Brightness? _styleBrightness;
  Timer? _pace;

  @override
  void didUpdateWidget(ChatMarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text && oldWidget.cacheKey == widget.cacheKey) {
      ChatMarkdownBuildCounters.reuseHits += 1;
      return;
    }
    if (!widget.isLive) {
      _pace?.cancel();
      _committed = widget.text;
      return;
    }
    _pace?.cancel();
    _pace = Timer(ChatMarkdownBody.livePace, () {
      if (!mounted) return;
      setState(() => _committed = widget.text);
    });
  }

  @override
  void dispose() {
    _pace?.cancel();
    super.dispose();
  }

  MarkdownStyleSheet _sheetFor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_styleSheet != null && _styleBrightness == brightness) {
      return _styleSheet!;
    }
    _styleBrightness = brightness;
    _styleSheet = ocMarkdownStyleSheet(context);
    return _styleSheet!;
  }

  @override
  Widget build(BuildContext context) {
    final source = _committed;
    if (source.trim().isEmpty) return const SizedBox.shrink();
    final identity = '${widget.cacheKey ?? ''}#${source.hashCode}:${Theme.of(context).brightness}';
    if (_builtIdentity == identity && _builtBody != null) {
      ChatMarkdownBuildCounters.reuseHits += 1;
      return _builtBody!;
    }
    ChatMarkdownBuildCounters.builds += 1;
    ChatMarkdownSourceCache.remember(identity);
    _builtIdentity = identity;
    _builtBody = MarkdownBody(
      key: Key('chat-markdown-${widget.cacheKey ?? 'anon'}'),
      data: source,
      shrinkWrap: true,
      fitContent: true,
      softLineBreak: true,
      selectable: false,
      styleSheet: _sheetFor(context),
      onTapLink: (text, href, title) {
        final url = href?.trim() ?? '';
        if (url.isEmpty) return;
        final opener = widget.browser ?? ExternalBrowser();
        unawaited(opener.open(url).catchError((Object _) {}));
      },
    );
    return _builtBody!;
  }
}

MarkdownStyleSheet ocMarkdownStyleSheet(BuildContext context) {
  final tokens = OcTokens.of(context);
  final base = TextStyle(
    fontSize: OcTokens.textMarkdown,
    height: OcOptical.chatBodyHeight,
    letterSpacing: OcOptical.chatBodyTracking,
    fontWeight: FontWeight.w400,
    color: tokens.foreground,
  );
  final heading = base.copyWith(fontWeight: FontWeight.w600);
  final mono = base.copyWith(
    fontFamily: 'monospace',
    fontSize: OcTokens.textCode,
    height: 1.35,
    letterSpacing: 0,
    backgroundColor: tokens.surfaceSubtle,
  );
  return MarkdownStyleSheet(
    p: base,
    pPadding: const EdgeInsets.only(bottom: 10),
    h1: heading,
    h2: heading,
    h3: heading,
    h4: heading,
    h5: heading,
    h6: heading,
    h1Padding: const EdgeInsets.only(top: 10, bottom: 4),
    h2Padding: const EdgeInsets.only(top: 8, bottom: 4),
    h3Padding: const EdgeInsets.only(top: 8, bottom: 4),
    em: base.copyWith(fontStyle: FontStyle.italic),
    strong: base.copyWith(fontWeight: FontWeight.w600),
    a: base.copyWith(
      color: tokens.primary,
      decoration: TextDecoration.underline,
      decorationColor: tokens.primary,
    ),
    code: mono.copyWith(color: tokens.foreground),
    blockquote: base.copyWith(color: tokens.mutedForeground),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: tokens.border, width: 3)),
    ),
    listIndent: 18,
    listBullet: base.copyWith(color: tokens.primary, fontSize: 11),
    blockSpacing: 10,
    codeblockPadding: const EdgeInsets.all(10),
    codeblockDecoration: BoxDecoration(
      color: tokens.surfaceSubtle,
      borderRadius: BorderRadius.circular(OcTokens.radius),
    ),
  );
}
