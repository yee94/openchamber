import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/mobile/mobile_assistant_card.dart';
import 'package:openchamber/theme/app_theme.dart';
import 'package:openchamber/theme/ios_chrome.dart';

void main() {
  testWidgets('assistant card uses official 40 avatar and 16 pad, not a 44 coin', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: materialTheme(Brightness.light),
        home: MobileAssistantCard(
          pressKey: const Key('assistant-item-asst-1'),
          seed: 'asst-1',
          name: '首页助理',
          modeLabel: '连续模式',
          summary: '一段持续的长对话，处理首页和通知。',
          onOpen: () {},
        ),
      ),
    );
    await tester.pump();

    final press = tester.getRect(find.byKey(const Key('assistant-item-asst-1')));
    expect(press.height, greaterThanOrEqualTo(OcOptical.assistantCardMinHeight));

    final name = tester.widget<Text>(find.text('首页助理'));
    expect(name.style?.fontWeight, FontWeight.w600);
    expect(name.style?.fontSize, OcOptical.assistantName);
    expect(name.style?.letterSpacing, closeTo(OcOptical.assistantNameTrackingOfficial, 0.01));

    final mode = tester.widget<Text>(find.text('连续模式'));
    expect(mode.style?.fontSize, OcOptical.entityMeta);
    final modePill = tester.getSize(find.byKey(const Key('assistant-mode')));
    expect(
      modePill.height,
      closeTo(
        OcOptical.entityMeta * OcOptical.entityMetaHeight +
            2 * OcOptical.assistantModePadV,
        0.5,
      ),
    );
    expect(find.byType(AgentIdenticon), findsOneWidget);
    expect(find.text('首'), findsNothing);

    final summary = tester.widget<Text>(find.text('一段持续的长对话，处理首页和通知。'));
    expect(summary.style?.fontSize, OcTokens.textMicro);
    expect(summary.maxLines, 3);
  });
}
