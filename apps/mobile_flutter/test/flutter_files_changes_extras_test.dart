import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/file_preview.dart';
import 'package:openchamber/data/git_commit_generate.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/files/changes_sheet.dart';
import 'package:openchamber/features/files/files_browser_sheet.dart';
import 'package:openchamber/l10n/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({AppController controller, MemoryOpenChamberTransport transport})> connected() async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    return (controller: controller, transport: transport);
  }

  Future<void> pumpSheet(WidgetTester tester, Widget sheet) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 720, height: 900, child: sheet)),
      ),
    );
    await tester.pump();
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
    final env = await connected();
    final results = await env.controller.searchFilesystemFiles(directory: '/workspace/openchamber', query: 'READ');
    expect(results.single.relativePath, 'README.md');
    expect(results.single.path, '/workspace/openchamber/README.md');
    final call = env.transport.calls.singleWhere((item) => item.path == OpenChamberPaths.findFile);
    expect(call.query['dirs'], 'false');
    expect(call.query['type'], 'file');
    expect(call.query['limit'], '40');
    expect(call.query['directory'], '/workspace/openchamber');
    expect(call.query['query'], 'READ');
  });

  test('generate / revert / sync / commit-and-push hit official paths', () async {
    final env = await connected();
    expect(await env.controller.revertGitChanges('/workspace/openchamber', 'README.md'), isTrue);
    expect(
      env.transport.calls.any((call) => call.path == OpenChamberPaths.gitRevert && call.body?['path'] == 'README.md'),
      isTrue,
    );
    env.transport.gitStatusFiles = [
      {'path': 'README.md', 'index': 'M', 'working_dir': ''},
    ];
    final generated = await env.controller.generateGitCommitMessage(directory: '/workspace/openchamber', files: ['README.md']);
    expect(generated?.subject, 'docs: note');
    expect(
      env.transport.calls.any((call) => call.path == OpenChamberPaths.smallModelGenerate && call.body?['purpose'] == 'commit'),
      isTrue,
    );
    env.transport.gitAhead = 1;
    expect(await env.controller.syncGitChanges('/workspace/openchamber'), isTrue);
    expect(env.transport.calls.any((call) => call.path == OpenChamberPaths.gitFetch), isTrue);
    expect(env.transport.calls.any((call) => call.path == OpenChamberPaths.gitPush), isTrue);
    env.transport.gitStatusFiles = [
      {'path': 'README.md', 'index': 'M', 'working_dir': ''},
    ];
    env.transport.gitAhead = 1;
    expect(
      await env.controller.commitAndPushGitChanges('/workspace/openchamber', 'docs: note', files: ['README.md']),
      isTrue,
    );
    expect(
      env.transport.calls.any(
        (call) => call.path == OpenChamberPaths.gitCommit && (call.body?['files'] as List).contains('README.md'),
      ),
      isTrue,
    );
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

  testWidgets('Files preview copies the absolute path', (tester) async {
    final env = await connected();
    await pumpSheet(tester, FilesBrowserSheet(controller: env.controller, root: '/workspace/openchamber'));
    expect(find.byKey(const Key('files-browser-search')), findsOneWidget);
    expect(find.text(AppStrings.of(AppStrings.en).t('mobile.files.search.placeholder')), findsOneWidget);
    await tester.tap(find.byKey(const Key('files-browser-entry-README.md')));
    await tester.pump();
    expect(find.byKey(const Key('files-browser-preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('files-browser-copy-path')));
    await tester.pump();
    expect(env.transport.calls.any((call) => call.path == OpenChamberPaths.fsRead), isTrue);
    expect(find.byKey(const Key('files-browser-copy-content')), findsOneWidget);
  });

  testWidgets('image files preview via /api/fs/raw not /api/fs/read', (tester) async {
    final env = await connected();
    await pumpSheet(tester, FilesBrowserSheet(controller: env.controller, root: '/workspace/openchamber'));
    await tester.tap(find.byKey(const Key('files-browser-entry-photo.png')));
    await tester.pump();
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

  testWidgets('Changes revert uses POST /api/git/revert', (tester) async {
    final env = await connected();
    await pumpSheet(tester, ChangesSheet(controller: env.controller, directory: '/workspace/openchamber'));
    expect(find.text(AppStrings.of(AppStrings.en).t('gitView.commit.messagePlaceholder')), findsOneWidget);
    await tester.tap(find.byKey(const Key('changes-revert-README.md')));
    await tester.pump();
    expect(
      env.transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.gitRevert && call.body?['path'] == 'README.md',
      ),
      isTrue,
    );
  });

  testWidgets('Changes generate + commit-and-push use small-model and git files', (tester) async {
    final env = await connected();
    await pumpSheet(tester, ChangesSheet(controller: env.controller, directory: '/workspace/openchamber'));
    await tester.tap(find.byKey(const Key('changes-stage-README.md')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('changes-generate')));
    await tester.tap(find.byKey(const Key('changes-generate')));
    await tester.pump();
    final generate = env.transport.calls.singleWhere((call) => call.path == OpenChamberPaths.smallModelGenerate);
    expect(generate.method, 'POST');
    expect(generate.body?['purpose'], 'commit');
    expect(generate.body?['directory'], '/workspace/openchamber');
    expect(find.text('docs: note'), findsOneWidget);
    expect(find.byKey(const Key('changes-highlights')), findsOneWidget);

    env.transport.gitAhead = 1;
    await tester.ensureVisible(find.byKey(const Key('changes-commit-push')));
    await tester.tap(find.byKey(const Key('changes-commit-push')));
    await tester.pump();
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
    expect(env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.gitFetch), isTrue);
    expect(env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.gitPush), isTrue);
  });

  testWidgets('Changes header sync fetches then pushes when ahead', (tester) async {
    final env = await connected();
    await pumpSheet(tester, ChangesSheet(controller: env.controller, directory: '/workspace/openchamber'));
    await tester.tap(find.byKey(const Key('changes-sync')));
    await tester.pump();
    expect(env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.gitFetch), isTrue);
    expect(env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.gitPush), isTrue);
  });
}
