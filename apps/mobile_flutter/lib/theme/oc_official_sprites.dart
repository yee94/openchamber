import 'dart:ui';

/// Official `packages/ui/src/components/icon/sprite.ts` paths (24×24 viewBox).
/// Flutter paints these so glyph *shape* matches WebView `Icon`, while
/// [OcOptical] tokens own the on-screen size. Hit areas stay on the widget.
class OcOfficialSprite {
  const OcOfficialSprite({
    this.paths = const [],
    this.circles = const [],
    this.rects = const [],
  });

  final List<String> paths;
  final List<(double cx, double cy, double r)> circles;
  final List<(double x, double y, double w, double h, double rx)> rects;
}

/// Homepage / dock / header roles only — names from MobileProjectCard,
/// MobileWorktreeGroupLabel, MobileTabBar, MobileTabPageHeader.
OcOfficialSprite? officialSpriteFor(String kindName) {
  return switch (kindName) {
    'search' => const OcOfficialSprite(
        paths: ['m21 21-4.34-4.34'],
        circles: [(11, 11, 8)],
      ),
    'plus' => const OcOfficialSprite(paths: ['M5 12h14', 'M12 5v14']),
    'folder' => const OcOfficialSprite(
        paths: [
          'm6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2',
        ],
      ),
    'sparkles' => const OcOfficialSprite(
        paths: [
          'M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0-1.594 1.594l-1.051 5.558a1 1 0 0 1-1.966 0l-1.051-5.558a2 2 0 0 0-1.594-1.594l-5.558-1.051a1 1 0 0 1 0-1.966l5.558-1.051a2 2 0 0 0 1.594-1.594z',
          'M20 2v4',
          'M22 4h-4',
        ],
        circles: [(4, 20, 2)],
      ),
    // Official `calendar` sprite (grid + header). Not `calendar-schedule`
    // (clock overlay). Date dots are the calendar body cells.
    'calendar' => const OcOfficialSprite(
        paths: ['M8 2v4', 'M16 2v4', 'M3 10h18'],
        rects: [(3, 4, 18, 18, 2)],
        circles: [
          (8, 14, 0.55),
          (12, 14, 0.55),
          (16, 14, 0.55),
          (8, 18, 0.55),
          (12, 18, 0.55),
          (16, 18, 0.55),
        ],
      ),
    // `gear` is painted by OcGlyph `_gear` (narrow 8-tooth holed cog).
    // Official `settings-3` lobes bloom into a flower at 23px medium.
    'code' => const OcOfficialSprite(
        paths: ['m18 16 4-4-4-4', 'm6 8-4 4 4 4', 'm14.5 4-5 16'],
      ),
    'branch' => const OcOfficialSprite(
        paths: ['M6 15.4V3', 'M18 8.6c0 4.6-3.4 7.4-9.4 8'],
        circles: [(18, 6, 2.6), (6, 18, 2.6)],
      ),
    'ellipsis' => const OcOfficialSprite(
        circles: [(12, 12, 1), (19, 12, 1), (5, 12, 1)],
      ),
    'arrowUp' => const OcOfficialSprite(paths: ['m5 12 7-7 7 7', 'M12 19V5']),
    // Official idle composer `send-plane-2` (stroke-only inside the pill).
    'sendPlane' => const OcOfficialSprite(
        paths: [
          'M3.714 3.048a.498.498 0 0 0-.683.627l2.843 7.627a2 2 0 0 1 0 1.396l-2.842 7.627a.498.498 0 0 0 .682.627l18-8.5a.5.5 0 0 0 0-.904z',
          'M6 12h16',
        ],
      ),
    'chevronDown' => const OcOfficialSprite(paths: ['m6 9 6 6 6-6']),
    'chevronRight' => const OcOfficialSprite(paths: ['m9 6 6 6-6 6']),
    'chevronBack' => const OcOfficialSprite(paths: ['m15 18-6-6 6-6']),
    'xmark' => const OcOfficialSprite(paths: ['M18 6 6 18', 'm6 6 12 12']),
    'bolt' => const OcOfficialSprite(
        paths: [
          'M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2',
        ],
      ),
    'clock' => const OcOfficialSprite(
        paths: ['M12 7v5.25l3.25 1.75'],
        circles: [(12, 12, 9)],
      ),
    'layers' => const OcOfficialSprite(
        paths: [
          'M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83z',
          'M2 12a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 12',
          'M2 17a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 17',
        ],
      ),
    'share' => const OcOfficialSprite(
        paths: [
          'M12 2v13',
          'm16 6-4-4-4 4',
          'M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8',
        ],
      ),
    'server' => const OcOfficialSprite(
        rects: [(2, 2, 20, 8, 2), (2, 14, 20, 8, 2)],
        circles: [(6, 6, 0.55), (6, 18, 0.55)],
      ),
    'palette' => const OcOfficialSprite(
        paths: [
          'M12 22a1 1 0 0 1 0-20 10 9 0 0 1 10 9 5 5 0 0 1-5 5h-2.25a1.75 1.75 0 0 0-1.4 2.8l.3.4a1.75 1.75 0 0 1-1.4 2.8z',
        ],
        circles: [(13.5, 6.5, 0.5), (17.5, 10.5, 0.5), (6.5, 12.5, 0.5), (8.5, 7.5, 0.5)],
      ),
    'chatAi' => const OcOfficialSprite(
        paths: [
          'M12 6V2H8',
          'M15 11v2',
          'M2 12h2',
          'M20 12h2',
          'M20 16a2 2 0 0 1-2 2H8.828a2 2 0 0 0-1.414.586l-2.202 2.202A.71.71 0 0 1 4 20.286V8a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2z',
          'M9 11v2',
        ],
      ),
    'notification' => const OcOfficialSprite(
        paths: [
          'M10.268 21a2 2 0 0 0 3.464 0',
          'M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326',
        ],
      ),
    'chatHistory' => const OcOfficialSprite(
        paths: [
          'M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8',
          'M3 3v5h5',
          'M12 7v5l4 2',
        ],
      ),
    'aiGenerate' => const OcOfficialSprite(
        paths: [
          'm21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72',
          'm14 7 3 3',
          'M5 6v4',
          'M19 14v4',
          'M10 2v2',
          'M7 8H3',
          'M21 16h-4',
          'M11 3H9',
        ],
      ),
    'cloud' => const OcOfficialSprite(
        paths: ['M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z'],
      ),
    'nodeTree' => const OcOfficialSprite(
        paths: [
          'M5 16v-3a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v3',
          'M12 12V8',
        ],
        rects: [(16, 16, 6, 6, 1), (2, 16, 6, 6, 1), (9, 2, 6, 6, 1)],
      ),
    'brain' => const OcOfficialSprite(
        paths: [
          'M12 18V5',
          'M15 13a4.17 4.17 0 0 1-3-4 4.17 4.17 0 0 1-3 4',
          'M17.598 6.5A3 3 0 1 0 12 5a3 3 0 1 0-5.598 1.5',
          'M17.997 5.125a4 4 0 0 1 2.526 5.77',
          'M18 18a4 4 0 0 0 2-7.464',
          'M19.967 17.483A4 4 0 1 1 12 18a4 4 0 1 1-7.967-.517',
          'M6 18a4 4 0 0 1-2-7.464',
          'M6.003 5.125a4 4 0 0 0-2.526 5.77',
        ],
      ),
    'slashCommands' => const OcOfficialSprite(
        paths: ['M12 19h8', 'm4 17 6-6-6-6'],
      ),
    'bookOpen' => const OcOfficialSprite(
        paths: [
          'M12 7v14',
          'M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z',
        ],
      ),
    'barChart' => const OcOfficialSprite(
        paths: ['M3 3v16a2 2 0 0 0 2 2h16', 'M18 17V9', 'M13 17V5', 'M8 17v-3'],
      ),
    'information' => const OcOfficialSprite(
        paths: ['M12 16v-4', 'M12 8h.01'],
        circles: [(12, 12, 10)],
      ),
    'chatThread' => const OcOfficialSprite(
        paths: [
          'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z',
          'M8 8h8',
          'M8 12h5',
        ],
      ),
    'mcp' => const OcOfficialSprite(
        paths: ['M12 19h8', 'm4 17 6-6-6-6'],
      ),
    _ => null,
  };
}

