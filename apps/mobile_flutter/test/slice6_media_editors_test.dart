import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/assistant_scheduled.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/prompt_attachment.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/data/settings_remote.dart';
import 'package:openchamber/data/widget_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prompt attachment PUT uses official headers and prompt_async file parts', () async {
    final transport = MemoryOpenChamberTransport();
    final api = OpenChamberApi(transport: transport);
    final controller = AppController(store: MemorySecureStore(), api: api);
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.refreshSessions();
    final session = controller.sessions.firstWhere((row) => row.id == 'sess-catalog');
    final bytes = Uint8List.fromList(List<int>.filled(16, 7));

    await controller.sendPrompt(
      session: session,
      messageId: 'msg-file',
      text: 'see photo',
      attachments: [
        AttachmentDraft(name: 'photo.jpg', mime: 'image/jpeg', bytes: bytes),
      ],
    );

    final upload = transport.calls.firstWhere((call) => call.path.startsWith('/api/fs/prompt-attachments/'));
    expect(upload.method, 'PUT');
    expect(upload.bytes, bytes);
    expect(upload.extraHeaders['X-OpenChamber-Mime'], 'image/jpeg');
    expect(upload.extraHeaders['X-OpenChamber-Sha256'], sha256Hex(bytes));
    expect(upload.extraHeaders['X-OpenChamber-Content-Length'], '${bytes.length}');
    expect(transport.uploadedAttachments, isNotEmpty);
    expect(transport.sentPromptParts.single.any((part) => part['type'] == 'file'), isTrue);
    expect(transport.sentPromptParts.single.any((part) => part['url']?.toString().startsWith('file://') == true), isTrue);
    expect(transport.sentPromptParts.single.any((part) => part['url']?.toString().startsWith('data:') == true), isFalse);
    expect(transport.sentPrompts, ['see photo']);
  });

  test('too-large attachment is not uploaded as a fake success', () async {
    final transport = MemoryOpenChamberTransport();
    final api = OpenChamberApi(transport: transport);
    expect(
      () => uploadPromptAttachmentBytes(
        api: api,
        base: Uri.parse('http://192.168.1.74:2606'),
        bytes: List<int>.filled(maxPromptAttachmentBytes + 1, 1),
        mime: 'image/jpeg',
        filename: 'huge.jpg',
      ),
      throwsA(isA<PromptAttachmentUploadError>()),
    );
    expect(transport.calls, isEmpty);
  });

  test('settings editors hit official create/auth/install paths', () async {
    final transport = MemoryOpenChamberTransport();
    final store = SettingsRemoteStore(
      api: OpenChamberApi(transport: transport),
      base: () => Uri.parse('http://192.168.1.74:2606'),
      bearer: () => 'tok',
    );

    await store.saveProviderApiKey('anthropic', 'sk-test');
    await store.createAgent(name: 'reviewer', description: 'Review diffs', mode: 'subagent');
    await store.createAssistant(name: 'Desk', providerId: 'anthropic', modelId: 'claude-sonnet-4');
    await store.createMcp(name: 'github', type: 'remote', url: 'https://example.invalid/mcp');
    await store.createPlugin(spec: 'opencode-plugin/demo');
    await store.createSkill(name: 'notes', description: 'Draft notes');
    await store.installSkill(source: 'https://example.invalid/skills.git', skillDir: 'notes');
    await store.createCommand(name: 'ship', template: 'Ship the change', description: 'Release');

    expect(transport.calls.any((call) => call.method == 'PUT' && call.path == OpenChamberPaths.providerAuth('anthropic') && call.body?['type'] == 'api'), isTrue);
    expect(transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.configAgent('reviewer')), isTrue);
    expect(transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.assistants), isTrue);
    expect(transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.configMcp('github')), isTrue);
    expect(transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.pluginsEntry), isTrue);
    expect(transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.configSkill('notes')), isTrue);
    expect(
      transport.calls.any(
        (call) =>
            call.method == 'POST' &&
            call.path == OpenChamberPaths.skillsInstall &&
            call.body?['source'] == 'https://example.invalid/skills.git',
      ),
      isTrue,
    );
    expect(transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.configCommand('ship')), isTrue);
  });

  test('assistant snapshot and scheduled runs parse official payloads', () {
    final assistants = parseAssistantSnapshotView(MemoryOpenChamberTransport.defaultTestAssistants);
    expect(assistants.assistants.single.id, 'asst-1');
    expect(assistants.assistants.single.boundSession?.id, 'sess-catalog');
    final tasks = parseScheduledTasks(MemoryOpenChamberTransport.defaultTestScheduledTasks);
    expect(tasks.single.id, 'cron-1');
    final runs = parseScheduledRuns(MemoryOpenChamberTransport.defaultTestScheduledRuns);
    expect(runs.single.historySession?.id, 'sess-catalog');
    expect(buildWidgetSnapshot(fixtureHomeSessions()).attentionCount, 1);
  });

  test('failed assistant snapshot keeps the previous list', () async {
    final transport = MemoryOpenChamberTransport()..catalogStatus = 503;
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    controller.assistantSnapshot = SettingsResource(
      value: parseAssistantSnapshotView(MemoryOpenChamberTransport.defaultTestAssistants),
    );
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.loadAssistantSnapshot();
    expect(controller.assistantSnapshot.errorKey, 'settings.error.loadFailed');
    expect(controller.assistantSnapshot.value?.assistants.single.id, 'asst-1');
  });

  testWidgets('assistant and scheduled tabs load official rows', (tester) async {
    final controller = AppController(store: MemorySecureStore());
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Agent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-item-asst-1')), findsOneWidget);
    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Schedule')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scheduled-task-cron-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scheduled-task-cron-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scheduled-run-run-1')), findsOneWidget);
  });

  testWidgets('provider editor can save an API key and shows the OAuth gap', (tester) async {
    final controller = AppController(store: MemorySecureStore());
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-slug-providers')));
    await tester.tap(find.byKey(const Key('settings-slug-providers')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-item-anthropic')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-oauth-gap')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('settings-editor-field-key')), 'sk-test');
    await tester.tap(find.byKey(const Key('settings-editor-save')));
    await tester.pumpAndSettle();
  });
}
