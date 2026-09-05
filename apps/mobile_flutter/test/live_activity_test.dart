import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/chat/chat_screen.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';
import 'package:openchamber/native/deep_link.dart';
import 'package:openchamber/native/live_activity_controller.dart';
import 'package:openchamber/native/platform_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts after 5s continuous work and does not rebuild after dismiss', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel(OpenChamberChannels.liveActivity);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'start') return 'activity-1';
      return null;
    });

    var now = DateTime.utc(2026, 9, 3, 12, 0, 0);
    final live = LiveActivityController(now: () => now);
    live.selectSession('sess-busy');
    live.markWorkStarted(at: now);
    expect(live.shouldStart, isFalse);
    now = now.add(const Duration(seconds: 4));
    expect(live.shouldStart, isFalse);
    now = now.add(const Duration(seconds: 2));
    expect(live.shouldStart, isTrue);
    expect(await live.startIfDue(), 'activity-1');
    expect(calls.single.method, 'start');
    final args = calls.single.arguments as Map;
    expect(args['sessionId'], liveActivityCatalogId);
    final items = args['items'] as List;
    expect(items, isNotEmpty);
    expect((items.first as Map)['sessionId'], 'sess-busy');

    live.markDismissed('sess-busy');
    now = now.add(const Duration(seconds: 10));
    live.markWorkStarted(at: now);
    expect(live.shouldStart, isFalse);
    expect(await live.startIfDue(), isNull);
    expect(calls.length, 1);
  });

  test('catalog includes every busy session and each row has a session URI', () {
    final items = buildLiveActivityCatalog(
      statusById: {
        'sess-a': 'busy',
        'sess-b': 'retry',
        'sess-idle': 'idle',
      },
      sessions: const [
        HomeSessionRow(id: 'sess-a', title: 'Composer IME', projectLabel: 'oc', kind: HomeSessionKind.inProgress),
        HomeSessionRow(id: 'sess-b', title: 'HTML preview', projectLabel: 'oc', kind: HomeSessionKind.inProgress),
        HomeSessionRow(id: 'sess-idle', title: 'Done', projectLabel: 'oc', kind: HomeSessionKind.catalog),
      ],
      now: () => DateTime.utc(2026, 9, 5, 4, 0),
    );
    expect(items.map((item) => item.sessionId), ['sess-a', 'sess-b']);
    expect(items.first.title, 'Composer IME');
    expect(items.last.status, 'retry');
    expect(liveActivityRowUri('sess-a').toString(), 'openchamber://session/sess-a');
    expect(liveActivityRowUri('sess-b').toString(), 'openchamber://session/sess-b');
    expect(parseSessionDeepLinkId(liveActivityRowUri('sess-a').toString()), 'sess-a');
    expect(parseSessionDeepLinkId(liveActivityRowUri(liveActivityCatalogId).toString()), isNull);
  });

  test('jump back uses openchamber session deep link', () {
    final live = LiveActivityController();
    expect(live.jumpBackUri('sess-1').toString(), 'openchamber://session/sess-1');
  });

  test('parseSessionDeepLinkId reads the row session, not the catalog id', () {
    expect(parseSessionDeepLinkId('openchamber://session/sess-busy'), 'sess-busy');
    expect(parseSessionDeepLinkId('openchamber://session/live'), isNull);
    expect(parseSessionDeepLinkId('openchamber://settings'), isNull);
  });

  testWidgets('Live Activity row deep link opens that session', (tester) async {
    SecondaryChrome.debugReset();
    final controller = AppController(store: MemorySecureStore());
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    await controller.handleIncomingLink('openchamber://session/sess-catalog');
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('New Session'), findsWidgets);
  });
}
