import 'package:flutter/material.dart';

import '../../theme/ios_chrome.dart';
import '../../theme/oc_tokens.dart';

/// Minimal inline markdown: backtick spans render as official code chips.
///
/// Source: `.markdown-content code[data-markdown="inline-code"]` +
/// `--markdown-inline-code` / `--markdown-inline-code-bg`.
class InlineMarkdownText extends StatelessWidget {
  const InlineMarkdownText({
    super.key,
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  static final RegExp _inlineCode = RegExp(r'`([^`]+)`');

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final codeStyle = base.copyWith(
      fontFamily: 'monospace',
      fontSize: OcTokens.textCode,
      height: 1.35,
      letterSpacing: 0,
      color: base.color ?? context.oc.foreground,
      backgroundColor: context.oc.surfaceSubtle,
    );
    return Text.rich(
      TextSpan(
        children: _spans(text, base, codeStyle),
        style: base,
      ),
    );
  }

  List<InlineSpan> _spans(String source, TextStyle base, TextStyle codeStyle) {
    final out = <InlineSpan>[];
    var start = 0;
    for (final match in _inlineCode.allMatches(source)) {
      if (match.start > start) {
        out.add(TextSpan(text: source.substring(start, match.start)));
      }
      final code = match.group(1) ?? '';
      out.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: codeStyle.backgroundColor,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(code, style: codeStyle.copyWith(backgroundColor: Colors.transparent)),
              ),
            ),
          ),
        ),
      );
      start = match.end;
    }
    if (start < source.length) {
      out.add(TextSpan(text: source.substring(start)));
    }
    return out.isEmpty ? [TextSpan(text: source)] : out;
  }
}
