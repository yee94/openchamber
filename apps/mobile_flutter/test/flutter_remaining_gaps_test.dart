import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SecondaryChrome.debugReset);

  Future<({AppController controller, MemoryOpenChamberTransport transport})> pumpApp(WidgetTester tester) async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    return (controller: controller, transport: transport);
  }

  test('existing-branch worktree POSTs mode existing and existingBranch', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    expect(await controller.listGitBranches('/workspace/openchamber'), ['main', 'feat/share']);
    final ok = await controller.createWorktree(
      directory: '/workspace/openchamber',
      worktreeName: 'feat-share',
      mode: 'existing',
      existingBranch: 'feat/share',
    );
    expect(ok, isTrue);
    final create = transport.calls.lastWhere(
      (call) => call.method == 'POST' && call.path == OpenChamberPaths.gitWorktrees,
    );
    expect(create.body?['mode'], 'existing');
    expect(create.body?['existingBranch'], 'feat/share');
    expect(create.body?['worktreeName'], 'feat-share');
    expect(create.body?.containsKey('branchName'), isFalse);
  });

  test('scheduled editor PUTs cron/weekly and DELETE removes the task', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    expect(
      await controller.createScheduledTask(
        projectId: 'proj-1',
        taskId: 'cron-1',
        name: 'Nightly review',
        prompt: 'Review the diff',
        scheduleKind: 'weekly',
        scheduleTime: '02:00',
        weekdays: const [1, 3],
      ),
      isTrue,
    );
    final weekly = transport.calls.lastWhere(
      (call) => call.method == 'PUT' && call.path == OpenChamberPaths.scheduledTasksForProject('proj-1'),
    );
    expect((weekly.body?['task'] as Map)['id'], 'cron-1');
    expect((weekly.body?['task'] as Map)['schedule'], {
      'kind': 'weekly',
      'time': '02:00',
      'weekdays': [1, 3],
    });

    expect(
      await controller.createScheduledTask(
        projectId: 'proj-1',
        taskId: 'cron-1',
        name: 'Nightly review',
        prompt: 'Review the diff',
        scheduleKind: 'cron',
        cron: '0 9 * * 1',
      ),
      isTrue,
    );
    final cron = transport.calls.lastWhere(
      (call) => call.method == 'PUT' && call.path == OpenChamberPaths.scheduledTasksForProject('proj-1'),
    );
    expect((cron.body?['task'] as Map)['schedule'], {'kind': 'cron', 'cron': '0 9 * * 1'});

    expect(await controller.deleteScheduledTask(projectId: 'proj-1', taskId: 'cron-1'), isTrue);
    expect(
      transport.calls.any(
        (call) =>
            call.method == 'DELETE' && call.path == OpenChamberPaths.scheduledTask('proj-1', 'cron-1'),
      ),
      isTrue,
    );
    expect(controller.scheduledTasks.value?.any((item) => item.id == 'cron-1'), isFalse);
  });

  test('revertSession POSTs official /api/session/:id/revert', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    final ok = await controller.revertSession(
      session: const HomeSessionRow(
        id: 'sess-catalog',
        title: 'Catalog',
        projectLabel: 'openchamber',
        kind: HomeSessionKind.catalog,
        directory: '/workspace/openchamber',
      ),
      messageId: 'm3',
    );
    expect(ok, isTrue);
    expect(
      transport.calls.any(
        (call) =>
            call.method == 'POST' &&
            call.path == OpenChamberPaths.sessionRevert('sess-catalog') &&
            call.body?['messageID'] == 'm3',
      ),
      isTrue,
    );
  });

  test('composerSuggestions uses command, file, skill, and snippet catalogs', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    expect(
      (await controller.composerSuggestions(text: '/re')).map((item) => item.label),
      contains('/review'),
    );
    expect(
      (await controller.composerSuggestions(text: '@RE', directory: '/workspace')).map((item) => item.label),
      contains('@README.md'),
    );
    expect(
      (await controller.composerSuggestions(text: 'please /rel')).map((item) => item.label),
      contains('/release-notes'),
    );
    expect(
      (await controller.composerSuggestions(text: '#re')).map((item) => item.label),
      contains('#repro'),
    );
    expect(
      transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.commandsMetadata),
      isTrue,
    );
    expect(
      transport.calls.any((call) => call.method == 'GET' && call.path == OpenChamberPaths.fsList),
      isTrue,
    );
    expect(
      transport.calls.any((call) => call.method == 'GET' && call.path == OpenChamberPaths.skills),
      isTrue,
    );
    expect(
      transport.calls.any((call) => call.method == 'GET' && call.path == OpenChamberPaths.snippets),
      isTrue,
    );
  });

  testWidgets('new worktree existing-branch mode hides startRef and POSTs existingBranch', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home-project-actions-openchamber')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-overflow-newWorktree')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('segment-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('worktree-github-start')), findsNothing);
    expect(find.byKey(const Key('worktree-start-ref-field')), findsNothing);
    expect(find.byKey(const Key('worktree-existing-branch')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('worktree-branch-field')), 'feat/share');
    await tester.tap(find.byKey(const Key('worktree-name-save')));
    await tester.pumpAndSettle();
    final create = env.transport.calls.lastWhere(
      (call) => call.method == 'POST' && call.path == OpenChamberPaths.gitWorktrees,
    );
    expect(create.body?['mode'], 'existing');
    expect(create.body?['existingBranch'], 'feat/share');
    expect(create.query['directory'], '/workspace/openchamber');
  });

  testWidgets('scheduled ellipsis opens editor and PUTs weekly kind', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('tab-scheduled')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scheduled-run-now-cron-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scheduled-task-actions-cron-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scheduled-action-edit-cron-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scheduled-create-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scheduled-create-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scheduled-create-save')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) =>
            call.method == 'PUT' &&
            call.path == OpenChamberPaths.scheduledTasksForProject('proj-1') &&
            call.body?['task'] is Map &&
            (call.body?['task'] as Map)['id'] == 'cron-1' &&
            ((call.body?['task'] as Map)['schedule'] as Map)['kind'] == 'weekly',
      ),
      isTrue,
    );
  });

  testWidgets('chat user toolbar revert POSTs /api/session/:id/revert', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('chat-action-revert')).first);
    await tester.tap(find.byKey(const Key('chat-action-revert')).first);
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) =>
            call.method == 'POST' &&
            call.path == OpenChamberPaths.sessionRevert('sess-catalog') &&
            (call.body?['messageID'] == 'm1' || call.body?['messageID'] == 'm3'),
      ),
      isTrue,
    );
  });

  testWidgets('assistant long-press edit opens Settings assistants', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('tab-assistant')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const Key('assistant-item-asst-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-menu-asst-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-menu-edit-asst-1')));
    await tester.pumpAndSettle();
    expect(find.text('Assistants'), findsWidgets);
  });

  test('deleteAssistantRecord DELETEs the official assistant path', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.loadAssistantSnapshot();
    final assistant = controller.assistantSnapshot.value!.assistants.single;
    expect(await controller.deleteAssistantRecord(assistant), isTrue);
    expect(
      transport.calls.any(
        (call) => call.method == 'DELETE' && call.path == OpenChamberPaths.assistant('asst-1'),
      ),
      isTrue,
    );
    expect(controller.assistantSnapshot.value?.assistants, isEmpty);
  });
}
