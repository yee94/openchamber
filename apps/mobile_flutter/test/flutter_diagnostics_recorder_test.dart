import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/app_version.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/data/diagnostics_export.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/chat/chat_screen.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';
import 'package:openchamber/native/platform_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SecondaryChrome.debugReset();
    debugResetClientDiagnosticsRecorder();
  });

  test('prerelease default is on; stable default is off; preference wins', () {
    expect(isPrereleaseClientVersion(AppVersion.display), isTrue);
    expect(resolveTranscriptDiagnosticsEnabled(version: AppVersion.display), isTrue);
    expect(resolveTranscriptDiagnosticsEnabled(version: '1.19.5'), isFalse);
    expect(resolveTranscriptDiagnosticsEnabled(version: '1.19.5', preference: true), isTrue);
    expect(resolveTranscriptDiagnosticsEnabled(version: AppVersion.display, preference: false), isFalse);
    expect(parseTranscriptDiagnosticsPreference('true'), isTrue);
    expect(parseTranscriptDiagnosticsPreference('false'), isFalse);
    expect(parseTranscriptDiagnosticsPreference(null), isNull);
  });

  test('recorder ring keeps 500 events and redacts tokens, never message bodies', () {
    final recorder = ClientDiagnosticsRecorder(enabled: true);
    debugResetClientDiagnosticsRecorder(recorder);
    for (var i = 0; i < 502; i += 1) {
      recorder.record(
        snapshotTranscriptDiagnostics(
          kind: 'ensure-initial',
          sessionID: 'sess-$i',
          now: 1700000000000 + i,
          messages: [
            ChatMessage(id: 'u$i', body: 'secret user body $i', isUser: true),
            const ChatMessage(id: 'a1', body: 'assistant body', isUser: false),
          ],
        ),
      );
    }
    expect(recorder.events.length, 500);
    expect(recorder.events.first.sessionID, 'sess-2');
    expect(recorder.events.last.sessionID, 'sess-501');
    expect(sanitizeDiagnosticsError('Bearer abc.def'), 'redacted-error');
    expect(sanitizeDiagnosticsError(const OpenChamberHttpException(503, '/api/session/x/messages')), contains('503'));
    expect(diagnosticsHttpStatus(const OpenChamberHttpException(503, '/api/session/x/messages')), 503);

    final content = recorder.exportReport(exportedAt: 1700000000000);
    expect(content.contains('secret user body'), isFalse);
    expect(content.contains('assistant body'), isFalse);
    expect(content.contains('Bearer'), isFalse);
    expect(content.contains('schema'), isTrue);
    final parsed = jsonDecode(content) as Map<String, Object?>;
    expect(parsed['schema'], 'openchamber.client-diagnostics.v1');
    expect(parsed['eventCount'], 500);
    expect(parsed['feats'], ['transcript']);
    final first = (parsed['events'] as List).first as Map<String, Object?>;
    expect(first['feat'], 'transcript');
    expect(first['kind'], 'ensure-initial');
    expect(first['lastMessageIDs'], ['u2', 'a1']);
    expect(first['identityMissingCount'], 1);
    expect(first.containsKey('body'), isFalse);
  });

  test('disabled recorder drops events', () {
    final recorder = ClientDiagnosticsRecorder(enabled: false);
    recorder.record(snapshotTranscriptDiagnostics(kind: 'ensure-initial', sessionID: 's'));
    expect(recorder.events, isEmpty);
    expect(diagnosticsExportEventCount(recorder.exportReport(exportedAt: 1)), 0);
  });

  testWidgets('chat load records ensure-initial without transcript text', (tester) async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    await controller.handleIncomingLink('openchamber://session/sess-catalog');
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(clientDiagnosticsRecorder.events, isNotEmpty);
    expect(clientDiagnosticsRecorder.events.first.kind, 'ensure-initial');
    expect(clientDiagnosticsRecorder.events.first.source, 'network');
    expect(clientDiagnosticsRecorder.events.first.lastMessageIDs, isNotEmpty);
    final report = clientDiagnosticsRecorder.exportReport();
    expect(report.contains('Open a session from Projects.'), isFalse);
    expect(report.contains('oc_client'), isFalse);
  });

  testWidgets('chat load failure records request-error and keeps export official', (tester) async {
    final transport = MemoryOpenChamberTransport()..messagesStatus = 503;
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    await controller.handleIncomingLink('openchamber://session/sess-catalog');
    await tester.pumpAndSettle();
    expect(clientDiagnosticsRecorder.events.single.kind, 'request-error');
    expect(clientDiagnosticsRecorder.events.single.purpose, 'load-failed');
    expect(clientDiagnosticsRecorder.events.single.httpStatus, 503);
    expect(clientDiagnosticsRecorder.events.single.error, isNot(contains('Bearer')));
  });

  testWidgets('About toggle hides export and persists the official preference key', (tester) async {
    const channel = MethodChannel(OpenChamberChannels.media);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveFile') return {'cancelled': false};
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final store = MemorySecureStore();
    final controller = AppController(store: store, api: OpenChamberApi(transport: MemoryOpenChamberTransport()));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-slug-about')));
    await tester.tap(find.byKey(const Key('settings-slug-about')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('about-diagnostics-enable')), 120);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-diagnostics-export')), findsOneWidget);
    await tester.tap(find.byKey(const Key('about-diagnostics-enable')));
    await tester.pumpAndSettle();
    expect(controller.diagnosticsEnabled, isFalse);
    expect(store.snapshot[transcriptDiagnosticsPreferenceKey], 'false');
    expect(find.byKey(const Key('about-diagnostics-export')), findsNothing);
  });
}
