import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/project_id.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/projects/explorer_paths.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SecondaryChrome.debugReset);

  Future<({AppController controller, MemoryOpenChamberTransport transport})> pumpHome(WidgetTester tester) async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    return (controller: controller, transport: transport);
  }

  test('explorer hidden/parent helpers match DirectoryExplorer mobile rules', () {
    expect(isHiddenDirectoryName('.hidden'), isTrue);
    expect(isHiddenDirectoryName('notes'), isFalse);
    expect(browseParentPath('/workspace/notes'), '/workspace');
    expect(browseParentPath('/workspace'), '/');
    expect(browseParentPath('/'), isNull);
    expect(
      pathAlreadyAdded([
        {'path': '/workspace/notes'},
      ], '/workspace/notes/'),
      isTrue,
    );
  });

  test('createProjectIdFromPath matches official path_ base64url ids', () {
    expect(createProjectIdFromPath('/workspace/notes'), startsWith('path_'));
    expect(createProjectIdFromPath('/workspace/notes'), isNot(contains('=')));
    expect(deriveProjectLabel('/workspace/notes'), 'notes');
  });

  test('addProject PUTs settings projects and does not snackbar-only', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    final ok = await controller.addProject(path: '/workspace/notes', label: 'Notes');
    expect(ok, isTrue);
    final put = transport.calls.lastWhere((call) => call.method == 'PUT' && call.path == OpenChamberPaths.configSettings);
    final projects = put.body?['projects'];
    expect(projects, isA<List>());
    expect(
      (projects as List).any((item) => item is Map && item['path'] == '/workspace/notes' && item['label'] == 'Notes'),
      isTrue,
    );
    expect(controller.settingsProjectRecords().any((item) => item['path'] == '/workspace/notes'), isTrue);
  });

  testWidgets('plus menu opens the new-project sheet against /api/fs/home', (tester) async {
    final env = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('projects-plus-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Project'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-project-sheet')), findsOneWidget);
    expect(env.transport.calls.any((call) => call.path == OpenChamberPaths.fsHome), isTrue);
    expect(find.byKey(const Key('new-project-path')), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-project-entry-notes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-project-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-project-sheet')), findsNothing);
    expect(
      env.transport.calls.any((call) => call.method == 'PUT' && call.path == OpenChamberPaths.configSettings),
      isTrue,
    );
  });

  testWidgets('home session overflow wires pin against the official path', (tester) async {
    final env = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('home-session-actions-sess-catalog')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-overflow-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-overflow-pin')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionIndexPin('sess-catalog'),
      ),
      isTrue,
    );
    expect(env.controller.sessionById('sess-catalog')?.kind.toString(), contains('pinned'));
  });

  testWidgets('session overflow share hits official POST /share', (tester) async {
    final env = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('home-session-actions-sess-catalog')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-overflow-share')), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-overflow-share')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionShare('sess-catalog'),
      ),
      isTrue,
    );
    expect(env.controller.sessionById('sess-catalog')?.shareUrl, 'https://share.example/sess-catalog');
  });

  testWidgets('new-project sheet hides dotfiles until shown and clones through /api/fs/clone', (tester) async {
    final env = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('projects-plus-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Project'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-project-entry-notes')), findsOneWidget);
    expect(find.byKey(const Key('new-project-entry-.hidden')), findsNothing);
    await tester.tap(find.byKey(const Key('new-project-hidden')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-project-entry-.hidden')), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-project-clone-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('new-project-clone-url')), 'git@example.com:org/notes.git');
    await tester.tap(find.byKey(const Key('new-project-add')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) =>
            call.method == 'POST' &&
            call.path == OpenChamberPaths.fsClone &&
            call.body?['remoteUrl'] == 'git@example.com:org/notes.git',
      ),
      isTrue,
    );
  });

  testWidgets('new worktree sheet POSTs branchName and startRef', (tester) async {
    final env = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('home-project-actions-openchamber')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-overflow-newWorktree')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-worktree-sheet')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('worktree-branch-field')), 'feat/gap');
    await tester.enterText(find.byKey(const Key('worktree-start-ref-field')), 'main');
    await tester.tap(find.byKey(const Key('worktree-name-save')));
    await tester.pumpAndSettle();
    final create = env.transport.calls.lastWhere(
      (call) => call.method == 'POST' && call.path == OpenChamberPaths.gitWorktrees,
    );
    expect(create.body?['branchName'], 'feat/gap');
    expect(create.body?['startRef'], 'main');
    expect(create.body?['worktreeName'], 'feat/gap');
    expect(create.body?['mode'], 'new');
  });

  testWidgets('project edit sheet PUTs icon/color and discovers favicon', (tester) async {
    final env = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('home-project-actions-openchamber')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-overflow-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-edit-sheet')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('project-edit-field')), 'OpenChamber');
    await tester.tap(find.byKey(const Key('project-edit-color-primary')));
    await tester.tap(find.byKey(const Key('project-edit-icon-code')));
    await tester.tap(find.byKey(const Key('project-edit-discover')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-edit-save')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.projectIconDiscover('proj-1'),
      ),
      isTrue,
    );
    final put = env.transport.calls.lastWhere((call) => call.method == 'PUT' && call.path == OpenChamberPaths.configSettings);
    final projects = put.body?['projects'] as List;
    expect(
      projects.any((item) => item is Map && item['label'] == 'OpenChamber' && item['icon'] == 'code' && item['color'] == 'primary'),
      isTrue,
    );
  });

  testWidgets('project row actions sheet can create a session in that directory', (tester) async {
    final env = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('home-project-actions-openchamber')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-overflow-sheet')), findsOneWidget);
    expect(find.byKey(const Key('session-overflow-newSession')), findsOneWidget);
    expect(find.byKey(const Key('session-overflow-newWorktree')), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-overflow-newSession')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) =>
            call.method == 'POST' &&
            call.path == OpenChamberPaths.sessionCreate &&
            call.query['directory'] == '/workspace/openchamber',
      ),
      isTrue,
    );
  });
}
