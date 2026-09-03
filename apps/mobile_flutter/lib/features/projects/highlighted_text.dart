import 'package:flutter/material.dart';

/// 1.19.3-beta.1 keyword highlight for home session search.
class HighlightedText extends StatelessWidget {
  const HighlightedText(this.text, {super.key, required this.query, this.style});

  final String text;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final needle = query.trim();
    if (needle.isEmpty) {
      // Official `.oc-mobile-session-title` / subtitle keep CSS line-height
      // boxes (16px / 12px). Collapsing Flutter leading made rows denser.
      return Text(text, style: style);
    }
    final lower = text.toLowerCase();
    final match = needle.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lower.indexOf(match, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) spans.add(TextSpan(text: text.substring(start, index)));
      spans.add(
        TextSpan(
          text: text.substring(index, index + needle.length),
          style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
        ),
      );
      start = index + needle.length;
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
