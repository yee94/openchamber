import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/file_preview.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/features/files/html_preview_sheet.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isHtmlFile matches official html/htm only', () {
    expect(isHtmlFile('docs/index.html'), isTrue);
    expect(isHtmlFile(r'C:\site\home.HTM'), isTrue);
    expect(isHtmlFile('README.md'), isFalse);
    expect(isHtmlFile('image.png'), isFalse);
  });

  test('linkHtmlFileReferences underlines bare HTML paths', () {
    expect(linkHtmlFileReferences('See docs/index.html please'), contains('[docs/index.html](docs/index.html)'));
    expect(linkHtmlFileReferences('[docs/index.html](docs/index.html)'), '[docs/index.html](docs/index.html)');
  });

  test('shouldHandPreviewPanToSheet only at the top on a downward pan', () {
    expect(shouldHandPreviewPanToSheet(0, 12), isTrue);
    expect(shouldHandPreviewPanToSheet(0.4, 8), isTrue);
    expect(shouldHandPreviewPanToSheet(2, 12), isFalse);
    expect(shouldHandPreviewPanToSheet(0, -8), isFalse);
    expect(shouldHandPreviewPanToSheet(0, 0), isFalse);
  });

  test('memory transport serves official fs/read and fs/serve paths', () async {
    final transport = MemoryOpenChamberTransport();
    final api = OpenChamberApi(transport: transport);
    final html = await api.readFile(
      base: Uri.parse('http://192.168.1.74:2606'),
      bearer: 'oc_client_test',
      path: '/workspace/openchamber/docs/index.html',
    );
    expect(html, contains('<h1>Preview</h1>'));
    expect(transport.calls.last.path, OpenChamberPaths.fsRead);
    expect(OpenChamberPaths.fsServe('/workspace/openchamber/docs/index.html'), '/api/fs/serve/workspace/openchamber/docs/index.html');
  });

  testWidgets('HTML preview sheet is flush to the physical bottom and can open source + fullscreen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings.of(AppStrings.en),
        child: MaterialApp(
          theme: materialTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('open-html'),
                  onPressed: () {
                    showHtmlPreviewSheet(
                      context: context,
                      path: '/workspace/openchamber/docs/index.html',
                      loadContent: (_) async => '<!doctype html><html><body>Hello</body></html>',
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-html')));
    await tester.pumpAndSettle();

    final sheet = tester.getRect(find.byKey(const Key('html-preview-sheet')));
    expect(sheet.bottom, 844);
    expect(find.byKey(const Key('html-preview-physical-bottom')), findsOneWidget);
    expect(find.byKey(const Key('html-preview-frame')), findsOneWidget);

    await tester.tap(find.byKey(const Key('html-preview-source')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('html-preview-source-body')), findsOneWidget);
    expect(find.textContaining('<!doctype html>'), findsOneWidget);

    await tester.tap(find.byKey(const Key('html-preview-fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('html-preview-fullscreen-surface')), findsOneWidget);

    await tester.tap(find.byKey(const Key('html-preview-exit-fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('html-preview-fullscreen-surface')), findsNothing);
    expect(find.byKey(const Key('html-preview-sheet')), findsOneWidget);
  });

  testWidgets('pull/release at the top of the preview stays on the sheet', (tester) async {
    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings.of(AppStrings.en),
        child: MaterialApp(
          theme: materialTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: HtmlPreviewSheet(
                path: 'docs/index.html',
                loadContent: (_) async => '<p>top</p>\n<p>more</p>',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('html-preview-sheet')), findsOneWidget);
    await tester.drag(find.byKey(const Key('html-preview-frame')), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('html-preview-sheet')), findsOneWidget);
  });

  testWidgets('preview mode hosts the platform surface; source stays selectable text', (tester) async {
    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings.of(AppStrings.en),
        child: MaterialApp(
          theme: materialTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: HtmlPreviewSheet(
                path: 'docs/index.html',
                loadContent: (_) async => '<h1>Preview</h1>',
                usePlatformView: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('html-preview-frame')), findsOneWidget);
    expect(find.byKey(const Key('html-preview-platform')), findsOneWidget);
    expect(find.byKey(const Key('html-preview-source-body')), findsNothing);

    await tester.tap(find.byKey(const Key('html-preview-source')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('html-preview-source-body')), findsOneWidget);
    expect(find.byKey(const Key('html-preview-platform')), findsNothing);
    expect(find.textContaining('<h1>Preview</h1>'), findsOneWidget);

    await tester.tap(find.byKey(const Key('html-preview-source')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('html-preview-platform')), findsOneWidget);
    expect(find.byKey(const Key('html-preview-source-body')), findsNothing);
  });
}
