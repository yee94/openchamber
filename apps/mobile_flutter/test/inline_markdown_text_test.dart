import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/features/chat/inline_markdown_text.dart';
import 'package:openchamber/theme/app_theme.dart';

void main() {
  testWidgets('InlineMarkdownText renders backtick spans through MarkdownBody', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: materialTheme(Brightness.light),
        home: const Scaffold(
          body: InlineMarkdownText(
            text: '已跑: `ToolPart` / `toolDiffUtils` / `DiffView` 相关测试。',
          ),
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('ToolPart'), findsWidgets);
    expect(find.textContaining('已跑:'), findsWidgets);
  });
}
