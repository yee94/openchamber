import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/motion/oc_motion.dart';
import 'package:openchamber/motion/pressable.dart';
import 'package:openchamber/motion/selected_spring.dart';
import 'package:openchamber/native/haptics.dart';
import 'package:openchamber/native/platform_channels.dart';
import 'package:openchamber/navigation/native_back.dart';
import 'package:openchamber/navigation/platform_route.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iOS back commit thresholds match Capacitor OpenChamberNavigation', () {
    expect(OcMotion.shouldCommitBack(progress: 0.35, velocityX: 0), isTrue);
    expect(OcMotion.shouldCommitBack(progress: 0.08, velocityX: 700), isTrue);
    expect(OcMotion.shouldCommitBack(progress: 0.07, velocityX: 900), isFalse);
    expect(OcMotion.shouldCommitBack(progress: 0.2, velocityX: 100), isFalse);
  });

  test('press scale sits in the 0.97–0.98 native band', () {
    expect(OcMotion.pressScale, inInclusiveRange(0.97, 0.98));
  });

  test('NativeHaptics talks to openchamber/haptics, not HapticFeedback', () async {
    final calls = <MethodCall>[];
    final channel = MethodChannel(OpenChamberChannels.haptics);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    final haptics = NativeHaptics(channel: channel);
    await haptics.impact(HapticStrength.light);
    await haptics.impact(HapticStrength.medium);
    expect(calls.map((call) => call.method), ['impact', 'impact']);
    expect(calls.map((call) => (call.arguments as Map)['strength']), ['light', 'medium']);
  });

  testWidgets('finger-down scales immediately; release springs back', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: false),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const Scaffold(
          body: Center(
            child: Pressable(
              key: Key('press-target'),
              child: SizedBox(width: 80, height: 40, child: Text('Row')),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('Row')));
    await tester.pump();
    expect(_scaleOf(tester, 'press-target'), closeTo(OcMotion.pressScale, 0.008));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_scaleOf(tester, 'press-target'), closeTo(1, 0.008));
  });

  testWidgets('drag-out cancels onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Pressable(
              key: const Key('press-target'),
              onPressed: () => taps += 1,
              child: const SizedBox(width: 80, height: 40, child: Text('Row')),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(const Key('press-target')));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.moveBy(const Offset(OcMotion.dragCancelSlop + 12, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('tap still commits onPressed after press scale', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Pressable(
              key: const Key('press-target'),
              onPressed: () => taps += 1,
              child: const SizedBox(width: 80, height: 40, child: Text('Row')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('press-target')));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('selected spring is not an instant snap', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Center(
                child: GestureDetector(
                  key: const Key('select'),
                  onTap: () => setState(() => selected = true),
                  child: OcSelectedSpring(
                    selected: selected,
                    builder: (context, t) => Text('t=${t.toStringAsFixed(2)}'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('t=0.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('select')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('t=1.00'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('t=1.00'), findsOneWidget);
  });

  testWidgets('iOS platform route disables Flutter pop gesture', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      late IosNativePageRoute<void> route;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  route = IosNativePageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('chat-page')),
                  );
                  Navigator.of(context).push(route);
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('chat-page'), findsOneWidget);
      expect(route.popGestureEnabled, isFalse);
      expect(platformPageRoute<void>(builder: (_) => const SizedBox()).runtimeType, IosNativePageRoute<void>);

      await NativeBackDriver.instance.handle(
        const NativeBackEvent(kind: NativeBackKind.invoked, progress: 0.42, velocityX: 820),
      );
      await tester.pumpAndSettle();
      expect(find.text('chat-page'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android platform route stays Material + predictive back', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      expect(platformPageRoute<void>(builder: (_) => const SizedBox()), isA<MaterialPageRoute<void>>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('native back events parse Capacitor-shaped payloads', () {
    final invoked = NativeBackEvent.fromMap({
      'type': 'invoked',
      'progress': 0.4,
      'velocityX': 820.0,
    });
    expect(invoked.kind, NativeBackKind.invoked);
    expect(invoked.progress, 0.4);
    expect(invoked.velocityX, 820);
  });
}

double _scaleOf(WidgetTester tester, String key) {
  final transform = tester.widget<Transform>(
    find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byKey(const ValueKey<String>('oc-press-transform')),
    ),
  );
  return transform.transform.storage[0];
}
