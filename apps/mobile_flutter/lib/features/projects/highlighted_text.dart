import 'package:flutter/material.dart';

import '../../theme/ios_chrome.dart';

/// 1.19.3-beta.1 keyword highlight for home session search.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    required this.query,
    this.style,
    this.halfLead,
  });

  final String text;
  final String query;
  final TextStyle? style;
  /// Session 16/12 rows keep the pinned 1.25 CJK half-lead. Project /
  /// schedule 14/18 titles pass 0 so the official CSS box is not inflated.
  final double? halfLead;

  @override
  Widget build(BuildContext context) {
    final needle = query.trim();
    // Ink is font-size; [OcCssLine] owns the official CSS line box +
    // pinned CJK half-lead. Multiplying Flutter `height` on the Text
    // packed Regular CJK inside the 16/12 and 18/14 boxes.
    final paint = ocCssInk((style ?? const TextStyle()).copyWith(
      color: style?.color ?? context.oc.foreground,
    ))!;
    if (needle.isEmpty) {
      return OcCssLine(
        style: style,
        halfLead: halfLead,
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
      halfLead: halfLead,
      child: Text.rich(
        TextSpan(style: paint, children: spans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
