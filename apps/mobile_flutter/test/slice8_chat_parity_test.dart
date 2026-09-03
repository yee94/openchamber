import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/chat_parts.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/data/context_tool_grouping.dart';
import 'package:openchamber/features/chat/tool_cards.dart';
import 'package:openchamber/l10n/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('context grouping collapses consecutive read/glob/grep/list only', () {
    final parts = parseChatParts(
      [
        {'id': 'r1', 'type': 'tool', 'tool': 'read', 'state': {'status': 'completed', 'input': {'path': 'a.dart'}}},
        {'id': 'g1', 'type': 'tool', 'tool': 'grep', 'state': {'status': 'completed', 'input': {'pattern': 'foo'}}},
        {'id': 'l1', 'type': 'tool', 'tool': 'list', 'state': {'status': 'completed', 'input': {'path': '.'}}},
        {'id': 'b1', 'type': 'tool', 'tool': 'bash', 'state': {'status': 'completed', 'input': {'command': 'ls'}}},
        {'id': 'r2', 'type': 'tool', 'tool': 'read', 'state': {'status': 'running', 'input': {'path': 'b.dart'}}},
      ],
      messageId: 'm',
    );
    final first = collectConsecutiveContextTools(parts, 0);
    expect(first.items.map((part) => part.id), ['r1', 'g1', 'l1']);
    expect(first.end, 3);
    expect(isContextGroupTool(parts[3].toolName), isFalse);
    final second = collectConsecutiveContextTools(parts, 4);
    expect(second.items.single.id, 'r2');
    expect(
      isContextGroupExploring(parts: second.items, hasFollowingOtherType: false, isTurnLive: true),
      isTrue,
    );
    expect(
      isContextGroupExploring(parts: first.items, hasFollowingOtherType: true, isTurnLive: true),
      isFalse,
    );
    final counts = summarizeContextTools(first.items.map((part) => part.toolName));
    expect(counts.read, 1);
    expect(counts.search, 1);
    expect(counts.list, 1);
  });

  test('mermaid fences become first-class parts and leave remaining text', () {
    final parts = splitTextAndMermaid(
      'Intro\n```mermaid\ngraph TD\n  A-->B\n```\nOutro',
      id: 'text-1',
    );
    expect(parts.where((part) => part.kind == ChatPartKind.text).map((part) => part.body), ['Intro', 'Outro']);
    expect(parts.singleWhere((part) => part.kind == ChatPartKind.mermaid).body, contains('graph TD'));
    expect(parts.any((part) => part.kind == ChatPartKind.mermaid && part.body!.contains('```')), isFalse);
  });

  test('unified diff keeps interleaved add/remove lines for live viewer', () {
    final diff = parseUnifiedDiff('--- a/x\n+++ b/x\n@@\n context\n-old\n+new\n');
    expect(diff.removed, ['old']);
    expect(diff.added, ['new']);
    expect(diff.lines.map((line) => '${line.kind}:${line.text}'), ['context:context', 'remove:old', 'add:new']);
  });

  testWidgets('settled activity starts collapsed; live activity stays locked open', (tester) async {
    final settled = ChatMessage(
      id: 'm-settled',
      body: 'Done.',
      isUser: false,
      parts: [
        const ChatPart(id: 't1', kind: ChatPartKind.text, title: 'text', body: 'Done.'),
        const ChatPart(
          id: 'edit-1',
          kind: ChatPartKind.diff,
          title: 'lib/app.dart',
          status: 'completed',
          toolName: 'edit',
          added: ['new'],
          removed: ['old'],
        ),
      ],
    );
    await tester.pumpWidget(_wrap(ChatTranscriptBody(message: settled, isLastAssistant: true)));
    expect(find.text('Done.'), findsOneWidget);
    expect(find.byKey(const Key('chat-activity-m-settled')), findsNothing);
    expect(find.byKey(const Key('chat-tool-diff-edit-1')), findsWidgets);

    final live = ChatMessage(
      id: 'm-live',
      body: '',
      isUser: false,
      parts: const [
        ChatPart(id: 'bash-1', kind: ChatPartKind.tool, title: 'ls', status: 'running', toolName: 'bash'),
      ],
    );
    await tester.pumpWidget(_wrap(ChatTranscriptBody(message: live, isLastAssistant: true, isTurnLive: true)));
    expect(find.text('Working'), findsOneWidget);
    expect(find.byKey(const Key('chat-tool-bash-bash-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-activity-m-live')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-tool-bash-bash-1')), findsOneWidget);
  });

  testWidgets('diff toggle switches unified default to side-by-side', (tester) async {
    final message = ChatMessage(
      id: 'm-diff',
      body: '',
      isUser: false,
      parts: [
        ChatPart(
          id: 'edit-2',
          kind: ChatPartKind.diff,
          title: 'a.dart',
          status: 'completed',
          toolName: 'edit',
          added: const ['new'],
          removed: const ['old'],
          diffLines: const [DiffLine(kind: 'remove', text: 'old'), DiffLine(kind: 'add', text: 'new')],
        ),
      ],
    );
    await tester.pumpWidget(_wrap(ChatTranscriptBody(message: message, isLastAssistant: true)));
    expect(find.byKey(const Key('chat-tool-diff-edit-2')), findsOneWidget);
    expect(find.text('- old'), findsOneWidget);
    expect(find.text('+ new'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-diff-toggle-edit-2')));
    await tester.pumpAndSettle();
    expect(find.text('- old'), findsOneWidget);
    expect(find.text('+ new'), findsOneWidget);
  });

  testWidgets('permission card matches official once / always / deny layout', (tester) async {
    final message = ChatMessage(
      id: 'm-perm',
      body: 'Need a shell.',
      isUser: false,
      parts: const [
        ChatPart(id: 't', kind: ChatPartKind.text, title: 'text', body: 'Need a shell.'),
        ChatPart(
          id: 'perm-1',
          kind: ChatPartKind.permission,
          title: 'bash',
          toolName: 'bash',
          permissionId: 'perm-1',
          patterns: ['git status'],
          metadata: {'command': 'git status'},
        ),
      ],
    );
    await tester.pumpWidget(_wrap(ChatTranscriptBody(message: message)));
    expect(find.text('Permission required'), findsOneWidget);
    expect(find.text('Patterns:'), findsOneWidget);
    expect(find.text('git status'), findsWidgets);
    expect(find.text('Allow once'), findsOneWidget);
    expect(find.text('Always agree'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);
    expect(find.byKey(const Key('chat-permission-once')), findsOneWidget);
    expect(find.byKey(const Key('chat-permission-always')), findsOneWidget);
    expect(find.byKey(const Key('chat-permission-reject')), findsOneWidget);
  });

  testWidgets('context group and mermaid cards render instead of raw dumps', (tester) async {
    final messages = parseTurnPageMessages(
      {
        'records': [
          {
            'info': {'id': 'm-parity', 'role': 'assistant'},
            'parts': [
              {
                'type': 'text',
                'text': 'Here is the flow.\n```mermaid\ngraph TD\n  A-->B\n```\n',
              },
              {
                'id': 'read-1',
                'type': 'tool',
                'tool': 'read',
                'state': {'status': 'completed', 'input': {'path': 'lib/app.dart'}},
              },
              {
                'id': 'grep-1',
                'type': 'tool',
                'tool': 'grep',
                'state': {'status': 'completed', 'input': {'pattern': 'ChatScreen'}},
              },
              {
                'id': 'edit-live',
                'type': 'tool',
                'tool': 'edit',
                'state': {
                  'status': 'completed',
                  'input': {'path': 'lib/app.dart'},
                  'output': '--- a/lib/app.dart\n+++ b/lib/app.dart\n-old\n+new\n',
                },
              },
            ],
          },
        ],
      },
      permissions: const [
        PermissionRequestRecord(
          id: 'perm-1',
          sessionId: 'sess-catalog',
          permission: 'bash',
          patterns: ['git status'],
          metadata: {'command': 'git status'},
        ),
      ],
    );
    expect(messages.single.parts.any((part) => part.kind == ChatPartKind.mermaid), isTrue);
    expect(messages.single.parts.any((part) => part.body?.contains('{') == true && part.kind != ChatPartKind.text), isFalse);
    await tester.pumpWidget(_wrap(ChatTranscriptBody(message: messages.single, isLastAssistant: true)));
    expect(find.byKey(const Key('chat-mermaid-m-parity-0-mermaid-0')), findsOneWidget);
    expect(find.textContaining('graph TD'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-activity-m-parity')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-context-group-read-1')), findsOneWidget);
    expect(find.text('Explored'), findsOneWidget);
    expect(find.textContaining('1 search'), findsOneWidget);
    expect(find.textContaining('1 read'), findsOneWidget);
    expect(find.byKey(const Key('chat-tool-diff-edit-live')), findsOneWidget);
    expect(find.byKey(const Key('chat-tool-permission-perm-1')), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: StringsScope(
      strings: AppStrings.of(AppStrings.en),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}
