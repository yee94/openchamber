import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/chat_markdown_cache.dart';
import 'package:openchamber/data/chat_rebuild_counters.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/long_context_fixture.dart';
import 'package:openchamber/features/chat/chat_markdown_body.dart';
import 'package:openchamber/features/chat/chat_screen.dart';
import 'package:openchamber/features/chat/chat_transcript_row.dart';
import 'package:openchamber/features/chat/reverse_chat_list.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/motion/oc_motion.dart';
import 'package:openchamber/theme/app_theme.dart';

const _session = HomeSessionRow(
  id: 'sess-perf',
  title: 'Long context',
  projectLabel: 'OpenChamber',
  kind: HomeSessionKind.catalog,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ChatMarkdownBuildCounters.reset();
    ChatRebuildCounters.reset();
    ChatMarkdownSourceCache.clear();
  });

  test('long-context fixture is 500+ rows with large fences and many reasoning blocks', () {
    final messages = LongContextFixture.build();
    expect(messages.length, LongContextFixture.defaultTurns * 2);
    expect(messages.length, greaterThanOrEqualTo(500));
    expect(LongContextFixture.estimatedLineCount(), greaterThanOrEqualTo(25000));
    expect(messages.where((message) => !message.isUser).first.body, contains('```dart'));
    final reasoning = messages.where((message) => message.parts.any((part) => part.kind == ChatPartKind.reasoning)).length;
    expect(reasoning, greaterThanOrEqualTo(80));
    expect(messages.last.parts.any((part) => part.kind == ChatPartKind.reasoning), isTrue);
    expect(LongContextFixture.reasoningMarkdown(0), contains('Hidden reasoning paragraph'));
  });

  testWidgets('500-message transcript stays lazy, settles scroll, and bounds first-frame work', (tester) async {
    final fixture = LongContextFixture.build();
    final timeline = ReverseChatController(seed: fixture);
    addTearDown(timeline.dispose);

    await tester.pumpWidget(_chatApp(ChatScreen(session: _session, timeline: timeline)));

    final mountPump = Stopwatch()..start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    mountPump.stop();

    expect(find.byKey(const Key('reverse-chat-list')), findsOneWidget);
    final afterMount = ChatMarkdownBuildCounters.builds;
    expect(
      afterMount,
      lessThan(40),
      reason: 'ListView.builder must not parse every message on mount (got $afterMount)',
    );
    expect(
      mountPump.elapsedMilliseconds,
      lessThan(2500),
      reason: 'first frames after 500-message mount took ${mountPump.elapsedMilliseconds}ms (CI CPU budget, not 16ms phone frames)',
    );
    debugPrint(
      'chat-perf mount: messages=${fixture.length} markdownBuilds=$afterMount '
      'listBuilds=${ChatRebuildCounters.listStructureBuilds} '
      'rowWidgets=${ChatRebuildCounters.rowWidgetBuilds} '
      'ms=${mountPump.elapsedMilliseconds}',
    );

    final list = find.byKey(const Key('reverse-chat-list'));
    final scrollWatch = Stopwatch()..start();
    await tester.fling(list, const Offset(0, 1800), 3200);
    await tester.pump();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    scrollWatch.stop();
    expect(
      scrollWatch.elapsedMilliseconds,
      lessThan(3000),
      reason: 'fling+settle took ${scrollWatch.elapsedMilliseconds}ms',
    );

    final afterFling = ChatMarkdownBuildCounters.builds;
    expect(afterFling, greaterThanOrEqualTo(afterMount));
    expect(
      afterFling,
      lessThan(80),
      reason: 'scroll must hydrate a window, not O(n=${fixture.length}) Markdown trees (got $afterFling)',
    );
    debugPrint(
      'chat-perf fling: markdownBuilds=$afterFling settleMs=${scrollWatch.elapsedMilliseconds}',
    );

    final position = tester.widget<ListView>(list).controller!.position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    position.jumpTo(0);
    await tester.pump();

    final beforeReplay = ChatMarkdownBuildCounters.builds;
    final structureBefore = timeline.structureNotifyCount;
    final listBuildsBefore = ChatRebuildCounters.listStructureBuilds;
    timeline.applyMessages(List<ChatMessage>.from(timeline.oldestFirst));
    await tester.pump();
    expect(timeline.structureNotifyCount, structureBefore);
    expect(ChatRebuildCounters.listStructureBuilds, listBuildsBefore);
    expect(
      ChatMarkdownBuildCounters.builds,
      beforeReplay,
      reason: 'identical applyMessages must not rematerialize Markdown',
    );

    timeline.applyMessages([
      ...timeline.oldestFirst.sublist(0, timeline.length - 1),
      ChatMessage(
        id: timeline.oldestFirst.last.id,
        body: '${timeline.oldestFirst.last.body}\n\n+token',
        isUser: false,
        parts: timeline.oldestFirst.last.parts,
      ),
    ]);
    await tester.pump();
    expect(timeline.structureNotifyCount, structureBefore, reason: 'in-place tail edit is a slot write, not a list rebuild');
    expect(ChatRebuildCounters.listStructureBuilds, listBuildsBefore);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('single-message SSE token does not rebuild the list or the neighbor row', (tester) async {
    final busy = ValueNotifier(true);
    final speaking = ValueNotifier<String?>(null);
    addTearDown(busy.dispose);
    addTearDown(speaking.dispose);

    final timeline = ReverseChatController(
      seed: [
        const ChatMessage(
          id: 'settled',
          body: 'Settled **done**.',
          isUser: false,
          parts: [
            ChatPart(id: 'settled-text', kind: ChatPartKind.text, title: 'text', body: 'Settled **done**.'),
            ChatPart(
              id: 'settled-think',
              kind: ChatPartKind.reasoning,
              title: 'thinking',
              body: 'First thought about the settled turn.\nHidden settled detail that must stay collapsed.',
              status: 'completed',
            ),
          ],
        ),
        const ChatMessage(
          id: 'live',
          body: 'Hello',
          isUser: false,
          parts: [
            ChatPart(id: 'live-text', kind: ChatPartKind.text, title: 'text', body: 'Hello'),
          ],
        ),
      ],
    );
    addTearDown(timeline.dispose);

    await tester.pumpWidget(_chatApp(_listHarness(timeline: timeline, busy: busy, speaking: speaking)));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('chat-message-settled')), findsOneWidget);
    expect(find.byKey(const Key('chat-message-live')), findsOneWidget);

    final structureBefore = timeline.structureNotifyCount;
    final listBefore = ChatRebuildCounters.listStructureBuilds;
    final settledSlots = ChatRebuildCounters.rowSlotBuildsFor('settled');
    final settledReasoning = ChatRebuildCounters.reasoningBuildsFor('settled-think');
    final settledWidgets = ChatRebuildCounters.rowWidgetBuildsFor('settled');
    final markdownBefore = ChatMarkdownBuildCounters.builds;
    var liveSlotTicks = 0;
    timeline.slotFor('live').addListener(() => liveSlotTicks += 1);
    var settledSlotTicks = 0;
    timeline.slotFor('settled').addListener(() => settledSlotTicks += 1);

    for (var i = 1; i <= 8; i += 1) {
      timeline.applyMessages([
        timeline.oldestFirst.first,
        ChatMessage(
          id: 'live',
          body: 'Hello${'!' * i}',
          isUser: false,
          parts: [
            ChatPart(id: 'live-text', kind: ChatPartKind.text, title: 'text', body: 'Hello${'!' * i}'),
          ],
        ),
      ]);
      await tester.pump();
    }

    expect(timeline.structureNotifyCount, structureBefore);
    expect(ChatRebuildCounters.listStructureBuilds, listBefore);
    expect(ChatRebuildCounters.rowWidgetBuildsFor('settled'), settledWidgets);
    expect(ChatRebuildCounters.rowSlotBuildsFor('settled'), settledSlots);
    expect(ChatRebuildCounters.reasoningBuildsFor('settled-think'), settledReasoning);
    expect(settledSlotTicks, 0);
    expect(liveSlotTicks, 8);
    expect(
      ChatMarkdownBuildCounters.builds,
      markdownBefore,
      reason: 'live 64ms pace must coalesce 8 tokens before the timer fires (got ${ChatMarkdownBuildCounters.builds - markdownBefore} extra builds)',
    );

    await tester.pump(ChatMarkdownBody.livePace);
    await tester.pump();
    expect(ChatMarkdownBuildCounters.builds, markdownBefore + 1);
    expect(ChatRebuildCounters.rowSlotBuildsFor('settled'), settledSlots);
    expect(find.textContaining('Hello!!!!!!!!'), findsWidgets);
    debugPrint(
      'chat-perf sse: liveSlotTicks=$liveSlotTicks settledSlotTicks=$settledSlotTicks '
      'listBuilds=${ChatRebuildCounters.listStructureBuilds - listBefore} '
      'markdownDelta=${ChatMarkdownBuildCounters.builds - markdownBefore}',
    );
  });

  testWidgets('reasoning expand/collapse does not rebuild unrelated rows and still matches official motion', (tester) async {
    final busy = ValueNotifier(false);
    final speaking = ValueNotifier<String?>(null);
    addTearDown(busy.dispose);
    addTearDown(speaking.dispose);

    final timeline = ReverseChatController(
      seed: [
        const ChatMessage(
          id: 'other',
          body: 'Neighbor',
          isUser: false,
          parts: [
            ChatPart(id: 'other-text', kind: ChatPartKind.text, title: 'text', body: 'Neighbor **row**'),
            ChatPart(
              id: 'other-think',
              kind: ChatPartKind.reasoning,
              title: 'thinking',
              body: 'First thought about the neighbor.\nHidden neighbor detail that must not remount.',
              status: 'completed',
            ),
          ],
        ),
        const ChatMessage(
          id: 'target',
          body: 'Target',
          isUser: false,
          parts: [
            ChatPart(id: 'target-text', kind: ChatPartKind.text, title: 'text', body: 'Target **row**'),
            ChatPart(
              id: 'target-think',
              kind: ChatPartKind.reasoning,
              title: 'thinking',
              body: 'First thought about the target row.\nHidden target detail that mounts only when expanded.',
              status: 'completed',
            ),
          ],
        ),
      ],
    );
    addTearDown(timeline.dispose);

    await tester.pumpWidget(_chatApp(_listHarness(timeline: timeline, busy: busy, speaking: speaking)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(MarkdownBody), findsNWidgets(2));
    expect(find.byKey(const Key('chat-reasoning-summary-target-think')), findsOneWidget);

    final listBefore = ChatRebuildCounters.listStructureBuilds;
    final otherSlots = ChatRebuildCounters.rowSlotBuildsFor('other');
    final otherReasoning = ChatRebuildCounters.reasoningBuildsFor('other-think');
    final otherWidgets = ChatRebuildCounters.rowWidgetBuildsFor('other');
    final markdownBefore = ChatMarkdownBuildCounters.builds;

    await tester.tap(find.byKey(const Key('chat-reasoning-toggle-target-think')));
    await tester.pump();
    await tester.pump(OcMotion.reasoningExpand);

    expect(find.byKey(const Key('chat-markdown-reasoning-target-think')), findsOneWidget);
    expect(find.textContaining('Hidden target detail'), findsWidgets);
    expect(ChatRebuildCounters.listStructureBuilds, listBefore);
    expect(ChatRebuildCounters.rowWidgetBuildsFor('other'), otherWidgets);
    expect(ChatRebuildCounters.rowSlotBuildsFor('other'), otherSlots);
    expect(ChatRebuildCounters.reasoningBuildsFor('other-think'), otherReasoning);
    expect(ChatMarkdownBuildCounters.builds, markdownBefore + 1);

    await tester.tap(find.byKey(const Key('chat-reasoning-toggle-target-think')));
    await tester.pump();
    await tester.pump(OcMotion.reasoningExpand);
    await tester.pump(OcMotion.reasoningUnmountDelay);

    expect(find.byKey(const Key('chat-markdown-reasoning-target-think')), findsNothing);
    expect(ChatRebuildCounters.listStructureBuilds, listBefore);
    expect(ChatRebuildCounters.rowSlotBuildsFor('other'), otherSlots);
    expect(ChatRebuildCounters.reasoningBuildsFor('other-think'), otherReasoning);
    debugPrint(
      'chat-perf reasoning: listDelta=${ChatRebuildCounters.listStructureBuilds - listBefore} '
      'otherSlotDelta=${ChatRebuildCounters.rowSlotBuildsFor('other') - otherSlots} '
      'otherReasoningDelta=${ChatRebuildCounters.reasoningBuildsFor('other-think') - otherReasoning} '
      'markdownDelta=${ChatMarkdownBuildCounters.builds - markdownBefore}',
    );
  });
}

Widget _chatApp(Widget home) {
  return MaterialApp(
    theme: materialTheme(Brightness.light),
    home: StringsScope(
      strings: AppStrings.of(AppStrings.en),
      child: home,
    ),
  );
}

Widget _listHarness({
  required ReverseChatController timeline,
  required ValueNotifier<bool> busy,
  required ValueNotifier<String?> speaking,
}) {
  return Scaffold(
    body: ReverseChatList(
      controller: timeline,
      itemBuilder: (context, message, reverseIndex) {
        return ChatTranscriptRow(
          controller: timeline,
          messageId: message.id,
          reverseIndex: reverseIndex,
          busy: busy,
          speakingId: speaking,
        );
      },
    ),
  );
}
