import 'dart:io';

import 'package:flutter/services.dart';

/// Load Latin + CJK + icon families for WidgetTester goldens.
///
/// Flutter tests do not ship CupertinoIcons.ttf / Roboto unless we register
/// them. Chrome icons are painted (`OcGlyph`); these fonts keep Latin digits
/// and Chinese copy from turning into tofu.
Future<void> loadReviewFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/home/ubuntu/flutter';
  await _loadFaces('ReviewSans', [
    [
      '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/home/ubuntu/development/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ],
    [
      '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Medium.ttf',
      '/home/ubuntu/development/flutter/bin/cache/artifacts/material_fonts/Roboto-Medium.ttf',
    ],
  ]);
  await _loadFamily('ReviewCjk', [
    '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf',
    '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/noto-cjk/NotoSansCJKsc-Regular.otf',
  ]);
  await _loadFamily('RobotoReal', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  ]);
  final material = [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/home/ubuntu/development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  await _loadFamily('MaterialIcons', material);
  final cupertino = [
    '${Directory.current.path}/build/unit_test_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
    '/home/ubuntu/.pub-cache/hosted/pub.dev/cupertino_icons-1.0.8/assets/CupertinoIcons.ttf',
    '${Directory.current.path}/../../apps/mobile_flutter/build/unit_test_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
  ];
  final cupertinoBytes = _firstBytes(cupertino);
  if (cupertinoBytes != null) {
    await _loadBytes('CupertinoIcons', cupertinoBytes);
    await _loadBytes('packages/cupertino_icons/CupertinoIcons', cupertinoBytes);
  }
  try {
    final bundled = await rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf');
    await _loadBytes('CupertinoIcons', bundled);
    await _loadBytes('packages/cupertino_icons/CupertinoIcons', bundled);
  } catch (_) {}
}

Future<void> _loadFamily(String family, List<String> candidates) async {
  final bytes = _firstBytes(candidates);
  if (bytes == null) return;
  await _loadBytes(family, bytes);
}

/// One family with Regular + Medium so official `font-medium` is a real cut,
/// not a synthesized bold that packs session titles.
Future<void> _loadFaces(String family, List<List<String>> faces) async {
  final loader = FontLoader(family);
  var any = false;
  for (final candidates in faces) {
    final bytes = _firstBytes(candidates);
    if (bytes == null) continue;
    loader.addFont(Future<ByteData>.value(bytes));
    any = true;
  }
  if (!any) return;
  try {
    await loader.load();
  } catch (_) {}
}

ByteData? _firstBytes(List<String> candidates) {
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final raw = file.readAsBytesSync();
    if (raw.isEmpty) continue;
    return ByteData.sublistView(Uint8List.fromList(raw));
  }
  return null;
}

Future<void> _loadBytes(String family, ByteData bytes) async {
  try {
    await (FontLoader(family)..addFont(Future<ByteData>.value(bytes))).load();
  } catch (_) {}
}
