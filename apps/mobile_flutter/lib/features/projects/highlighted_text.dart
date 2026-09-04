import 'package:flutter/material.dart';

import '../../theme/ios_chrome.dart';

/// 1.19.3-beta.1 keyword highlight for home session search.
class HighlightedText extends StatelessWidget {
  const HighlightedText(this.text, {super.key, required this.query, this.style});

  final String text;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final needle = query.trim();
    // Keep the CSS line-height box so CJK is not clipped to font-size.
    // Always paint full warm ink — never inherit a washed DefaultTextStyle.
    final paint = (style ?? const TextStyle()).copyWith(
      color: style?.color ?? context.oc.foreground,
      leadingDistribution: TextLeadingDistribution.even,
    );
    if (needle.isEmpty) {
      return OcCssLine(
        style: style,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: paint,
        ),
      );
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
    return OcCssLine(
      style: style,
      child: Text.rich(
        TextSpan(style: paint, children: spans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
