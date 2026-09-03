import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/features/chat/reasoning_block.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/motion/oc_motion.dart';
import 'package:openchamber/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const longReasoning =
      'First thought about the task at hand and how to approach it carefully.\n'
      'This second line goes into much deeper detail about the internal reasoning '
      'process that should remain hidden in the collapsed header view.';

  test('summary strips markdown and truncates at 80 like official ReasoningPart', () {
    final summary = reasoningSummary(longReasoning);
    expect(summary, contains('First thought'));
    expect(summary, isNot(contains('remain hidden in the collapsed header view')));
    expect(summary.endsWith('…'), isTrue);
    expect(reasoningSummary('Planning labels <!-- -->'), 'Planning labels');
  });

  test('official motion tokens match ReasoningPart.tsx', () {
    expect(OcMotion.reasoningExpand, const Duration(milliseconds: 200));
    expect(OcMotion.reasoningContentFade, const Duration(milliseconds: 180));
    expect(OcMotion.reasoningUnmountDelay, const Duration(milliseconds: 200));
    expect(OcMotion.reasoningExpandedMaxHeight, 320);
    expect(OcMotion.reasoningContentSlidePx, 4);
    expect(identical(OcMotion.reasoningExpandEase, Curves.easeOut), isTrue);
  });

  testWidgets('settled reasoning is collapsed and does not mount Markdown', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ReasoningTraceBlock(
          part: ChatPart(
            id: 'r1',
            kind: ChatPartKind.reasoning,
            title: 'thinking',
            body: longReasoning,
            status: 'completed',
          ),
        ),
      ),
    );

    expect(find.text('Thought'), findsOneWidget);
    expect(find.textContaining('First thought'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.textContaining('remain hidden in the collapsed header view'), findsNothing);
    expect(find.byKey(const Key('chat-reasoning-toggle-r1')), findsOneWidget);
  });

  testWidgets('expand mounts Markdown and collapse unmounts after 200ms', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ReasoningTraceBlock(
          part: ChatPart(
            id: 'r2',
            kind: ChatPartKind.reasoning,
            title: 'thinking',
            body: longReasoning,
            status: 'completed',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('chat-reasoning-toggle-r2')));
    await tester.pump();
    await tester.pump(OcMotion.reasoningExpand);
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('remain hidden in the collapsed header view'), findsWidgets);

    await tester.tap(find.byKey(const Key('chat-reasoning-toggle-r2')));
    await tester.pump();
    await tester.pump(OcMotion.reasoningExpand);
    await tester.pump(OcMotion.reasoningUnmountDelay);
    expect(find.byType(MarkdownBody), findsNothing);
  });

  testWidgets('streaming reasoning starts expanded', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ReasoningTraceBlock(
          isLive: true,
          part: ChatPart(
            id: 'r3',
            kind: ChatPartKind.reasoning,
            title: 'thinking',
            body: 'Thinking about the next edit.',
            status: 'streaming',
          ),
        ),
      ),
    );
    expect(find.text('Thinking'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: materialTheme(Brightness.light),
    home: StringsScope(
      strings: AppStrings.of(AppStrings.en),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}
