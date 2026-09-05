import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/composer_autocomplete.dart';
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

  test('applyComposerSuggestion replaces only the trigger token', () {
    expect(applyComposerSuggestion('/re', '/review'), '/review ');
    expect(applyComposerSuggestion('please /rel', '/release-notes'), 'please /release-notes ');
    expect(applyComposerSuggestion('see @RE', '@README.md'), 'see @README.md ');
    expect(applyComposerSuggestion('#re', '#repro'), '#repro ');
  });

  test('git status / stage / commit use official /api/git paths', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    final status = await controller.loadGitStatus('/workspace/openchamber');
    expect(status.current, 'main');
    expect(status.files.single.path, 'README.md');
    expect(status.files.single.unstaged, isTrue);
    expect(await controller.stageGitPaths('/workspace/openchamber', ['README.md']), isTrue);
    expect(
      transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.gitStage && (call.body?['paths'] as List).contains('README.md'),
      ),
      isTrue,
    );
    expect(await controller.commitGitChanges('/workspace/openchamber', 'docs: note'), isTrue);
    expect(
      transport.calls.any(
        (call) =>
            call.method == 'POST' &&
            call.path == OpenChamberPaths.gitCommit &&
            call.body?['message'] == 'docs: note',
      ),
      isTrue,
    );
  });

  test('MCP connect/disconnect hit official /api/mcp/:name paths', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    expect((await controller.loadMcpRuntimeStatus())['filesystem']?.connected, isTrue);
    expect(await controller.setMcpRuntimeConnected(name: 'filesystem', connected: false), isTrue);
    expect(
      transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.mcpDisconnect('filesystem')),
      isTrue,
    );
    expect(await controller.setMcpRuntimeConnected(name: 'filesystem', connected: true), isTrue);
    expect(
      transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.mcpConnect('filesystem')),
      isTrue,
    );
  });

  testWidgets('chat overflow opens Cap Files / Changes / MCP / New session', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-overflow-newSession')), findsOneWidget);
    expect(find.byKey(const Key('session-overflow-files')), findsOneWidget);
    expect(find.byKey(const Key('session-overflow-changes')), findsOneWidget);
    expect(find.byKey(const Key('session-overflow-mcp')), findsOneWidget);
    expect(find.byKey(const Key('session-overflow-rename')), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-overflow-files')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('files-browser-sheet')), findsOneWidget);
    expect(find.byKey(const Key('files-browser-entry-README.md')), findsOneWidget);
    await tester.tap(find.byKey(const Key('files-browser-entry-README.md')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('files-browser-preview')), findsOneWidget);
    expect(find.textContaining('Flutter native'), findsOneWidget);
    await tester.tap(find.byKey(const Key('files-browser-close')));
    await tester.pumpAndSettle();
  });

  testWidgets('chat overflow Changes stages and commits via official git paths', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-overflow-changes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('changes-sheet')), findsOneWidget);
    expect(find.byKey(const Key('changes-file-README.md')), findsOneWidget);
    await tester.tap(find.byKey(const Key('changes-stage-README.md')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.gitStage),
      isTrue,
    );
    await tester.enterText(find.byKey(const Key('changes-commit-message')), 'docs: note');
    await tester.tap(find.byKey(const Key('changes-commit')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.gitCommit && call.body?['message'] == 'docs: note',
      ),
      isTrue,
    );
  });

  testWidgets('chat overflow MCP disconnects via official /api/mcp path', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-overflow-mcp')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mcp-overlay-sheet')), findsOneWidget);
    expect(find.byKey(const Key('mcp-overlay-toggle-filesystem')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mcp-overlay-toggle-filesystem')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.mcpDisconnect('filesystem')),
      isTrue,
    );
  });

  testWidgets('chat overflow new session POSTs /api/session', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-overflow-newSession')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionCreate),
      isTrue,
    );
  });

  test('createSession still uses the official session create path', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    final created = await controller.createSession(directory: '/workspace/openchamber');
    expect(created, isA<HomeSessionRow>());
    expect(
      transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionCreate),
      isTrue,
    );
  });
}
