import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/chat_parts.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/oauth.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/data/settings_remote.dart';
import 'package:openchamber/features/chat/chat_screen.dart';
import 'package:openchamber/native/deep_link.dart';
import 'package:openchamber/native/external_browser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provider and MCP OAuth hit official authorize, pending, and callback paths', () async {
    final transport = MemoryOpenChamberTransport();
    final browser = MemoryExternalBrowser();
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: transport),
      browser: browser,
    );
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');

    final start = await controller.startProviderOAuth('anthropic');
    expect(start.url, 'https://example.invalid/oauth/provider');
    expect(browser.opened, contains('https://example.invalid/oauth/provider'));
    expect(transport.oauthCalls.any((call) => call['path'] == '/api/provider/anthropic/oauth/authorize'), isTrue);

    await controller.handleIncomingLink('openchamber://oauth/callback?code=prov-code');
    expect(controller.pendingOAuthCallback?.code, 'prov-code');
    await controller.completeProviderOAuth('anthropic', code: controller.takeOAuthCallback()?.code);
    expect(transport.oauthCalls.any((call) => call['path'] == '/api/provider/anthropic/oauth/callback' && call['code'] == 'prov-code'), isTrue);

    final mcpUrl = await controller.startMcpOAuth('filesystem');
    expect(mcpUrl, contains('state=mcp-state-1'));
    expect(transport.mcpPending['mcp-state-1']?['name'], 'filesystem');
    await controller.completeMcpOAuth(name: 'filesystem', code: 'mcp-code', state: 'mcp-state-1');
    expect(transport.oauthCalls.any((call) => call['path'] == '/api/mcp/filesystem/auth/callback' && call['code'] == 'mcp-code'), isTrue);
    expect(transport.mcpPending.containsKey('mcp-state-1'), isFalse);
  });

  test('plugin file write uses official /api/config/plugins/file', () async {
    final transport = MemoryOpenChamberTransport();
    final store = SettingsRemoteStore(
      api: OpenChamberApi(transport: transport),
      base: () => Uri.parse('http://192.168.1.74:2606'),
      bearer: () => 'tok',
    );
    await store.loadPlugins();
    expect(store.plugins.value!.any((item) => item.meta['kind'] == 'file' && item.id == 'file-1'), isTrue);
    final file = await store.readPluginFile('file-1');
    expect(file['content'], contains('ping'));
    await store.updatePluginFile(id: 'file-1', content: 'export const ping = () => 2\n');
    expect(transport.calls.any((call) => call.method == 'PUT' && call.path == '/api/config/plugins/file/file-1'), isTrue);
    await store.createPluginFile(fileName: 'extra.ts', content: 'export {}\n');
    expect(transport.calls.any((call) => call.method == 'POST' && call.path == '/api/config/plugins/file'), isTrue);
  });

  test('transcript parser renders diff, file, task, and permission cards instead of raw JSON', () {
    final messages = parseTurnPageMessages(
      {
        'records': [
          {
            'info': {
              'id': 'm-tools',
              'role': 'assistant',
              'time': {'created': 0, 'completed': 2000},
              'tokens': {'output': 80, 'reasoning': 20},
            },
            'parts': [
              {'type': 'text', 'text': 'Applying the patch.'},
              {
                'id': 'edit-1',
                'type': 'tool',
                'tool': 'edit',
                'state': {
                  'status': 'completed',
                  'input': {'path': 'lib/app.dart'},
                  'output': '--- a/lib/app.dart\n+++ b/lib/app.dart\n@@\n-old\n+new\n',
                },
              },
              {
                'id': 'write-1',
                'type': 'tool',
                'tool': 'write',
                'state': {
                  'status': 'completed',
                  'input': {'path': 'lib/new.dart'},
                  'output': 'created',
                },
              },
              {
                'id': 'task-1',
                'type': 'tool',
                'tool': 'task',
                'state': {
                  'status': 'running',
                  'title': 'Exploring',
                  'time': {'start': 0, 'end': 1000},
                  'tokens': 50,
                  'input': {'description': 'Scan repo'},
                },
              },
            ],
          },
        ],
      },
      permissions: const [
        PermissionRequestRecord(id: 'perm-1', sessionId: 'sess-catalog', permission: 'bash', patterns: ['git status']),
      ],
    );
    expect(messages.single.body, 'Applying the patch.');
    expect(messages.single.tokensPerSecond, '100 tok/s');
    expect(messages.single.parts.any((part) => part.kind == ChatPartKind.diff && part.added.contains('new')), isTrue);
    expect(messages.single.parts.any((part) => part.kind == ChatPartKind.fileOp && part.path == 'lib/new.dart'), isTrue);
    expect(messages.single.parts.any((part) => part.kind == ChatPartKind.task && part.tokensPerSecond != null), isTrue);
    expect(messages.single.parts.any((part) => part.kind == ChatPartKind.permission && part.permissionId == 'perm-1'), isTrue);
    expect(messages.single.parts.any((part) => part.body?.contains('{') == true && part.kind != ChatPartKind.text), isFalse);
  });

  test('permission reply posts official /api/permission/{id}/reply', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.replyToPermission(
      session: const HomeSessionRow(
        id: 'sess-catalog',
        title: 'Chat',
        projectLabel: 'openchamber',
        kind: HomeSessionKind.catalog,
        directory: '/workspace/openchamber',
      ),
      requestId: 'perm-1',
      reply: 'once',
    );
    expect(transport.permissionReplies.single['path'], '/api/permission/perm-1/reply');
    expect(transport.permissionReplies.single['reply'], 'once');
  });

  test('scheduled cards keep status from start and run-now marks running', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.loadScheduledTasks();
    final task = controller.scheduledTasks.value!.single;
    expect(task.statusLabel(), 'success');
    expect(task.scheduleLabel(), contains('daily'));
    expect(task.nextRunAt, isNotNull);
    await controller.runScheduledTaskNow(projectId: task.projectId, taskId: task.id);
    expect(controller.scheduledTasks.value!.single.isRunning, isTrue);
    expect(controller.scheduledRuns.value!.first.status, 'running');
    expect(
      transport.calls.any((call) => call.method == 'POST' && call.path == '/api/projects/proj-1/scheduled-tasks/cron-1/run'),
      isTrue,
    );
  });

  testWidgets('settings OAuth, plugin file, chat tool cards, and scheduled status render', (tester) async {
    final transport = MemoryOpenChamberTransport()
      ..transcript = [
        ...MemoryOpenChamberTransport.defaultTestTranscript,
        {
          'info': {'id': 'm-tools', 'role': 'assistant'},
          'parts': [
            {'type': 'text', 'text': 'Patched the file.'},
            {
              'id': 'edit-1',
              'type': 'tool',
              'tool': 'edit',
              'state': {
                'status': 'completed',
                'input': {'path': 'lib/app.dart'},
                'output': '--- a/lib/app.dart\n+++ b/lib/app.dart\n-old\n+new\n',
              },
            },
          ],
        },
      ];
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: transport),
      browser: MemoryExternalBrowser(),
    );
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
    expect(find.byKey(const Key('settings-oauth-start')), findsOneWidget);
    expect(find.byKey(const Key('settings-oauth-gap')), findsNothing);
    await tester.tap(find.byKey(const Key('settings-oauth-start')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings-oauth-code')), 'widget-code');
    await tester.tap(find.byKey(const Key('settings-oauth-complete')));
    await tester.pumpAndSettle();
    expect(transport.oauthCalls.any((call) => call['code'] == 'widget-code'), isTrue);
    Navigator.of(tester.element(find.byKey(const Key('settings-oauth-complete'))), rootNavigator: true).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings-slug-plugins')));
    await tester.tap(find.byKey(const Key('settings-slug-plugins')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-item-file-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-item-file-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-editor-field-content')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('settings-editor-field-content')), 'export const ping = () => 3\n');
    await tester.tap(find.byKey(const Key('settings-editor-save')));
    await tester.pumpAndSettle();
    expect(transport.calls.any((call) => call.method == 'PUT' && call.path.contains('/api/config/plugins/file/file-1')), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Schedule')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scheduled-task-cron-1')), findsOneWidget);
    expect(find.textContaining('success'), findsWidgets);
    expect(find.textContaining('daily'), findsWidgets);
    await tester.tap(find.byKey(const Key('scheduled-run-now-cron-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('running'), findsWidgets);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Projects')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Session'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byKey(const Key('chat-activity-m-tools')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-activity-m-tools')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-tool-diff-edit-1')), findsOneWidget);
    expect(find.byKey(const Key('chat-tool-permission-perm-1')), findsOneWidget);
  });

  test('oauth deep links are classified and http(s) only for the browser', () {
    expect(classifyDeepLink('openchamber://oauth/callback?code=abc').kind, DeepLinkKind.oauth);
    expect(parseOAuthCallbackUri('openchamber://mcp/oauth/callback?code=x&state=s').hasCode, isTrue);
    expect(
      () => MemoryExternalBrowser().open('openchamber://oauth/callback?code=abc'),
      throwsA(isA<ExternalBrowserException>()),
    );
  });

  test('failed scheduled refresh keeps the previous snapshot', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.loadScheduledTasks();
    transport.catalogStatus = 503;
    await controller.loadScheduledTasks();
    expect(controller.scheduledTasks.errorKey, 'settings.error.loadFailed');
    expect(controller.scheduledTasks.value!.single.id, 'cron-1');
  });
}