/// Paint a 24×24 official sprite into [size]. [strokeWidth] is the viewBox
/// stroke (1.5 regular / 2 medium).
///
/// [filled] is the dock medium pass. Path bodies fill. Calendar rects
/// stay a stroked frame + filled header (not a solid slab). Small
/// circles ink as date dots. Open line paths stay stroke. Do not use
/// this on calendar-schedule / settings-3.
void paintOfficialSprite({
  required Canvas canvas,
  required Size size,
  required OcOfficialSprite sprite,
  required Color color,
  required double strokeWidth,
  bool filled = false,
}) {
  if (size.width <= 0 || size.height <= 0) return;
  canvas.save();
  canvas.scale(size.width / 24, size.height / 24);
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final fill = Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  for (final d in sprite.paths) {
    final path = parseSvgPath(d);
    if (filled && _pathHasFillBody(path)) {
      path.fillType = PathFillType.nonZero;
      canvas.drawPath(path, fill);
    } else {
      canvas.drawPath(path, stroke);
    }
  }
  for (final rect in sprite.rects) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.$1, rect.$2, rect.$3, rect.$4),
      Radius.circular(rect.$5),
    );
    // Delicate medium: stroke the calendar body (not a solid 18×18
    // slab) and fill only the header band. Date dots ink as fill.
    canvas.drawRRect(rrect, stroke);
    if (filled) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.$1, rect.$2, rect.$3, 1.45), // slim header band
          Radius.circular(rect.$5),
        ),
        fill,
      );
    }
  }
  for (final circle in sprite.circles) {
    final center = Offset(circle.$1, circle.$2);
    // Calendar date cells are dots. Stroking r≤1 at medium weight
    // blooms into rings (wake-0706). Search/branch eyes stay stroke.
    if (circle.$3 <= 1.0 || (filled && circle.$3 <= 2.6)) {
      canvas.drawCircle(center, circle.$3, fill);
    } else {
      canvas.drawCircle(center, circle.$3, stroke);
    }
  }
  canvas.restore();
}

