import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/features/chat/inline_markdown_text.dart';
import 'package:openchamber/theme/app_theme.dart';

void main() {
  testWidgets('InlineMarkdownText renders backtick spans as monospace chips', (tester) async {
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

    expect(find.text('ToolPart'), findsOneWidget);
    final chip = tester.widget<Text>(find.text('ToolPart'));
    expect(chip.style?.fontFamily, 'monospace');
    expect(chip.style?.backgroundColor, isNotNull);
    expect(find.textContaining('已跑:'), findsOneWidget);
  });
}
