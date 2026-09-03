import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect((calls.single.arguments as Map)['sessionId'], 'sess-busy');

    live.markDismissed('sess-busy');
    now = now.add(const Duration(seconds: 10));
    live.markWorkStarted(at: now);
    expect(live.shouldStart, isFalse);
    expect(await live.startIfDue(), isNull);
    expect(calls.length, 1);
  });

  test('jump back uses openchamber session deep link', () {
    final live = LiveActivityController();
    expect(live.jumpBackUri('sess-1').toString(), 'openchamber://session/sess-1');
  });
}
