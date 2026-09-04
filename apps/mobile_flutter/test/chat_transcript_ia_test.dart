import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/features/chat/tool_cards.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/theme/ios_chrome.dart';
import 'package:openchamber/theme/oc_glyphs.dart';

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

  testWidgets('expanded activity has a gap, foreground ink, skill and terminal rows', (tester) async {
    const message = ChatMessage(
      id: 'm-expand',
      body: '按 skill 流程上 pod 取证，再跑 pub。',
      isUser: false,
      processedLabel: '10m 33s',
      parts: [
        ChatPart(id: 't1', kind: ChatPartKind.text, title: 'text', body: '按 skill 流程上 pod 取证，再跑 pub。'),
        ChatPart(
          id: 'skill-1',
          kind: ChatPartKind.tool,
          title: 'wxa-bff-hot-debug',
          status: 'completed',
          toolName: 'skill',
        ),
        ChatPart(
          id: 'bash-1',
          kind: ChatPartKind.tool,
          title: "ego-browser nodejs <<'EOF'",
          status: 'completed',
          toolName: 'bash',
          body: 'ok pub done',
          metadata: {'duration': '8.2s', 'command': "ego-browser nodejs <<'EOF'"},
        ),
        ChatPart(
          id: 'bash-2',
          kind: ChatPartKind.tool,
          title: 'kubectl logs',
          status: 'completed',
          toolName: 'bash',
          metadata: {'duration': '0.1s', 'command': 'kubectl logs'},
        ),
      ],
    );
    await tester.pumpWidget(_wrap(const ChatTranscriptBody(message: message, isLastAssistant: true)));
    await tester.tap(find.byKey(const Key('chat-activity-m-expand')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-skill-group-skill-1')), findsOneWidget);
    expect(find.text('加载技能'), findsOneWidget);
    expect(find.textContaining('wxa-bff-hot-debug'), findsOneWidget);
    expect(find.byKey(const Key('chat-tool-bash-bash-1')), findsOneWidget);
    expect(find.text('运行'), findsWidgets);
    expect(find.text('8.2s'), findsOneWidget);
    expect(find.text('0.1s'), findsOneWidget);
    expect(find.textContaining("ego-browser nodejs"), findsOneWidget);

    final header = tester.getRect(find.byKey(const Key('chat-activity-m-expand')));
    final skill = tester.getRect(find.byKey(const Key('chat-skill-group-skill-1')));
    expect(skill.top - header.bottom, greaterThanOrEqualTo(OcOptical.activityExpandedGap - 1));
    expect(skill.left, greaterThan(header.left + 8));

    final skillTitle = tester.widget<Text>(find.text('加载技能'));
    expect(skillTitle.style?.color, OcTokens.light.foreground);
    final duration = tester.widget<Text>(find.text('8.2s'));
    expect(duration.style?.color, OcTokens.light.mutedForeground);

    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(
      tester.widgetList<OcGlyph>(find.byType(OcGlyph)).any((glyph) => glyph.kind == OcGlyphKind.folder),
      isTrue,
    );
    expect(
      tester.widgetList<OcGlyph>(find.byType(OcGlyph)).any((glyph) => glyph.kind == OcGlyphKind.terminal),
      isTrue,
    );
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
