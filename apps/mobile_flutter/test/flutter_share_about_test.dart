import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/diagnostics_export.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/data/share_delivery.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';
import 'package:openchamber/native/platform_channels.dart';
import 'package:openchamber/native/share_inbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SecondaryChrome.debugReset);

  test('Android share handoff geometry rejects oversized or non-image attachments', () {
    expect(usesAndroidShareComposerHandoff(platform: TargetPlatform.android), isTrue);
    expect(usesAndroidShareComposerHandoff(platform: TargetPlatform.iOS), isFalse);
    expect(
      isValidAndroidShareHandoffDraft(
        const NativeShareDraft(
          draftID: 'd1',
          attachments: [
            NativeShareAttachment(stagedPath: '/tmp/a.png', originalName: 'a.png', mime: 'image/png', byteSize: 12),
          ],
        ),
      ),
      isTrue,
    );
    expect(
      isValidAndroidShareHandoffDraft(
        const NativeShareDraft(
          draftID: 'd1',
          attachments: [
            NativeShareAttachment(stagedPath: '/tmp/a.pdf', originalName: 'a.pdf', mime: 'application/pdf', byteSize: 12),
          ],
        ),
      ),
      isFalse,
    );
  });

  test('diagnostics export is official schema without tokens or message bodies', () {
    final content = exportClientDiagnosticsReport(exportedAt: 1700000000000);
    final parsed = jsonDecode(content) as Map<String, Object?>;
    expect(parsed['schema'], 'openchamber.client-diagnostics.v1');
    expect(parsed['eventCount'], 0);
    expect(parsed['events'], isEmpty);
    expect(content.contains('Bearer'), isFalse);
    expect(content.contains('token'), isFalse);
    expect(diagnosticsExportFileName(DateTime.utc(2026, 9, 5, 12)), startsWith('openchamber-diagnostics-'));
    expect(diagnosticsExportEventCount(content), 0);
  });

  testWidgets('About export calls OpenChamberMedia.saveFile', (tester) async {
    const channel = MethodChannel(OpenChamberChannels.media);
    Map<String, Object?>? saved;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveFile') {
        saved = Map<String, Object?>.from(call.arguments as Map);
        return {'cancelled': false};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: MemoryOpenChamberTransport()));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-slug-about')));
    await tester.tap(find.byKey(const Key('settings-slug-about')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-diagnostics-export')), findsOneWidget);
    await tester.tap(find.byKey(const Key('about-diagnostics-export')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!['filename'], contains('openchamber-diagnostics-'));
    final decoded = utf8.decode(base64Decode(saved!['dataBase64'] as String));
    expect(decoded, contains('openchamber.client-diagnostics.v1'));
    expect(decoded.contains('oc_client'), isFalse);
    expect(find.text('Diagnostics log exported. No events were recorded yet.'), findsOneWidget);
  });

  testWidgets('Android assigned share opens chat composer without POST /share', (tester) async {
    final transport = MemoryOpenChamberTransport();
    final inbox = MemoryShareInbox();
    inbox.drafts.add(
      const NativeShareDraft(
        draftID: 'draft-ui',
        serverInstanceID: 'srv-memory',
        assistantID: 'asst-1',
        text: 'from android share',
        source: 'android-share',
      ),
    );
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: transport),
      shareInbox: inbox,
    );
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    await controller.drainShares();
    await tester.pumpAndSettle();
    expect(transport.shareCalls, isEmpty);
    expect(find.byKey(const Key('composer-field')), findsOneWidget);
    expect(find.text('from android share'), findsWidgets);
  });
}
