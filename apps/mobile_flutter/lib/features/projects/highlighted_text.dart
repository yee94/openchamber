import 'package:flutter/material.dart';

import '../../theme/ios_hero.dart';

/// 1.19.3-beta.1 keyword highlight for home session search.
class HighlightedText extends StatelessWidget {
  const HighlightedText(this.text, {super.key, required this.query, this.style});

  final String text;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final needle = query.trim();
    final paint = ocCssInk(style);
    if (needle.isEmpty) {
      return Text(text, style: paint, strutStyle: ocCssLineBox(style));
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
      TextSpan(style: paint, children: spans),
      strutStyle: ocCssLineBox(style),
    );
  }
}

/// CSS `font-size` is ink. Official `line-height` is the strut — do not
/// also multiply Flutter `TextStyle.height` or CJK packs the 40px box.
TextStyle? ocCssInk(TextStyle? style) {
  if (style == null) return null;
  return style.copyWith(
    height: 1.0,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// Official CSS `line-height` boxes (session title 16, subtitle/time 12).
/// Move [OcOptical.sessionLineLeading] of that box into strut leading so
/// CJK ink sits with official single-line air. Total height is unchanged.
StrutStyle? ocCssLineBox(TextStyle? style) {
  if (style?.fontSize == null || style?.height == null) return null;
  final box = style!.height!;
  const lead = OcOptical.sessionLineLeading;
  // Keep height + leading == the CSS box. Flooring at 1.0 ate the
  // subtitle's air and grew the 12px strut past official.
  return StrutStyle(
    fontSize: style.fontSize,
    height: (box - lead).clamp(0.5, box),
    leading: lead,
    forceStrutHeight: true,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
