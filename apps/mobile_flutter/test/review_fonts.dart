import 'dart:io';
import 'dart:typed_data';

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
  // DroidSansFallback Regular at 12px AA-washes to ~RGB 150 on cream
  // (row-box p5 218–240, zero lum<120). WenQuanYi Micro Hei is still a
  // Regular cut but has a real stem — PIL 12px: 263 lum<120 vs Droid 185.
  // Official font-medium is PingFang/Noto Medium on device; goldens cannot
  // invent that cut. Prefer Micro Hei, then Droid.
  await _loadFamily('ReviewCjk', [
    '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/noto-cjk/NotoSansCJKsc-Regular.otf',
    '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf',
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
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final raw = file.readAsBytesSync();
    if (raw.isEmpty) continue;
    try {
      final bytes = _asSfnt(Uint8List.fromList(raw));
      await (FontLoader(family)..addFont(Future<ByteData>.value(bytes))).load();
      return;
    } catch (_) {}
  }
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
    return _asSfnt(Uint8List.fromList(raw));
  }
  return null;
}

/// FontLoader wants a single sfnt. WenQuanYi ships as TTC.
ByteData _asSfnt(Uint8List raw) {
  if (raw.length >= 4 && raw[0] == 0x74 && raw[1] == 0x74 && raw[2] == 0x63 && raw[3] == 0x66) {
    return ByteData.sublistView(_extractTtcFace(raw));
  }
  return ByteData.sublistView(raw);
}

Uint8List _extractTtcFace(Uint8List ttc, [int index = 0]) {
  final numFonts = _u32(ttc, 8);
  if (index >= numFonts) {
    return ttc;
  }
  final offset = _u32(ttc, 12 + index * 4);
  if (offset + 12 > ttc.length) return ttc;
  final numTables = _u16(ttc, offset + 4);
  final out = BytesBuilder();
  out.add(ttc.sublist(offset, offset + 12));
  var cursor = 12 + 16 * numTables;
  final dir = <int>[];
  final payloads = <Uint8List>[];
  for (var i = 0; i < numTables; i++) {
    final entry = offset + 12 + i * 16;
    final tag = ttc.sublist(entry, entry + 4);
    final checksum = ttc.sublist(entry + 4, entry + 8);
    final tableOffset = _u32(ttc, entry + 8);
    final tableLength = _u32(ttc, entry + 12);
    final end = tableOffset + tableLength;
    if (end > ttc.length) return ttc;
    final pad = (4 - (tableLength & 3)) & 3;
    dir.addAll(tag);
    dir.addAll(checksum);
    dir.addAll(_u32bytes(cursor));
    dir.addAll(_u32bytes(tableLength));
    final chunk = Uint8List(tableLength + pad);
    chunk.setRange(0, tableLength, ttc, tableOffset);
    payloads.add(chunk);
    cursor += tableLength + pad;
  }
  out.add(Uint8List.fromList(dir));
  for (final payload in payloads) {
    out.add(payload);
  }
  return Uint8List.fromList(out.toBytes());
}

int _u16(Uint8List bytes, int offset) => (bytes[offset] << 8) | bytes[offset + 1];

int _u32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];

List<int> _u32bytes(int value) => [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];

Future<void> _loadBytes(String family, ByteData bytes) async {
  try {
    await (FontLoader(family)..addFont(Future<ByteData>.value(bytes))).load();
  } catch (_) {}
}
