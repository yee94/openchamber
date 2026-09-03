import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/chat_markdown_cache.dart';
import 'package:openchamber/features/chat/chat_markdown_body.dart';
import 'package:openchamber/features/chat/inline_markdown_text.dart';
import 'package:openchamber/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(ChatMarkdownBuildCounters.reset);

  testWidgets('Markdown constructs render as MarkdownBody, not raw markers', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ChatMarkdownBody(
          cacheKey: 'md-constructs',
          text: '''
# Heading one
Paragraph with **bold** and *italic* and `inline`.

- first
- second

> quoted

```
void main() {}
```

[Example](https://example.invalid)
''',
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.byKey(const Key('chat-markdown-md-constructs')), findsOneWidget);
    expect(find.textContaining('Heading one'), findsWidgets);
    expect(find.textContaining('bold'), findsWidgets);
    expect(find.textContaining('italic'), findsWidgets);
    expect(find.textContaining('inline'), findsWidgets);
    expect(find.textContaining('first'), findsWidgets);
    expect(find.textContaining('quoted'), findsWidgets);
    expect(find.textContaining('void main() {}'), findsWidgets);
    expect(find.textContaining('Example'), findsWidgets);
    expect(find.text('# Heading one'), findsNothing);
    expect(find.text('**bold**'), findsNothing);
    expect(find.text('```'), findsNothing);
    expect(find.text('[Example](https://example.invalid)'), findsNothing);
  });

  testWidgets('partial streaming Markdown does not crash', (tester) async {
    await tester.pumpWidget(_wrap(const ChatMarkdownBody(cacheKey: 'live', text: '**bold and', isLive: true)));
    expect(tester.takeException(), isNull);
    expect(find.byType(MarkdownBody), findsOneWidget);

    await tester.pumpWidget(_wrap(const ChatMarkdownBody(cacheKey: 'live', text: '**bold** and ```dart\nint x', isLive: true)));
    await tester.pump(ChatMarkdownBody.livePace);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('bold'), findsWidgets);
  });

  testWidgets('InlineMarkdownText still surfaces inline code through MarkdownBody', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const InlineMarkdownText(
          text: '已跑: `ToolPart` / `toolDiffUtils` / `DiffView` 相关测试。',
        ),
      ),
    );
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('ToolPart'), findsWidgets);
    expect(find.textContaining('已跑:'), findsWidgets);
  });

  testWidgets('identical source rebuilds hit the Markdown cache', (tester) async {
    await tester.pumpWidget(_wrap(const ChatMarkdownBody(cacheKey: 'cache', text: 'Hello **world**')));
    final builds = ChatMarkdownBuildCounters.builds;
    expect(builds, greaterThan(0));
    await tester.pumpWidget(_wrap(const ChatMarkdownBody(cacheKey: 'cache', text: 'Hello **world**')));
    await tester.pump();
    expect(ChatMarkdownBuildCounters.builds, builds);
    expect(ChatMarkdownBuildCounters.reuseHits, greaterThan(0));
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: materialTheme(Brightness.light),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}
