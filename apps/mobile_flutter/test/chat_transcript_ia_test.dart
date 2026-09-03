import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/features/chat/tool_cards.dart';
import 'package:openchamber/l10n/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('activity status is 已处理 once; duration, fork, and +N/-M stay official', (tester) async {
    const message = ChatMessage(
      id: 'm-asst',
      body: 'Done.',
      isUser: false,
      processedLabel: '2m 14s',
      tokensPerSecond: '25.4 tok/s',
      completedClock: '23:24',
      agentCount: 1,
      parts: [
        ChatPart(id: 't1', kind: ChatPartKind.text, title: 'text', body: 'Done.'),
        ChatPart(id: 'task-1', kind: ChatPartKind.task, title: 'patch', status: 'completed', toolName: 'task'),
        ChatPart(
          id: 'edit-1',
          kind: ChatPartKind.diff,
          title: 'DOCUMENTATION.md',
          path: 'DOCUMENTATION.md',
          status: 'completed',
          toolName: 'edit',
          added: ['a', 'b', 'c'],
          removed: ['x'],
        ),
        ChatPart(
          id: 'edit-2',
          kind: ChatPartKind.diff,
          title: 'ToolPart.tsx',
          path: 'ToolPart.tsx',
          status: 'completed',
          toolName: 'edit',
          added: ['n'],
          removed: ['o'],
        ),
      ],
    );
    await tester.pumpWidget(_wrap(const ChatTranscriptBody(message: message, isLastAssistant: true)));

    expect(find.text('已处理'), findsOneWidget);
    expect(find.textContaining('已处理 '), findsNothing);
    expect(find.byKey(const Key('chat-activity-status-m-asst')), findsOneWidget);
    expect(find.byKey(const Key('chat-activity-duration-m-asst')), findsOneWidget);
    expect(find.byKey(const Key('chat-footer-duration-m-asst')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-fork-m-asst')), findsOneWidget);
    expect(find.byKey(const Key('chat-tps-m-asst')), findsOneWidget);
    expect(find.byKey(const Key('chat-file-slash-edit-1')), findsOneWidget);
    expect(find.text('+3/-1', findRichText: true), findsOneWidget);
    expect(find.text('+1/-1', findRichText: true), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: AppStrings.zhCN,
    home: StringsScope(
      strings: AppStrings.of(AppStrings.zhCN),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}
