import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Launcher art must be the official Capacitor OpenChamber mark.
/// Debug side-by-side identity stays package + label only — not a different glyph.
void main() {
  final flutterRes = Directory('android/app/src/main/res');
  final capacitorRes = Directory('../../packages/mobile/android/app/src/main/res');
  final officialIos1024 = File(
    '../../packages/mobile/ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png',
  );
  final officialSource = File('../../packages/mobile/assets/icon-only.png');
  final flutterIos1024 = File(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
  );

  test('Android launcher resources copy official Capacitor mipmaps', () {
    const densities = ['ldpi', 'mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
    const names = [
      'ic_launcher.png',
      'ic_launcher_round.png',
      'ic_launcher_foreground.png',
      'ic_launcher_background.png',
    ];
    for (final density in densities) {
      for (final name in names) {
        final official = File('${capacitorRes.path}/mipmap-$density/$name');
        final flutter = File('${flutterRes.path}/mipmap-$density/$name');
        expect(official.existsSync(), isTrue, reason: official.path);
        expect(flutter.existsSync(), isTrue, reason: flutter.path);
        expect(
          flutter.readAsBytesSync(),
          official.readAsBytesSync(),
          reason: 'Flutter $density/$name must be a byte copy of Capacitor',
        );
      }
    }

    final adaptive = File('${flutterRes.path}/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    final adaptiveRound =
        File('${flutterRes.path}/mipmap-anydpi-v26/ic_launcher_round.xml').readAsStringSync();
    expect(adaptive, contains('@drawable/ic_launcher_openchamber_background'));
    expect(adaptive, contains('@mipmap/ic_launcher_foreground'));
    expect(adaptiveRound, contains('@drawable/ic_launcher_openchamber_background'));
    expect(adaptiveRound, contains('@mipmap/ic_launcher_foreground'));
    expect(
      File('${flutterRes.path}/drawable/ic_launcher_openchamber_background.xml').existsSync(),
      isTrue,
    );
  });

  test('iOS AppIcon marketing image is the official 1024 OpenChamber mark', () {
    expect(officialSource.existsSync(), isTrue);
    expect(officialIos1024.existsSync(), isTrue);
    expect(flutterIos1024.existsSync(), isTrue);
    final officialBytes = officialSource.readAsBytesSync();
    expect(officialIos1024.readAsBytesSync(), officialBytes);
    expect(flutterIos1024.readAsBytesSync(), officialBytes);
    expect(officialBytes.length, greaterThan(50 * 1024));

    final contents = File(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
    ).readAsStringSync();
    expect(contents, contains('Icon-App-1024x1024@1x.png'));
    expect(contents, contains('Icon-App-60x60@3x.png'));

    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(pbx, contains('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'));

    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, isNot(contains('CFBundleIconFile')));
  });

  test('debug identity stays package and label, not a different mark', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationIdSuffix = ".debug"'));
    expect(gradle, contains('resValue("string", "app_name", "OpenChamber v2")'));
    expect(gradle, contains('official OpenChamber mark'));

    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    expect(manifest, contains('android:label="@string/app_name"'));
  });
}
