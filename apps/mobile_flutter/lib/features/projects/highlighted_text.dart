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
      return Text(text, style: style, strutStyle: _cssLineBox(style));
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
    return Text.rich(
      TextSpan(style: style, children: spans),
      strutStyle: _cssLineBox(style),
    );
  }
}

/// Official CSS `line-height` boxes (title 16, subtitle/time 12).
StrutStyle? _cssLineBox(TextStyle? style) {
  if (style?.fontSize == null || style?.height == null) return null;
  return StrutStyle(
    fontSize: style!.fontSize,
    height: style.height,
    leading: 0,
    forceStrutHeight: true,
  );
}
