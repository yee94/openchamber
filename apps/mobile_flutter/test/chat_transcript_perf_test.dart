import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/chat_markdown_cache.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/long_context_fixture.dart';
import 'package:openchamber/features/chat/chat_screen.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('long-context fixture is hundreds of rows and tens of thousands of lines', () {
    final messages = LongContextFixture.build();
    expect(messages.length, LongContextFixture.defaultTurns * 2);
    expect(messages.length, greaterThanOrEqualTo(200));
    expect(LongContextFixture.estimatedLineCount(), greaterThanOrEqualTo(10000));
    expect(messages.where((message) => !message.isUser).first.body, contains('```dart'));
    expect(messages.any((message) => message.parts.any((part) => part.kind == ChatPartKind.reasoning)), isTrue);
  });

  testWidgets('long transcript scroll stays lazy and Markdown builds stay bounded', (tester) async {
    ChatMarkdownBuildCounters.reset();
    final fixture = LongContextFixture.build();
    final timeline = ReverseChatController(seed: fixture);
    addTearDown(timeline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: materialTheme(Brightness.light),
        home: StringsScope(
          strings: AppStrings.of(AppStrings.en),
          child: ChatScreen(
            session: const HomeSessionRow(
              id: 'sess-perf',
              title: 'Long context',
              projectLabel: 'OpenChamber',
              kind: HomeSessionKind.catalog,
            ),
            timeline: timeline,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('reverse-chat-list')), findsOneWidget);
    final afterMount = ChatMarkdownBuildCounters.builds;
    expect(
      afterMount,
      lessThan(40),
      reason: 'ListView.builder must not parse every message on mount (got $afterMount)',
    );

    final list = find.byKey(const Key('reverse-chat-list'));
    await tester.fling(list, const Offset(0, 1200), 2400);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final afterFling = ChatMarkdownBuildCounters.builds;
    expect(afterFling, greaterThanOrEqualTo(afterMount));
    expect(
      afterFling,
      lessThan(80),
      reason: 'scroll must hydrate a window, not O(n=${fixture.length}) Markdown trees (got $afterFling)',
    );

    final position = tester.widget<ListView>(list).controller!.position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    position.jumpTo(0);
    await tester.pump();

    final beforeReplay = ChatMarkdownBuildCounters.builds;
    final structureBefore = timeline.structureNotifyCount;
    timeline.applyMessages(List<ChatMessage>.from(timeline.oldestFirst));
    await tester.pump();
    expect(timeline.structureNotifyCount, structureBefore);
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
  }, timeout: const Timeout(Duration(minutes: 2)));
}
