import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/chat_parts.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/data/generated_result.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/data/skill_tool_grouping.dart';
import 'package:openchamber/features/chat/chat_screen.dart';
import 'package:openchamber/features/chat/tool_cards.dart';
import 'package:openchamber/l10n/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('skill grouping collects consecutive skill tools and names', () {
    final parts = parseChatParts(
      [
        {
          'id': 's1',
          'type': 'tool',
          'tool': 'skill',
          'state': {'status': 'completed', 'input': {'name': 'sync-state-invariants'}},
        },
        {
          'id': 's2',
          'type': 'tool',
          'tool': 'runtime.skill:2',
          'state': {'status': 'completed', 'metadata': {'name': 'diagnosing-bugs'}},
        },
        {
          'id': 'b1',
          'type': 'tool',
          'tool': 'bash',
          'state': {'status': 'completed', 'input': {'command': 'ls'}, 'output': 'app.dart'},
        },
        {
          'id': 's3',
          'type': 'tool',
          'tool': 'skill',
          'state': {'status': 'running', 'input': {'id': 'later-skill'}},
        },
      ],
      messageId: 'm',
    );
    final first = collectConsecutiveSkillTools(parts, 0);
    expect(first.items.map((part) => part.id), ['s1', 's2']);
    expect(isSkillGroupTool(parts[2].toolName), isFalse);
    expect(getSkillNameFromPart(parts[0]), 'sync-state-invariants');
    expect(getSkillNameFromPart(parts[1]), 'diagnosing-bugs');
    final overflow = summarizeSkillNames(['one', 'two', 'three', 'four']);
    expect(overflow.hiddenCount, 1);
    expect(overflow.joinedVisible, 'one, two, three');
  });

  test('bash, webfetch, and websearch keep command/url/query instead of raw JSON', () {
    final parts = parseChatParts(
      [
        {
          'id': 'bash-1',
          'type': 'tool',
          'tool': 'bash',
          'state': {'status': 'completed', 'input': {'command': 'git status'}, 'output': 'clean'},
        },
        {
          'id': 'fetch-1',
          'type': 'tool',
          'tool': 'webfetch',
          'state': {'status': 'completed', 'input': {'url': 'https://example.invalid'}},
        },
        {
          'id': 'search-1',
          'type': 'tool',
          'tool': 'websearch',
          'state': {'status': 'completed', 'input': {'query': 'openchamber mobile'}},
        },
        {
          'id': 'img-1',
          'type': 'file',
          'filename': 'shot.png',
          'mime': 'image/png',
        },
      ],
      messageId: 'm',
    );
    expect(parts.any((part) => isBashTool(part.toolName) && part.title == 'git status'), isTrue);
    expect(parts.any((part) => isWebFetchTool(part.toolName) && part.title.contains('example.invalid')), isTrue);
    expect(parts.any((part) => isWebSearchTool(part.toolName) && part.title == 'openchamber mobile'), isTrue);
    expect(parts.any((part) => part.toolName == 'image-preview' && part.path == 'shot.png'), isTrue);
    expect(parts.any((part) => part.body?.contains('{') == true), isFalse);
  });

  test('generated commit and PR JSON become first-class results', () {
    final commit = parseGeneratedJsonResult('{"subject":"Fix mime isolation","highlights":["iOS","MainActor"]}');
    expect(commit?.kind, 'commit');
    expect(commit?.title, 'Fix mime isolation');
    final pr = parseGeneratedJsonResult('{"title":"Slice 9","body":"Skill grouping"}');
    expect(pr?.kind, 'pr');
    expect(pr?.title, 'Slice 9');
    expect(parseGeneratedJsonResult('plain prose'), isNull);
  });

  testWidgets('skill group, bash, search, and generated cards render', (tester) async {
    final message = ChatMessage(
      id: 'm-slice9',
      body: '{"subject":"Fix mime isolation","highlights":["iOS"]}',
      isUser: false,
      parts: [
        const ChatPart(
          id: 'json-1',
          kind: ChatPartKind.text,
          title: 'text',
          body: '{"subject":"Fix mime isolation","highlights":["iOS"]}',
        ),
        const ChatPart(id: 's1', kind: ChatPartKind.tool, title: 'sync-state-invariants', status: 'completed', toolName: 'skill'),
        const ChatPart(id: 's2', kind: ChatPartKind.tool, title: 'diagnosing-bugs', status: 'completed', toolName: 'skill'),
        const ChatPart(id: 'bash-1', kind: ChatPartKind.tool, title: 'git status', status: 'completed', toolName: 'bash', body: 'clean'),
        const ChatPart(id: 'fetch-1', kind: ChatPartKind.tool, title: 'https://example.invalid', status: 'completed', toolName: 'webfetch'),
        const ChatPart(id: 'search-1', kind: ChatPartKind.tool, title: 'openchamber mobile', status: 'completed', toolName: 'websearch', body: 'hits'),
        const ChatPart(id: 'q-1', kind: ChatPartKind.tool, title: 'Which file?', status: 'completed', toolName: 'question'),
        const ChatPart(
          id: 'img-1',
          kind: ChatPartKind.fileOp,
          title: 'shot.png',
          path: 'shot.png',
          toolName: 'image-preview',
          metadata: {'mime': 'image/png'},
        ),
      ],
    );
    await tester.pumpWidget(_wrap(ChatTranscriptBody(message: message, isLastAssistant: true)));
    expect(find.byKey(const Key('chat-generated-commit-json-1')), findsOneWidget);
    expect(find.text('Generated commit message'), findsOneWidget);
    expect(find.byKey(const Key('chat-tool-image-img-1')), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.byKey(const Key('chat-skill-group-s1')), findsNothing);
    await tester.tap(find.byKey(const Key('chat-activity-m-slice9')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-skill-group-s1')), findsOneWidget);
    expect(find.text('Load Skill'), findsOneWidget);
    expect(find.textContaining('sync-state-invariants'), findsOneWidget);
    expect(find.byKey(const Key('chat-tool-bash-bash-1')), findsOneWidget);
    expect(find.text('Shell Command'), findsOneWidget);
    expect(find.byKey(const Key('chat-tool-fetch-fetch-1')), findsOneWidget);
    expect(find.text('Fetch URL'), findsOneWidget);
    expect(find.byKey(const Key('chat-tool-search-search-1')), findsOneWidget);
    expect(find.text('Web Search'), findsOneWidget);
    expect(find.byKey(const Key('chat-tool-question-q-1')), findsOneWidget);
    expect(find.text('Question'), findsOneWidget);
  });

  testWidgets('composer has attach, field, and send — no mic', (tester) async {
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: MemoryOpenChamberTransport()),
    );
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-session-sess-pinned')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byKey(const Key('composer-attach')), findsOneWidget);
    expect(find.byKey(const Key('composer-field')), findsOneWidget);
    expect(find.byKey(const Key('composer-send')), findsOneWidget);
    expect(find.byKey(const Key('composer-dictate')), findsNothing);
    expect(find.byTooltip('Start dictation'), findsNothing);
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
