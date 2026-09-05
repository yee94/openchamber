import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/prompt_attachment.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SecondaryChrome.debugReset);

  Future<({AppController controller, MemoryOpenChamberTransport transport})> connected({
    String followUp = 'queue',
    Map<String, String> status = const {'sess-catalog': 'busy'},
    int queueStatus = 200,
  }) async {
    final transport = MemoryOpenChamberTransport(statusBySession: status);
    transport.settings['followUpBehavior'] = followUp;
    transport.messageQueueStatus = queueStatus;
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    return (controller: controller, transport: transport);
  }

  test('501 status is unavailable, not an empty queue', () async {
    final env = await connected(queueStatus: 501);
    final session = env.controller.sessionById('sess-catalog')!;
    expect(await env.controller.loadMessageQueueScope(session), isNull);
    expect(await env.controller.admitQueuedFollowUp(session: session, text: 'later'), isNull);
  });

  test('admit with attachments uses official message-queue upload APIs', () async {
    final env = await connected();
    final session = env.controller.sessionById('sess-catalog')!;
    final admitted = await env.controller.admitQueuedFollowUp(
      session: session,
      text: 'see screenshot',
      attachments: [
        AttachmentDraft(name: 'shot.png', mime: 'image/png', bytes: Uint8List.fromList(List<int>.filled(16, 7))),
      ],
    );
    expect(admitted, isNotNull);
    expect(
      env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.messageQueueAttachmentUploads),
      isTrue,
    );
    expect(
      env.transport.calls.any((call) => call.method == 'PUT' && call.path.startsWith('${OpenChamberPaths.messageQueueAttachmentUploads}/')),
      isTrue,
    );
    final admit = env.transport.calls.lastWhere((call) => call.method == 'POST' && call.path == OpenChamberPaths.messageQueueItems);
    final item = admit.body?['item'] as Map;
    final attachments = item['attachments'] as List;
    expect(attachments, isNotEmpty);
    expect((attachments.first as Map)['source'], 'local');
    expect(((attachments.first as Map)['locator'] as Map)['kind'], 'upload');
    expect(env.transport.calls.any((call) => call.path.contains('prompt-attachments')), isFalse);
  });

  test('reserve-edit downloads attachments then reserved-removes', () async {
    final env = await connected();
    final session = env.controller.sessionById('sess-catalog')!;
    await env.controller.admitQueuedFollowUp(
      session: session,
      text: 'edit me',
      attachments: [
        AttachmentDraft(name: 'note.txt', mime: 'text/plain', bytes: Uint8List.fromList('hello'.codeUnits)),
      ],
    );
    final scope = await env.controller.loadMessageQueueScope(session);
    expect(scope, isNotNull);
    final restored = await env.controller.editQueuedItemIntoComposer(
      session: session,
      item: scope!.items.single,
      scope: scope,
    );
    expect(restored, isNotNull);
    expect(restored!.text, 'edit me');
    expect(restored.attachments.single.name, 'note.txt');
    expect(String.fromCharCodes(restored.attachments.single.bytes), 'hello');
    expect(
      env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.messageQueueItemReserve(scope.items.single.queueItemID)),
      isTrue,
    );
    expect(
      env.transport.calls.any(
        (call) => call.method == 'DELETE' && call.path == OpenChamberPaths.messageQueueItemReservedRemove(scope.items.single.queueItemID),
      ),
      isTrue,
    );
    expect(await env.controller.loadMessageQueueScope(session), isNotNull);
    expect((await env.controller.loadMessageQueueScope(session))!.items, isEmpty);
  });

  test('reorder PUTs official scope order', () async {
    final env = await connected();
    final session = env.controller.sessionById('sess-catalog')!;
    await env.controller.admitQueuedFollowUp(session: session, text: 'first');
    var scope = await env.controller.loadMessageQueueScope(session);
    await env.controller.admitQueuedFollowUp(session: session, text: 'second', current: scope);
    scope = await env.controller.loadMessageQueueScope(session);
    expect(scope!.items.map((item) => item.content), ['first', 'second']);
    expect(await env.controller.reorderQueuedItems(session: session, scope: scope, from: 0, to: 2), isTrue);
    expect(
      env.transport.calls.any((call) => call.method == 'PUT' && call.path == OpenChamberPaths.messageQueueScopeOrder(scope!.scopeID)),
      isTrue,
    );
    final reordered = await env.controller.loadMessageQueueScope(session);
    expect(reordered!.items.map((item) => item.content), ['second', 'first']);
  });

  test('admit / send-now / remove hit official message-queue paths', () async {
    final env = await connected();
    final session = env.controller.sessionById('sess-catalog')!;
    final admitted = await env.controller.admitQueuedFollowUp(session: session, text: 'review the diff');
    expect(admitted, isNotNull);
    expect(
      env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.messageQueueItems),
      isTrue,
    );
    final scope = await env.controller.loadMessageQueueScope(session);
    expect(scope, isNotNull);
    expect(scope!.items.single.content, 'review the diff');
    expect(await env.controller.sendQueuedItemNow(session: session, item: scope.items.single, scope: scope), isTrue);
    expect(
      env.transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.messageQueueItemSend(scope.items.single.queueItemID),
      ),
      isTrue,
    );
    final afterSend = await env.controller.loadMessageQueueScope(session);
    expect(
      await env.controller.removeQueuedItem(session: session, item: afterSend!.items.single, scope: afterSend),
      isTrue,
    );
    expect(
      env.transport.calls.any(
        (call) =>
            call.method == 'DELETE' &&
            call.path == OpenChamberPaths.messageQueueItem(afterSend.items.single.queueItemID),
      ),
      isTrue,
    );
  });

  test('unarchive PATCHes time.archived 0 and restores the row', () async {
    final env = await connected(followUp: 'steer', status: const {});
    final session = env.controller.sessionById('sess-catalog')!;
    expect(await env.controller.archiveSession(session), isTrue);
    expect(env.controller.sessionById('sess-catalog'), isNull);
    expect(await env.controller.unarchiveSession(session), isTrue);
    final patch = env.transport.calls.lastWhere(
      (call) => call.method == 'PATCH' && call.path == OpenChamberPaths.session('sess-catalog'),
    );
    expect((patch.body?['time'] as Map)['archived'], 0);
    expect(env.controller.sessionById('sess-catalog'), isA<HomeSessionRow>());
  });

  testWidgets('busy + queue follow-up admits a chip without prompt_async', (tester) async {
    final env = await connected();
    await tester.pumpWidget(OpenChamberApp(controller: env.controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    // Busy nav chrome repeats; do not pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byKey(const Key('composer-field')), 'queue this follow-up');
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.messageQueueItems),
      isTrue,
    );
    expect(env.transport.calls.any((call) => call.path.contains('prompt_async')), isFalse);
    expect(find.byKey(const Key('queued-message-chips')), findsOneWidget);
    expect(find.text('queue this follow-up'), findsOneWidget);
    final queuedId = env.transport.messageQueueItems.single['queueItemID']!.toString();
    await tester.tap(find.byKey(Key('queued-chip-remove-$queuedId')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      env.transport.calls.any((call) => call.method == 'DELETE' && call.path == OpenChamberPaths.messageQueueItem(queuedId)),
      isTrue,
    );
    expect(find.byKey(const Key('queued-message-chips')), findsNothing);
  });

  testWidgets('home archive shows Cap undo and restores the session', (tester) async {
    final env = await connected(followUp: 'steer', status: const {});
    await tester.pumpWidget(OpenChamberApp(controller: env.controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-session-actions-sess-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-overflow-archive')));
    await tester.pumpAndSettle();
    expect(find.text('Session archived'), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-archive-undo')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) =>
            call.method == 'PATCH' &&
            call.path == OpenChamberPaths.session('sess-catalog') &&
            (call.body?['time'] as Map?)?['archived'] == 0,
      ),
      isTrue,
    );
    expect(find.byKey(const Key('home-session-sess-catalog')), findsOneWidget);
  });
}
