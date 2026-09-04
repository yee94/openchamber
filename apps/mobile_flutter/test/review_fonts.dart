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
  // Official session titles are `font-medium` (PingFang / Noto Medium).
  // Prefer Noto Sans CJK SC Regular+Medium+Bold so w500/w600 are real
  // cuts — not a miter stem and not a synthesized blob on Micro Hei.
  // Recapture hosts: `fonts-noto-cjk` + `fonts-noto-cjk-extra`.
  // Fallback is WenQuanYi Regular, then Droid.
  await _loadCjkFaces();
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

const _cjkRegularCandidates = [
  // Regular chrome / meta stay Micro Hei so only official medium/semibold
  // titles pick Noto. Swapping Regular to Noto restyles every CJK glyph.
  '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc',
  '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  '/usr/share/fonts/noto-cjk/NotoSansCJKsc-Regular.otf',
  '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf',
];

const _cjkMediumCandidates = [
  '/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc',
  '/usr/share/fonts/noto-cjk/NotoSansCJKsc-Medium.otf',
];

const _cjkBoldCandidates = [
  '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
  '/usr/share/fonts/noto-cjk/NotoSansCJKsc-Bold.otf',
];

Future<void> _loadCjkFaces() async {
  final faces = <List<String>>[_cjkRegularCandidates];
  if (_cjkMediumCandidates.any((path) => File(path).existsSync())) {
    faces.add(_cjkMediumCandidates);
  }
  if (_cjkBoldCandidates.any((path) => File(path).existsSync())) {
    faces.add(_cjkBoldCandidates);
  }
  if (faces.length > 1) {
    await _loadFaces('ReviewCjk', faces);
    return;
  }
  await _loadFamily('ReviewCjk', _cjkRegularCandidates);
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

/// Noto CJK TTC packs JP/KR/SC/TC/HK. Goldens are zh-CN — pick SC.
int _ttcFaceIndex(Uint8List ttc, {String prefer = 'CJK SC'}) {
  final numFonts = _u32(ttc, 8);
  for (var i = 0; i < numFonts; i++) {
    final offset = _u32(ttc, 12 + i * 4);
    if (_ttcName(ttc, offset).contains(prefer)) return i;
  }
  return 0;
}

String _ttcName(Uint8List ttc, int offset) {
  if (offset + 12 > ttc.length) return '';
  final numTables = _u16(ttc, offset + 4);
  for (var i = 0; i < numTables; i++) {
    final entry = offset + 12 + i * 16;
    if (entry + 16 > ttc.length) break;
    final tag = String.fromCharCodes(ttc.sublist(entry, entry + 4));
    if (tag != 'name') continue;
    final tableOffset = _u32(ttc, entry + 8);
    if (tableOffset + 6 > ttc.length) return '';
    final count = _u16(ttc, tableOffset + 2);
    final storage = tableOffset + _u16(ttc, tableOffset + 4);
    final names = StringBuffer();
    for (var j = 0; j < count; j++) {
      final rec = tableOffset + 6 + j * 12;
      if (rec + 12 > ttc.length) break;
      final platform = _u16(ttc, rec);
      final nameId = _u16(ttc, rec + 6);
      final length = _u16(ttc, rec + 8);
      final nameOffset = _u16(ttc, rec + 10);
      if (nameId != 1 && nameId != 4 && nameId != 16) continue;
      if (platform != 0 && platform != 3) continue;
      final start = storage + nameOffset;
      final end = start + length;
      if (end > ttc.length) continue;
      try {
        names.write(String.fromCharCodes(_u16beChars(ttc.sublist(start, end))));
      } catch (_) {}
    }
    return names.toString();
  }
  return '';
}

List<int> _u16beChars(Uint8List raw) {
  final out = <int>[];
  for (var i = 0; i + 1 < raw.length; i += 2) {
    out.add((raw[i] << 8) | raw[i + 1]);
  }
  return out;
}

Uint8List _extractTtcFace(Uint8List ttc, [int? index]) {
  final numFonts = _u32(ttc, 8);
  index ??= _ttcFaceIndex(ttc);
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
