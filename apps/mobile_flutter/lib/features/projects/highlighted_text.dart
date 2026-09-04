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
  /// Session 16/12 rows keep [OcOptical.cssLineCjkHalfLead]. Project /
  /// schedule 14/18 titles use [OcOptical.cardTitleHalfLead] (not 0).
  final double? halfLead;
  /// Same-color miter stem under Regular CJK so 12px titles reach
  /// authored foreground without a round-join halo. ReviewCjk has no
  /// Medium cut; Latin uses ReviewSans Medium. 0 = off.
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
        child: _inkPlain(text, paint),
      );
    }
    final lower = text.toLowerCase();
    final match = needle.toLowerCase();
    final spans = <InlineSpan>[];
    var start = 0;
    while (true) {
      final index = lower.indexOf(match, start);
      if (index < 0) {
        spans.addAll(_scriptFillSpans(text.substring(start), paint));
        break;
      }
      if (index > start) {
        spans.addAll(_scriptFillSpans(text.substring(start, index), paint));
      }
      spans.addAll(
        _scriptFillSpans(
          text.substring(index, index + needle.length),
          paint.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
      start = index + needle.length;
    }
    return OcCssLine(
      style: style,
      halfLead: halfLead,
      child: _inkRich(spans, paint),
    );
  }

  Widget _inkPlain(String value, TextStyle paint) {
    return _inkRich(_scriptFillSpans(value, paint), paint);
  }

  Widget _inkRich(List<InlineSpan> fillSpans, TextStyle paint) {
    final fill = Text.rich(
      TextSpan(style: paint, children: fillSpans),
      style: paint,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final visible = textFromSpans(fillSpans);
    if (stem <= 0 || paint.color == null || !scriptRuns(visible).any((run) => run.cjk)) {
      return fill;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ExcludeSemantics(
          child: Text.rich(
            TextSpan(
              style: paint.copyWith(color: Colors.transparent),
              children: _scriptStemSpans(visible, paint),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        fill,
      ],
    );
  }

  /// Highlighted search rebuilds spans; stem layout must use the same
  /// visible string as the fill, not the raw [text] (query can split it).
  static String textFromSpans(List<InlineSpan> spans) {
    final buf = StringBuffer();
    for (final span in spans) {
      if (span is TextSpan && span.text != null) buf.write(span.text);
    }
    return buf.toString();
  }

  List<InlineSpan> _scriptFillSpans(String value, TextStyle paint) {
    if (value.isEmpty) return const [];
    return [
      for (final run in scriptRuns(value))
        TextSpan(
          text: run.text,
          style: run.cjk ? _shaded(paint) : paint,
        ),
    ];
  }

  List<InlineSpan> _scriptStemSpans(String value, TextStyle paint) {
    if (value.isEmpty || paint.color == null) return const [];
    final stroke = Paint()
      ..color = paint.color!
      ..style = PaintingStyle.stroke
      ..strokeWidth = stem
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;
    return [
      for (final run in scriptRuns(value))
        TextSpan(
          text: run.text,
          style: run.cjk
              ? paint.copyWith(color: null, foreground: stroke)
              : const TextStyle(color: Colors.transparent),
        ),
    ];
  }

  TextStyle _shaded(TextStyle paint) {
    if (stem <= 0 || paint.color == null) return paint;
    const d = OcOptical.sessionTitleShade;
    if (d <= 0) return paint;
    final ink = paint.color!;
    return paint.copyWith(
      shadows: [
        Shadow(color: ink, offset: const Offset(-d, 0), blurRadius: 0),
        Shadow(color: ink, offset: const Offset(d, 0), blurRadius: 0),
        Shadow(color: ink, offset: const Offset(0, -d), blurRadius: 0),
        Shadow(color: ink, offset: const Offset(0, d), blurRadius: 0),
      ],
    );
  }
}

/// CJK / kana / hangul vs Latin-digit runs. Stem/shade stay on CJK —
/// Latin already has ReviewSans Medium (`font-medium`).
@visibleForTesting
List<({String text, bool cjk})> scriptRuns(String value) {
  if (value.isEmpty) return const [];
  final runs = <({String text, bool cjk})>[];
  final buf = StringBuffer();
  bool? cjk;
  for (final rune in value.runes) {
    final next = _looksCjk(rune);
    if (cjk != null && next != cjk) {
      runs.add((text: buf.toString(), cjk: cjk));
      buf.clear();
    }
    cjk = next;
    buf.writeCharCode(rune);
  }
  runs.add((text: buf.toString(), cjk: cjk ?? false));
  return runs;
}

bool _looksCjk(int rune) {
  return (rune >= 0x2E80 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0xFE30 && rune <= 0xFE4F) ||
      (rune >= 0x3040 && rune <= 0x30FF) ||
      (rune >= 0xAC00 && rune <= 0xD7AF);
}
