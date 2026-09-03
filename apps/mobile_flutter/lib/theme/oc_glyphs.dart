import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'oc_official_sprites.dart';

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
  arrowUp,
  ellipsis,
  code,
  branch,
  file,
  sendSquare,
  sendPlane,
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
  robot,
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
    this.filled = false,
  });

  final OcGlyphKind kind;
  final double size;
  final Color? color;
  final double? strokeWidth;
  /// Dock [filled] paints official filled-mass bodies (folder-open-fill,
  /// sparkling star, calendar plate, holed gear). Not a stroke-width bump.
  final bool filled;

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
          strokeWidth: strokeWidth ?? 1.5,
          filled: filled,
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
    required this.filled,
  });

  final OcGlyphKind kind;
  final Color color;
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final official = officialSpriteFor(kind.name);
    if (kind == OcGlyphKind.folder && filled) {
      _folderFill(canvas, size, color);
      return;
    }
    // Official `Icon weight="medium"` is stroke 2. Filling the sparkles
    // star path is a heavy blob vs delicate medium.
    if (kind == OcGlyphKind.sparkles && filled && official != null) {
      paintOfficialSprite(
        canvas: canvas,
        size: size,
        sprite: official,
        color: color,
        strokeWidth: strokeWidth,
        filled: false,
      );
      return;
    }
    if (official != null) {
      paintOfficialSprite(
        canvas: canvas,
        size: size,
        sprite: official,
        color: color,
        strokeWidth: strokeWidth,
        filled: filled,
      );
      return;
    }
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
        // Remix `folder-open`: tabbed back + dropped front flap.
        final back = Path()
          ..moveTo(w * 0.10, h * 0.22)
          ..lineTo(w * 0.10, h * 0.78)
          ..lineTo(w * 0.38, h * 0.78)
          ..lineTo(w * 0.38, h * 0.40)
          ..lineTo(w * 0.70, h * 0.40)
          ..lineTo(w * 0.70, h * 0.32)
          ..lineTo(w * 0.46, h * 0.32)
          ..lineTo(w * 0.38, h * 0.22)
          ..close();
        final flap = Path()
          ..moveTo(w * 0.22, h * 0.56)
          ..lineTo(w * 0.92, h * 0.56)
          ..lineTo(w * 0.80, h * 0.86)
          ..lineTo(w * 0.10, h * 0.86)
          ..close();
        canvas.drawPath(back, filled ? fill : stroke);
        canvas.drawPath(flap, filled ? fill : stroke);
      case OcGlyphKind.sparkles:
        // Remix `sparkling`: one 4-point star + small plus + small circle.
        if (filled) {
          _fourPointStar(canvas, Offset(w * 0.46, h * 0.46), w * 0.36, fill);
          canvas.drawCircle(Offset(w * 0.18, h * 0.84), w * 0.07, fill);
          canvas.drawLine(Offset(w * 0.82, h * 0.08), Offset(w * 0.82, h * 0.30), stroke);
          canvas.drawLine(Offset(w * 0.71, h * 0.19), Offset(w * 0.93, h * 0.19), stroke);
        } else {
          _fourPointStar(canvas, Offset(w * 0.46, h * 0.46), w * 0.34, stroke);
          _sparkle(canvas, Offset(w * 0.80, h * 0.18), w * 0.10, stroke);
          canvas.drawCircle(Offset(w * 0.18, h * 0.82), w * 0.07, fill);
        }
      case OcGlyphKind.calendar:
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.12, h * 0.20, w * 0.76, h * 0.68),
          Radius.circular(w * 0.10),
        );
        canvas.drawRRect(body, filled ? fill : stroke);
        canvas.drawLine(Offset(w * 0.30, h * 0.10), Offset(w * 0.30, h * 0.30), stroke);
        canvas.drawLine(Offset(w * 0.70, h * 0.10), Offset(w * 0.70, h * 0.30), stroke);
        if (filled) {
          final hole = Paint()
            ..blendMode = BlendMode.dstOut
            ..style = PaintingStyle.fill;
          canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
          canvas.drawRRect(body, fill);
          for (final x in [0.30, 0.50, 0.70]) {
            for (final y in [0.52, 0.68]) {
              canvas.drawCircle(Offset(w * x, h * y), w * 0.045, hole);
            }
          }
          canvas.restore();
        } else {
          canvas.drawLine(Offset(w * 0.12, h * 0.40), Offset(w * 0.88, h * 0.40), stroke);
          for (final x in [0.32, 0.50, 0.68]) {
            for (final y in [0.54, 0.70]) {
              canvas.drawCircle(Offset(w * x, h * y), w * 0.04, fill);
            }
          }
        }
      case OcGlyphKind.gear:
        _gear(canvas, size, filled ? fill : stroke, filled);
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
      case OcGlyphKind.arrowUp:
        canvas.drawLine(Offset(w * 0.22, h * 0.50), Offset(w * 0.50, h * 0.22), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.22), Offset(w * 0.78, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.22), Offset(w * 0.50, h * 0.78), stroke);
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
        canvas.drawCircle(Offset(w * 0.20, h * 0.5), w * 0.10, fill);
        canvas.drawCircle(Offset(w * 0.50, h * 0.5), w * 0.10, fill);
        canvas.drawCircle(Offset(w * 0.80, h * 0.5), w * 0.10, fill);
      case OcGlyphKind.code:
        canvas.drawLine(Offset(w * 0.38, h * 0.22), Offset(w * 0.18, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.18, h * 0.50), Offset(w * 0.38, h * 0.78), stroke);
        canvas.drawLine(Offset(w * 0.62, h * 0.22), Offset(w * 0.82, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.82, h * 0.50), Offset(w * 0.62, h * 0.78), stroke);
      case OcGlyphKind.branch:
        canvas.drawCircle(Offset(w * 0.75, h * 0.25), w * 0.108, stroke);
        canvas.drawCircle(Offset(w * 0.25, h * 0.75), w * 0.108, stroke);
        canvas.drawLine(Offset(w * 0.25, h * 0.64), Offset(w * 0.25, h * 0.125), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.75, h * 0.36)
            ..cubicTo(w * 0.75, h * 0.55, w * 0.55, h * 0.68, w * 0.25, h * 0.72),
          stroke,
        );
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
        canvas.drawPath(bolt, stroke);
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
      case OcGlyphKind.sendPlane:
        // Official sprite paints first; fallback is a thin paper-plane outline.
        canvas.drawLine(Offset(w * 0.18, h * 0.22), Offset(w * 0.86, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.86, h * 0.50), Offset(w * 0.18, h * 0.78), stroke);
        canvas.drawLine(Offset(w * 0.18, h * 0.22), Offset(w * 0.38, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.18, h * 0.78), Offset(w * 0.38, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.38, h * 0.50), Offset(w * 0.86, h * 0.50), stroke);
      case OcGlyphKind.robot:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.18, h * 0.32, w * 0.64, h * 0.50),
            Radius.circular(w * 0.10),
          ),
          stroke,
        );
        canvas.drawLine(Offset(w * 0.50, h * 0.14), Offset(w * 0.50, h * 0.32), stroke);
        canvas.drawCircle(Offset(w * 0.50, h * 0.12), w * 0.05, fill);
        canvas.drawCircle(Offset(w * 0.36, h * 0.52), w * 0.06, fill);
        canvas.drawCircle(Offset(w * 0.64, h * 0.52), w * 0.06, fill);
        canvas.drawLine(Offset(w * 0.36, h * 0.68), Offset(w * 0.64, h * 0.68), stroke);
    }
  }

  void _sparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), paint);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), paint);
    final diag = radius * 0.55;
    canvas.drawLine(Offset(center.dx - diag, center.dy - diag), Offset(center.dx + diag, center.dy + diag), paint);
    canvas.drawLine(Offset(center.dx + diag, center.dy - diag), Offset(center.dx - diag, center.dy + diag), paint);
  }

  void _fourPointStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final star = Path();
    for (var i = 0; i < 8; i += 1) {
      final a = (i / 8) * math.pi * 2 - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.36;
      final point = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, paint);
  }

  void _folderFill(Canvas canvas, Size size, Color color) {
    // Official `folder-open` is a stroke silhouette — filling that path
    // does not enclose a body. Delicate filled-medium at 23px: a compact
    // tab + body with a punched well (~medium 2px walls), not a brick.
    final w = size.width;
    final h = size.height;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final tab = Path()
      ..moveTo(w * 0.34, h * 0.39)
      ..lineTo(w * 0.34, h * 0.46)
      ..lineTo(w * 0.43, h * 0.46)
      ..lineTo(w * 0.41, h * 0.39)
      ..close();
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, h * 0.45, w * 0.32, h * 0.16),
      Radius.circular(w * 0.028),
    );
    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
    canvas.drawPath(tab, fill);
    canvas.drawRRect(body, fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.39, h * 0.50, w * 0.22, h * 0.07),
        Radius.circular(w * 0.018),
      ),
      Paint()
        ..blendMode = BlendMode.dstOut
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }

  void _gear(Canvas canvas, Size size, Paint paint, bool filled) {
    // Narrow 8-tooth holed cog. Not settings-3 flower lobes and not
    // a six-cog sun on the 23px dock slot.
    final w = size.width;
    final h = size.height;
    final c = Offset(w * 0.5, h * 0.5);
    final rim = w * 0.28;
    final hole = w * 0.14;
    final tooth = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -(rim + w * 0.018)),
        width: w * 0.12,
        height: w * 0.08,
      ),
      Radius.circular(w * 0.02),
    );
    final stroke = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = paint.strokeWidth > 0 ? paint.strokeWidth : 1.55
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    void teeth(Paint p) {
      for (var i = 0; i < 8; i += 1) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(i * math.pi / 4);
        canvas.drawRRect(tooth, p);
        canvas.restore();
      }
    }

    if (filled) {
      canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
      canvas.drawCircle(c, rim, fill);
      teeth(fill);
      canvas.drawCircle(
        c,
        hole,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
      return;
    }
    canvas.drawCircle(c, rim, stroke);
    canvas.drawCircle(c, hole, stroke);
    teeth(stroke);
  }

  @override
  bool shouldRepaint(covariant _OcGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.filled != filled;
  }
}
