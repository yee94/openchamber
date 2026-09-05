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
  // Official session titles are `font-medium` (PingFang Medium). Regular
  // chrome stays Micro Hei. Title w500/w600 load Noto Sans CJK SC
  // DemiLight remapped to 500 — Noto Medium is the wrong optical peer
  // (packs 12px / bricks 32px). Do not load Noto Bold. Recapture hosts:
  // `fonts-noto-cjk` + `fonts-noto-cjk-extra`.
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

/// PingFang Medium optical peer, then Noto Medium if DemiLight is absent.
const _cjkTitleMediumCandidates = [
  '/usr/share/fonts/opentype/noto/NotoSansCJK-DemiLight.ttc',
  '/usr/share/fonts/noto-cjk/NotoSansCJKsc-DemiLight.otf',
  '/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc',
  '/usr/share/fonts/noto-cjk/NotoSansCJKsc-Medium.otf',
];

Future<void> _loadCjkFaces() async {
  final regular = _firstBytes(_cjkRegularCandidates);
  if (regular == null) return;
  final title = _firstTitleMediumBytes();
  final loader = FontLoader('ReviewCjk');
  loader.addFont(Future<ByteData>.value(regular));
  if (title != null) {
    loader.addFont(Future<ByteData>.value(title));
  }
  try {
    await loader.load();
  } catch (_) {}
}

/// DemiLight is usWeightClass 350. Flutter w500 would snap to Regular
/// 400 (closer than 350). Remap the title face to 500 so official
/// `font-medium` / `font-semibold` select it.
ByteData? _firstTitleMediumBytes() {
  final bytes = _firstBytes(_cjkTitleMediumCandidates);
  if (bytes == null) return null;
  final copy = Uint8List.fromList(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );
  return ByteData.sublistView(_withWeightClass(copy, 500));
}

/// OpenType OS/2 `usWeightClass` at table offset 4.
Uint8List _withWeightClass(Uint8List sfnt, int weight) {
  if (sfnt.length < 12) return sfnt;
  final numTables = _u16(sfnt, 4);
  for (var i = 0; i < numTables; i++) {
    final entry = 12 + i * 16;
    if (entry + 16 > sfnt.length) break;
    final tag = String.fromCharCodes(sfnt.sublist(entry, entry + 4));
    if (tag != 'OS/2') continue;
    final tableOffset = _u32(sfnt, entry + 8);
    final tableLength = _u32(sfnt, entry + 12);
    if (tableOffset + 6 > sfnt.length || tableLength < 6) return sfnt;
    final out = Uint8List.fromList(sfnt);
    out[tableOffset + 4] = (weight >> 8) & 0xff;
    out[tableOffset + 5] = weight & 0xff;
    var sum = 0;
    final end = tableOffset + tableLength;
    for (var o = tableOffset; o < end; o += 4) {
      final b0 = o < out.length ? out[o] : 0;
      final b1 = o + 1 < out.length ? out[o + 1] : 0;
      final b2 = o + 2 < out.length ? out[o + 2] : 0;
      final b3 = o + 3 < out.length ? out[o + 3] : 0;
      sum = (sum + ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)) & 0xffffffff;
    }
    out[entry + 4] = (sum >> 24) & 0xff;
    out[entry + 5] = (sum >> 16) & 0xff;
    out[entry + 6] = (sum >> 8) & 0xff;
    out[entry + 7] = sum & 0xff;
    return out;
  }
  return sfnt;
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

/// One family with Regular + title-medium (DemiLight@500) so official
/// `font-medium` is a real cut, not a synthesized bold that packs titles.
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
