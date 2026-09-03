import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vector chrome glyphs. WidgetTester cannot be trusted to load
/// CupertinoIcons.ttf / MaterialIcons, so homepage / composer / dock
/// icons are painted paths — the same shapes on device and in goldens.
enum OcGlyphKind {
  search,
  plus,
  folder,
  sparkles,
  calendar,
  gear,
  check,
  pause,
  chevronDown,
  chevronRight,
  chevronBack,
  ellipsis,
  code,
  branch,
  file,
  sendSquare,
  xmark,
  clock,
  mic,
  qr,
  copy,
  share,
  thumbUp,
  thumbDown,
  speaker,
  people,
  bolt,
  hourglass,
  layers,
  undo,
  edit,
  link,
}

class OcGlyph extends StatelessWidget {
  const OcGlyph(
    this.kind, {
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth,
  });

  final OcGlyphKind kind;
  final double size;
  final Color? color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OcGlyphPainter(
          kind: kind,
          color: resolved,
          strokeWidth: strokeWidth ?? (size < 16 ? 1.4 : 1.8),
        ),
      ),
    );
  }
}

class _OcGlyphPainter extends CustomPainter {
  const _OcGlyphPainter({
    required this.kind,
    required this.color,
    required this.strokeWidth,
  });

  final OcGlyphKind kind;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    switch (kind) {
      case OcGlyphKind.search:
        canvas.drawCircle(Offset(w * 0.42, h * 0.42), w * 0.28, stroke);
        canvas.drawLine(Offset(w * 0.62, h * 0.62), Offset(w * 0.86, h * 0.86), stroke);
      case OcGlyphKind.plus:
        canvas.drawLine(Offset(w * 0.5, h * 0.18), Offset(w * 0.5, h * 0.82), stroke);
        canvas.drawLine(Offset(w * 0.18, h * 0.5), Offset(w * 0.82, h * 0.5), stroke);
      case OcGlyphKind.xmark:
        canvas.drawLine(Offset(w * 0.26, h * 0.26), Offset(w * 0.74, h * 0.74), stroke);
        canvas.drawLine(Offset(w * 0.74, h * 0.26), Offset(w * 0.26, h * 0.74), stroke);
      case OcGlyphKind.folder:
        final folder = Path()
          ..moveTo(w * 0.12, h * 0.38)
          ..lineTo(w * 0.12, h * 0.82)
          ..lineTo(w * 0.88, h * 0.82)
          ..lineTo(w * 0.88, h * 0.42)
          ..lineTo(w * 0.52, h * 0.42)
          ..lineTo(w * 0.42, h * 0.28)
          ..lineTo(w * 0.12, h * 0.28)
          ..close();
        canvas.drawPath(folder, stroke);
      case OcGlyphKind.sparkles:
        _star(canvas, Offset(w * 0.38, h * 0.42), w * 0.28, fill);
        _star(canvas, Offset(w * 0.72, h * 0.28), w * 0.14, fill);
        _star(canvas, Offset(w * 0.70, h * 0.70), w * 0.12, fill);
      case OcGlyphKind.calendar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.14, h * 0.22, w * 0.72, h * 0.64),
            Radius.circular(w * 0.08),
          ),
          stroke,
        );
        canvas.drawLine(Offset(w * 0.14, h * 0.40), Offset(w * 0.86, h * 0.40), stroke);
        canvas.drawLine(Offset(w * 0.32, h * 0.12), Offset(w * 0.32, h * 0.30), stroke);
        canvas.drawLine(Offset(w * 0.68, h * 0.12), Offset(w * 0.68, h * 0.30), stroke);
      case OcGlyphKind.gear:
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.16, stroke);
        for (var i = 0; i < 8; i += 1) {
          final a = (i / 8) * math.pi * 2;
          final inner = Offset(w * 0.5 + math.cos(a) * w * 0.26, h * 0.5 + math.sin(a) * h * 0.26);
          final outer = Offset(w * 0.5 + math.cos(a) * w * 0.40, h * 0.5 + math.sin(a) * h * 0.40);
          canvas.drawLine(inner, outer, stroke);
        }
      case OcGlyphKind.check:
        final check = Path()
          ..moveTo(w * 0.20, h * 0.52)
          ..lineTo(w * 0.42, h * 0.72)
          ..lineTo(w * 0.80, h * 0.28);
        canvas.drawPath(check, stroke);
      case OcGlyphKind.pause:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.28, h * 0.22, w * 0.16, h * 0.56),
            Radius.circular(w * 0.04),
          ),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.56, h * 0.22, w * 0.16, h * 0.56),
            Radius.circular(w * 0.04),
          ),
          fill,
        );
      case OcGlyphKind.chevronDown:
        canvas.drawLine(Offset(w * 0.22, h * 0.38), Offset(w * 0.50, h * 0.64), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.64), Offset(w * 0.78, h * 0.38), stroke);
      case OcGlyphKind.chevronRight:
        canvas.drawLine(Offset(w * 0.38, h * 0.22), Offset(w * 0.64, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.64, h * 0.50), Offset(w * 0.38, h * 0.78), stroke);
      case OcGlyphKind.chevronBack:
        canvas.drawLine(Offset(w * 0.62, h * 0.22), Offset(w * 0.36, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.36, h * 0.50), Offset(w * 0.62, h * 0.78), stroke);
      case OcGlyphKind.ellipsis:
        canvas.drawCircle(Offset(w * 0.22, h * 0.5), w * 0.08, fill);
        canvas.drawCircle(Offset(w * 0.50, h * 0.5), w * 0.08, fill);
        canvas.drawCircle(Offset(w * 0.78, h * 0.5), w * 0.08, fill);
      case OcGlyphKind.code:
        canvas.drawLine(Offset(w * 0.38, h * 0.22), Offset(w * 0.18, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.18, h * 0.50), Offset(w * 0.38, h * 0.78), stroke);
        canvas.drawLine(Offset(w * 0.62, h * 0.22), Offset(w * 0.82, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.82, h * 0.50), Offset(w * 0.62, h * 0.78), stroke);
      case OcGlyphKind.branch:
        canvas.drawCircle(Offset(w * 0.32, h * 0.24), w * 0.10, fill);
        canvas.drawCircle(Offset(w * 0.32, h * 0.76), w * 0.10, fill);
        canvas.drawCircle(Offset(w * 0.72, h * 0.50), w * 0.10, fill);
        canvas.drawLine(Offset(w * 0.32, h * 0.34), Offset(w * 0.32, h * 0.66), stroke);
        canvas.drawLine(Offset(w * 0.32, h * 0.42), Offset(w * 0.62, h * 0.50), stroke);
      case OcGlyphKind.file:
        final file = Path()
          ..moveTo(w * 0.30, h * 0.14)
          ..lineTo(w * 0.62, h * 0.14)
          ..lineTo(w * 0.78, h * 0.32)
          ..lineTo(w * 0.78, h * 0.86)
          ..lineTo(w * 0.22, h * 0.86)
          ..lineTo(w * 0.22, h * 0.14)
          ..close();
        canvas.drawPath(file, stroke);
        canvas.drawLine(Offset(w * 0.62, h * 0.14), Offset(w * 0.62, h * 0.34), stroke);
        canvas.drawLine(Offset(w * 0.62, h * 0.34), Offset(w * 0.78, h * 0.34), stroke);
      case OcGlyphKind.qr:
        canvas.drawRect(Rect.fromLTWH(w * 0.16, h * 0.16, w * 0.22, h * 0.22), stroke);
        canvas.drawRect(Rect.fromLTWH(w * 0.62, h * 0.16, w * 0.22, h * 0.22), stroke);
        canvas.drawRect(Rect.fromLTWH(w * 0.16, h * 0.62, w * 0.22, h * 0.22), stroke);
        canvas.drawRect(Rect.fromLTWH(w * 0.58, h * 0.58, w * 0.12, h * 0.12), fill);
        canvas.drawRect(Rect.fromLTWH(w * 0.74, h * 0.70, w * 0.10, h * 0.10), fill);
      case OcGlyphKind.mic:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.36, h * 0.14, w * 0.28, h * 0.42),
            Radius.circular(w * 0.14),
          ),
          stroke,
        );
        canvas.drawArc(Rect.fromLTWH(w * 0.22, h * 0.34, w * 0.56, h * 0.40), 0, 3.14, false, stroke);
        canvas.drawLine(Offset(w * 0.5, h * 0.74), Offset(w * 0.5, h * 0.86), stroke);
        canvas.drawLine(Offset(w * 0.34, h * 0.86), Offset(w * 0.66, h * 0.86), stroke);
      case OcGlyphKind.clock:
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.34, stroke);
        canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.5, h * 0.32), stroke);
        canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.68, h * 0.58), stroke);
      case OcGlyphKind.sendSquare:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.28, h * 0.28, w * 0.44, h * 0.44),
            Radius.circular(w * 0.06),
          ),
          fill,
        );
      case OcGlyphKind.copy:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.28, h * 0.28, w * 0.50, h * 0.54), Radius.circular(w * 0.08)),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.16, w * 0.50, h * 0.54), Radius.circular(w * 0.08)),
          stroke,
        );
      case OcGlyphKind.share:
        canvas.drawLine(Offset(w * 0.50, h * 0.16), Offset(w * 0.50, h * 0.58), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.16), Offset(w * 0.34, h * 0.32), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.16), Offset(w * 0.66, h * 0.32), stroke);
        canvas.drawArc(Rect.fromLTWH(w * 0.18, h * 0.40, w * 0.64, h * 0.46), 0.15, 2.84, false, stroke);
      case OcGlyphKind.thumbUp:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.42, w * 0.18, h * 0.40), Radius.circular(w * 0.04)),
          stroke,
        );
        final up = Path()
          ..moveTo(w * 0.36, h * 0.78)
          ..lineTo(w * 0.78, h * 0.78)
          ..lineTo(w * 0.74, h * 0.46)
          ..lineTo(w * 0.56, h * 0.46)
          ..lineTo(w * 0.58, h * 0.22)
          ..lineTo(w * 0.42, h * 0.42)
          ..lineTo(w * 0.36, h * 0.42)
          ..close();
        canvas.drawPath(up, stroke);
      case OcGlyphKind.thumbDown:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.18, w * 0.18, h * 0.40), Radius.circular(w * 0.04)),
          stroke,
        );
        final down = Path()
          ..moveTo(w * 0.36, h * 0.22)
          ..lineTo(w * 0.78, h * 0.22)
          ..lineTo(w * 0.74, h * 0.54)
          ..lineTo(w * 0.56, h * 0.54)
          ..lineTo(w * 0.58, h * 0.78)
          ..lineTo(w * 0.42, h * 0.58)
          ..lineTo(w * 0.36, h * 0.58)
          ..close();
        canvas.drawPath(down, stroke);
      case OcGlyphKind.speaker:
        final cone = Path()
          ..moveTo(w * 0.22, h * 0.40)
          ..lineTo(w * 0.40, h * 0.40)
          ..lineTo(w * 0.58, h * 0.24)
          ..lineTo(w * 0.58, h * 0.76)
          ..lineTo(w * 0.40, h * 0.60)
          ..lineTo(w * 0.22, h * 0.60)
          ..close();
        canvas.drawPath(cone, stroke);
        canvas.drawArc(Rect.fromLTWH(w * 0.52, h * 0.30, w * 0.30, h * 0.40), -0.7, 1.4, false, stroke);
      case OcGlyphKind.people:
        canvas.drawCircle(Offset(w * 0.36, h * 0.32), w * 0.14, stroke);
        canvas.drawArc(Rect.fromLTWH(w * 0.12, h * 0.50, w * 0.48, h * 0.40), 3.3, 2.8, false, stroke);
        canvas.drawCircle(Offset(w * 0.68, h * 0.34), w * 0.12, stroke);
        canvas.drawArc(Rect.fromLTWH(w * 0.48, h * 0.52, w * 0.40, h * 0.34), 3.4, 2.6, false, stroke);
      case OcGlyphKind.bolt:
        final bolt = Path()
          ..moveTo(w * 0.58, h * 0.12)
          ..lineTo(w * 0.30, h * 0.52)
          ..lineTo(w * 0.50, h * 0.52)
          ..lineTo(w * 0.42, h * 0.88)
          ..lineTo(w * 0.72, h * 0.44)
          ..lineTo(w * 0.52, h * 0.44)
          ..close();
        canvas.drawPath(bolt, fill);
      case OcGlyphKind.hourglass:
        canvas.drawLine(Offset(w * 0.28, h * 0.18), Offset(w * 0.72, h * 0.18), stroke);
        canvas.drawLine(Offset(w * 0.28, h * 0.82), Offset(w * 0.72, h * 0.82), stroke);
        final glass = Path()
          ..moveTo(w * 0.30, h * 0.20)
          ..lineTo(w * 0.70, h * 0.20)
          ..lineTo(w * 0.50, h * 0.50)
          ..lineTo(w * 0.70, h * 0.80)
          ..lineTo(w * 0.30, h * 0.80)
          ..lineTo(w * 0.50, h * 0.50)
          ..close();
        canvas.drawPath(glass, stroke);
      case OcGlyphKind.layers:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, h * 0.22, w * 0.56, h * 0.22), Radius.circular(w * 0.06)),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, h * 0.40, w * 0.56, h * 0.22), Radius.circular(w * 0.06)),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, h * 0.58, w * 0.56, h * 0.22), Radius.circular(w * 0.06)),
          stroke,
        );
      case OcGlyphKind.undo:
        canvas.drawArc(Rect.fromLTWH(w * 0.22, h * 0.28, w * 0.56, h * 0.48), 0.2, 4.2, false, stroke);
        canvas.drawLine(Offset(w * 0.22, h * 0.28), Offset(w * 0.22, h * 0.48), stroke);
        canvas.drawLine(Offset(w * 0.22, h * 0.28), Offset(w * 0.40, h * 0.30), stroke);
      case OcGlyphKind.edit:
        canvas.drawLine(Offset(w * 0.22, h * 0.78), Offset(w * 0.78, h * 0.78), stroke);
        final pencil = Path()
          ..moveTo(w * 0.70, h * 0.22)
          ..lineTo(w * 0.78, h * 0.30)
          ..lineTo(w * 0.38, h * 0.70)
          ..lineTo(w * 0.26, h * 0.72)
          ..lineTo(w * 0.28, h * 0.60)
          ..close();
        canvas.drawPath(pencil, stroke);
      case OcGlyphKind.link:
        canvas.drawArc(Rect.fromLTWH(w * 0.12, h * 0.30, w * 0.40, h * 0.40), 1.2, 4.0, false, stroke);
        canvas.drawArc(Rect.fromLTWH(w * 0.48, h * 0.30, w * 0.40, h * 0.40), 4.3, 4.0, false, stroke);
        canvas.drawLine(Offset(w * 0.38, h * 0.50), Offset(w * 0.62, h * 0.50), stroke);
    }
  }

  void _star(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i += 1) {
      final a = (i / 8) * math.pi * 2 - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.38;
      final point = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OcGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
