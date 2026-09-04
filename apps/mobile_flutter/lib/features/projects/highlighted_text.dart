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
    this.stem = 0,
  });

  final String text;
  final String query;
  final TextStyle? style;
  /// Session 16/12 rows keep the pinned 1.25 CJK half-lead. Project /
  /// schedule 14/18 titles pass 0 so the official CSS box is not inflated.
  final double? halfLead;
  /// Same-color hairline under Regular CJK so 12px stems reach
  /// authored foreground. ReviewCjk has no Medium cut; 0 = off.
  final double stem;

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
        child: _inkText(text, paint),
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
      child: _inkRich(TextSpan(style: paint, children: spans), paint),
    );
  }

  Widget _inkText(String value, TextStyle paint) {
    final fill = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: paint,
    );
    if (stem <= 0 || paint.color == null) return fill;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ExcludeSemantics(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: paint.copyWith(
              color: null,
              foreground: Paint()
                ..color = paint.color!
                ..style = PaintingStyle.stroke
                ..strokeWidth = stem
                ..strokeJoin = StrokeJoin.round,
            ),
          ),
        ),
        fill,
      ],
    );
  }

  Widget _inkRich(InlineSpan span, TextStyle paint) {
    final fill = Text.rich(
      span,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (stem <= 0 || paint.color == null) return fill;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ExcludeSemantics(
          child: Text.rich(
            span,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: paint.copyWith(
              color: null,
              foreground: Paint()
                ..color = paint.color!
                ..style = PaintingStyle.stroke
                ..strokeWidth = stem
                ..strokeJoin = StrokeJoin.round,
            ),
          ),
        ),
        fill,
      ],
    );
  }
}
