import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/file_preview.dart';
import 'package:openchamber/data/git_commit_generate.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';
import 'package:openchamber/l10n/app_strings.dart';

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

  Future<void> openFiles(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-overflow-files')));
    await tester.pumpAndSettle();
  }

  Future<void> openChanges(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-overflow-changes')));
    await tester.pumpAndSettle();
  }

  test('isRasterPreviewImage matches Cap image vs svg split', () {
    expect(isImageFile('a.png'), isTrue);
    expect(isRasterPreviewImage('a.png'), isTrue);
    expect(isImageFile('a.svg'), isTrue);
    expect(isRasterPreviewImage('a.svg'), isFalse);
  });

  test('parseGeneratedCommitMessage reads subject and 3 highlights', () {
    final parsed = parseGeneratedCommitMessage('{"subject":"docs: note","highlights":["a","b","c","d"]}');
    expect(parsed.subject, 'docs: note');
    expect(parsed.highlights, ['a', 'b', 'c']);
  });

  test('searchFiles uses official /api/find/file query', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    final results = await controller.searchFilesystemFiles(directory: '/workspace/openchamber', query: 'READ');
    expect(results.single.relativePath, 'README.md');
    expect(results.single.path, '/workspace/openchamber/README.md');
    final call = transport.calls.singleWhere((item) => item.path == OpenChamberPaths.findFile);
    expect(call.query['dirs'], 'false');
    expect(call.query['type'], 'file');
    expect(call.query['limit'], '40');
    expect(call.query['directory'], '/workspace/openchamber');
    expect(call.query['query'], 'READ');
  });

  test('failed file search is not empty success', () async {
    final transport = MemoryOpenChamberTransport()..fsStatus = 500;
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await expectLater(
      controller.searchFilesystemFiles(directory: '/workspace/openchamber', query: 'READ'),
      throwsA(isA<OpenChamberHttpException>()),
    );
  });

  testWidgets('Files search opens a result and copies the absolute path', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    await openFiles(tester);
    await tester.enterText(find.byKey(const Key('files-browser-search')), 'READ');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('files-browser-search-README.md')), findsOneWidget);
    await tester.tap(find.byKey(const Key('files-browser-search-README.md')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('files-browser-preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('files-browser-copy-path')));
    await tester.pumpAndSettle();
    final copied = await Clipboard.getData('text/plain');
    expect(copied?.text, '/workspace/openchamber/README.md');
    expect(find.text('Path copied'), findsOneWidget);
  });

  testWidgets('image files preview via /api/fs/raw not /api/fs/read', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final env = await pumpApp(tester);
    await openFiles(tester);
    await tester.tap(find.byKey(const Key('files-browser-entry-photo.png')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('files-browser-image')), findsOneWidget);
    expect(find.byKey(const Key('files-browser-copy-content')), findsNothing);
    expect(
      env.transport.calls.any((call) => call.method == 'GET' && call.path == OpenChamberPaths.fsRaw && call.query['path'] == '/workspace/openchamber/photo.png'),
      isTrue,
    );
    expect(
      env.transport.calls.any((call) => call.path == OpenChamberPaths.fsRead && call.query['path'] == '/workspace/openchamber/photo.png'),
      isFalse,
    );
  });

  testWidgets('Changes generate / revert / sync / commit-and-push hit official git paths', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final env = await pumpApp(tester);
    await openChanges(tester);
    expect(find.text(AppStrings.of(AppStrings.en).t('gitView.commit.messagePlaceholder')), findsOneWidget);

    await tester.tap(find.byKey(const Key('changes-revert-README.md')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.gitRevert && call.body?['path'] == 'README.md',
      ),
      isTrue,
    );

    env.transport.gitStatusFiles = [
      {'path': 'README.md', 'index': '', 'working_dir': 'M'},
    ];
    await tester.tap(find.byKey(const Key('changes-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-overflow-changes')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('changes-stage-README.md')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changes-generate')));
    await tester.pumpAndSettle();
    final generate = env.transport.calls.singleWhere((call) => call.path == OpenChamberPaths.smallModelGenerate);
    expect(generate.method, 'POST');
    expect(generate.body?['purpose'], 'commit');
    expect(generate.body?['directory'], '/workspace/openchamber');
    expect(find.text('docs: note'), findsOneWidget);
    expect(find.byKey(const Key('changes-highlights')), findsOneWidget);

    await tester.tap(find.byKey(const Key('changes-sync')));
    await tester.pumpAndSettle();
    expect(env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.gitFetch), isTrue);
    expect(env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.gitPush), isTrue);

    env.transport.gitAhead = 1;
    await tester.tap(find.byKey(const Key('changes-commit-push')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) =>
            call.method == 'POST' &&
            call.path == OpenChamberPaths.gitCommit &&
            call.body?['message'] == 'docs: note' &&
            (call.body?['files'] as List).contains('README.md'),
      ),
      isTrue,
    );
  });
}
