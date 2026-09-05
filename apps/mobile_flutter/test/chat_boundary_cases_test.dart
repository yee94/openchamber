import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/chat_parts.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/features/chat/chat_markdown_body.dart';
import 'package:openchamber/features/chat/chat_screen.dart';
import 'package:openchamber/features/chat/tool_cards.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const session = HomeSessionRow(
    id: 'sess-boundary',
    title: 'Boundary',
    projectLabel: 'OpenChamber',
    kind: HomeSessionKind.catalog,
  );

  test('parse keeps official reasoning / aborted / empty parts', () {
    final reasoning = parseReasoningPart(
      {
        'type': 'reasoning',
        'text': '> thinking aloud',
        'time': {'start': 1},
      },
      id: 'r-live',
    );
    expect(reasoning?.kind, ChatPartKind.reasoning);
    expect(reasoning?.status, 'streaming');
    expect(reasoning?.body, contains('thinking aloud'));

    expect(resolveAssistantError({'name': 'MessageAbortedError', 'message': 'aborted'}, null)?.kind, 'aborted');
    expect(resolveAssistantError({'name': 'Other', 'message': 'boom'}, null)?.kind, 'error');
    expect(resolveAssistantError(null, 'aborted')?.kind, 'aborted');

    final messages = parseTurnPageMessages({
      'records': [
        {
          'info': {'id': 'empty', 'role': 'assistant', 'finish': 'stop'},
          'parts': [],
        },
        {
          'info': {
            'id': 'aborted',
            'role': 'assistant',
            'error': {'name': 'MessageAbortedError', 'message': 'aborted'},
          },
          'parts': [
            {'id': 't', 'type': 'text', 'text': ''},
          ],
        },
        {
          'info': {'id': 'think', 'role': 'assistant'},
          'parts': [
            {'id': 'r', 'type': 'reasoning', 'text': 'plan', 'time': {'start': 1, 'end': 2}},
            {'id': 't', 'type': 'text', 'text': '## Done'},
          ],
        },
      ],
    });
    expect(messages.any((message) => message.id == 'empty' && message.body.isEmpty), isTrue);
    expect(messages.singleWhere((message) => message.id == 'aborted').errorKind, 'aborted');
    expect(messages.singleWhere((message) => message.id == 'think').parts.any((part) => part.kind == ChatPartKind.reasoning), isTrue);
  });

  testWidgets('empty, aborted, mixed, and wall-of-text rows stay mounted', (tester) async {
    final wall = ChatMessage(
      id: 'wall',
      body: '',
      isUser: false,
      parts: [
        ChatPart(
          id: 'wall-text',
          kind: ChatPartKind.text,
          title: 'text',
          body: '# Wall\n\n${'word ' * 400}\n\n```\n${'line\n' * 80}```',
        ),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            ChatTranscriptBody(message: ChatMessage(id: 'empty', body: '', isUser: false)),
            ChatTranscriptBody(
              message: ChatMessage(id: 'aborted', body: '', isUser: false, errorKind: 'aborted'),
            ),
            ChatTranscriptBody(
              message: ChatMessage(
                id: 'mixed',
                body: 'Here is the answer.',
                isUser: false,
                parts: [
                  ChatPart(id: 'r', kind: ChatPartKind.reasoning, title: 'thinking', body: 'Hidden plan.', status: 'completed'),
                  ChatPart(id: 't', kind: ChatPartKind.text, title: 'text', body: 'Here is the **answer**.'),
                  ChatPart(id: 'img', kind: ChatPartKind.fileOp, title: 'shot.png', toolName: 'image-preview', metadata: {'mime': 'image/png'}),
                  ChatPart(id: 'bash', kind: ChatPartKind.tool, title: 'ls', status: 'completed', toolName: 'bash', body: 'ok'),
                ],
              ),
            ),
            ChatTranscriptBody(message: wall),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('chat-aborted-aborted')), findsOneWidget);
    expect(find.text('Generation stopped'), findsOneWidget);
    expect(find.text('Thought'), findsOneWidget);
    expect(find.textContaining('answer'), findsWidgets);
    expect(find.byKey(const Key('chat-tool-image-img')), findsOneWidget);
    expect(find.byKey(const Key('chat-activity-mixed')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-activity-mixed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-tool-bash-bash')), findsOneWidget);
    expect(find.byType(MarkdownBody), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolled-up SSE apply does not yank; jump-to-bottom resumes follow', (tester) async {
    final timeline = ReverseChatController(
      seed: [
        for (var i = 0; i < 12; i += 1)
          ChatMessage(id: 'm$i', body: 'Message $i\n\n${'line\n' * 8}', isUser: i.isEven),
      ],
    );
    addTearDown(timeline.dispose);

    await tester.pumpWidget(
      _chat(
        session: session,
        timeline: timeline,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final position = _chatPosition(tester);
    expect(position.pixels, lessThan(24));

    position.jumpTo(280);
    await tester.pump();
    expect(position.pixels, closeTo(280, 1));

    final before = position.pixels;
    timeline.applyMessages([
      ...timeline.oldestFirst,
      const ChatMessage(id: 'tail', body: '**fresh** token', isUser: false),
    ]);
    await tester.pump();
    expect(position.pixels, greaterThan(24), reason: 'must not pin to live edge while the user is reading above');
    expect((position.pixels - before).abs(), lessThan(80));

    await tester.tap(find.byKey(const Key('chat-scroll-to-bottom')));
    await tester.pump();
    expect(_chatPosition(tester).pixels, lessThan(24));
  });

  testWidgets('at live edge, growing the last message stays pinned at 0', (tester) async {
    final timeline = ReverseChatController(
      seed: const [
        ChatMessage(id: 'u', body: 'go', isUser: true),
        ChatMessage(id: 'a', body: 'Hello', isUser: false, parts: [ChatPart(id: 't', kind: ChatPartKind.text, title: 'text', body: 'Hello')]),
      ],
    );
    addTearDown(timeline.dispose);
    await tester.pumpWidget(_chat(session: session, timeline: timeline));
    await tester.pump();

    timeline.applyMessages([
      const ChatMessage(id: 'u', body: 'go', isUser: true),
      const ChatMessage(
        id: 'a',
        body: 'Hello **world** and more',
        isUser: false,
        parts: [ChatPart(id: 't', kind: ChatPartKind.text, title: 'text', body: 'Hello **world** and more')],
      ),
    ]);
    await tester.pump();
    await tester.pump(ChatMarkdownBody.livePace);
    expect(timeline.structureNotifyCount, 0);
    expect(_chatPosition(tester).pixels, lessThan(24));
    expect(find.textContaining('world'), findsWidgets);
  });
}

ScrollPosition _chatPosition(WidgetTester tester) {
  return tester.widget<ListView>(find.byKey(const Key('reverse-chat-list'))).controller!.position;
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

Widget _chat({required HomeSessionRow session, required ReverseChatController timeline}) {
  return MaterialApp(
    theme: materialTheme(Brightness.light),
    home: StringsScope(
      strings: AppStrings.of(AppStrings.en),
      child: ChatScreen(session: session, timeline: timeline),
    ),
  );
}
