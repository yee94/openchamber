import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/github_worktree.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/chat/chat_screen.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SecondaryChrome.debugReset);

  test('github issue branch slug matches Cap issue-N-title pattern', () {
    expect(githubIssueBranchName(number: 42, title: 'Native gap audit'), 'issue-42-native-gap-audit');
    expect(slugifyWorktreeName('feat/Share UI'), 'feat-share-ui');
    expect(splitDefaultModel('anthropic/claude-sonnet-4').providerId, 'anthropic');
    expect(splitDefaultModel('anthropic/claude-sonnet-4').modelId, 'claude-sonnet-4');
  });

  test('createScheduledTask PUTs official project scheduled-tasks payload', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    final ok = await controller.createScheduledTask(
      projectId: 'proj-1',
      name: 'Morning digest',
      prompt: 'Summarize overnight changes',
      scheduleTime: '07:15',
    );
    expect(ok, isTrue);
    final put = transport.calls.lastWhere(
      (call) => call.method == 'PUT' && call.path == OpenChamberPaths.scheduledTasksForProject('proj-1'),
    );
    final task = put.body?['task'] as Map;
    expect(task['name'], 'Morning digest');
    expect(task['schedule'], {'kind': 'daily', 'time': '07:15'});
    expect((task['execution'] as Map)['prompt'], 'Summarize overnight changes');
    expect((task['execution'] as Map)['providerID'], 'anthropic');
    expect(controller.scheduledTasks.value?.any((item) => item.name == 'Morning digest'), isTrue);
  });

  test('forkSession POSTs official /api/session/:id/fork', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    final forked = await controller.forkSession(
      session: const HomeSessionRow(
        id: 'sess-catalog',
        title: 'Catalog',
        projectLabel: 'openchamber',
        kind: HomeSessionKind.catalog,
        directory: '/workspace/openchamber',
      ),
      messageId: 'm2',
    );
    expect(forked?.id, startsWith('ses_fork_'));
    expect(
      transport.calls.any(
        (call) =>
            call.method == 'POST' &&
            call.path == OpenChamberPaths.sessionFork('sess-catalog') &&
            call.body?['messageID'] == 'm2',
      ),
      isTrue,
    );
  });

  testWidgets('scheduled + opens create sheet and PUTs the task', (tester) async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-scheduled')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scheduled-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scheduled-create-sheet')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('scheduled-create-name')), 'Weekly review');
    await tester.enterText(find.byKey(const Key('scheduled-create-prompt')), 'Review the week');
    await tester.tap(find.byKey(const Key('scheduled-create-save')));
    await tester.pumpAndSettle();
    expect(
      transport.calls.any(
        (call) =>
            call.method == 'PUT' &&
            call.path == OpenChamberPaths.scheduledTasksForProject('proj-1') &&
            call.body?['task'] is Map &&
            (call.body?['task'] as Map)['name'] == 'Weekly review',
      ),
      isTrue,
    );
  });

  testWidgets('chat copy writes the assistant body to the clipboard', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('chat-action-copy')));
    await tester.tap(find.byKey(const Key('chat-action-copy')));
    await tester.pumpAndSettle();
    expect(find.text('Copied'), findsWidgets);
  });
}