bool _pathHasFillBody(Path path) {
  final bounds = path.getBounds();
  return bounds.width > 3 && bounds.height > 3;
}

Path parseSvgPath(String d) {
  final path = Path();
  final tokens = _tokenizeSvgPath(d);
  var i = 0;
  var x = 0.0;
  var y = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  var lastCmd = '';

  double num() {
    if (i >= tokens.length || tokens[i] is! double) {
      throw FormatException('SVG path expected number at $i in "$d"');
    }
    return tokens[i++] as double;
  }

  bool hasNumber() => i < tokens.length && tokens[i] is double;

  String takeCommand(String fallback) {
    if (i < tokens.length && tokens[i] is String) {
      return tokens[i++] as String;
    }
    if (fallback == 'M') return 'L';
    if (fallback == 'm') return 'l';
    return fallback;
  }

  while (i < tokens.length) {
    final cmd = takeCommand(lastCmd);
    lastCmd = cmd;
    final relative = cmd == cmd.toLowerCase();
    switch (cmd) {
      case 'M':
      case 'm':
        x = relative ? x + num() : num();
        y = relative ? y + num() : num();
        path.moveTo(x, y);
        startX = x;
        startY = y;
        lastCmd = relative ? 'm' : 'M';
      case 'L':
      case 'l':
        x = relative ? x + num() : num();
        y = relative ? y + num() : num();
        path.lineTo(x, y);
      case 'H':
      case 'h':
        x = relative ? x + num() : num();
        path.lineTo(x, y);
      case 'V':
      case 'v':
        y = relative ? y + num() : num();
        path.lineTo(x, y);
      case 'C':
      case 'c':
        final x1 = relative ? x + num() : num();
        final y1 = relative ? y + num() : num();
        final x2 = relative ? x + num() : num();
        final y2 = relative ? y + num() : num();
        x = relative ? x + num() : num();
        y = relative ? y + num() : num();
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'A':
      case 'a':
        final rx = num();
        final ry = num();
        final rotation = num();
        final large = num();
        final sweep = num();
        final nx = relative ? x + num() : num();
        final ny = relative ? y + num() : num();
        path.arcToPoint(
          Offset(nx, ny),
          radius: Radius.elliptical(rx.abs(), ry.abs()),
          rotation: rotation * 3.141592653589793 / 180,
          largeArc: large != 0,
          clockwise: sweep != 0,
        );
        x = nx;
        y = ny;
      case 'Z':
      case 'z':
        path.close();
        x = startX;
        y = startY;
      default:
        throw FormatException('Unsupported SVG command $cmd in "$d"');
    }
    // Repeat the same command while numbers remain (SVG implicit repeats).
    if (hasNumber() && cmd != 'Z' && cmd != 'z') {
      lastCmd = cmd == 'M'
          ? 'L'
          : cmd == 'm'
              ? 'l'
              : cmd;
    }
  }
  return path;
}

List<Object> _tokenizeSvgPath(String d) {
  final out = <Object>[];
  final buffer = StringBuffer();

  void flushNumber() {
    if (buffer.isEmpty) return;
    out.add(double.parse(buffer.toString()));
    buffer.clear();
  }

  for (var i = 0; i < d.length; i += 1) {
    final ch = d[i];
    final code = ch.codeUnitAt(0);
    final isLetter = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    if (isLetter) {
      flushNumber();
      out.add(ch);
      continue;
    }
    if (ch == ',' || ch == ' ' || ch == '\n' || ch == '\t') {
      flushNumber();
      continue;
    }
    if (ch == '-' && buffer.isNotEmpty && buffer.toString() != 'e' && buffer.toString() != 'E' && !buffer.toString().endsWith('e') && !buffer.toString().endsWith('E')) {
      flushNumber();
      buffer.write(ch);
      continue;
    }
    if (ch == '.' && buffer.toString().contains('.')) {
      flushNumber();
      buffer.write(ch);
      continue;
    }
    buffer.write(ch);
  }
  flushNumber();
  return out;
}
