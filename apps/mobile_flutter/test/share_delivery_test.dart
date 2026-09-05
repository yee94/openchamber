import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/assistant_scheduled.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/data/share_delivery.dart';
import 'package:openchamber/features/chat/chat_screen.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';
import 'package:openchamber/native/share_inbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('share catalog uses snapshot assistant IDs, not the saved instance id', () {
    final targets = shareCatalogFromSnapshot(
      serverInstanceID: 'srv-memory',
      connectionKey: 'lan',
      serverLabel: 'Studio',
      featureEnabled: true,
      assistants: const [
        AssistantRecord(id: 'asst-1', name: 'Home', revision: 1),
        AssistantRecord(id: 'inst-should-not-appear', name: 'Off', revision: 1, enabled: false),
      ],
    );
    expect(targets.map((entry) => entry.assistantId), ['asst-1', 'inst-should-not-appear']);
    expect(targets.first.serverInstanceId, 'srv-memory');
    expect(targets.first.enabled, isTrue);
    expect(targets.last.enabled, isFalse);
  });

  test('deliverOne posts official share then acks and releases', () async {
    final transport = MemoryOpenChamberTransport();
    final api = OpenChamberApi(transport: transport);
    final inbox = MemoryShareInbox();
    final controller = AppController(store: MemorySecureStore(), api: api, shareInbox: inbox);
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');

    expect(inbox.catalog, isNotEmpty);
    expect(inbox.catalog.single.assistantId, 'asst-1');
    expect(inbox.catalog.single.serverInstanceId, 'srv-memory');
    expect(controller.activeInstance!.id, isNot('asst-1'));

    inbox.pending.add(
      const NativeShareEnvelope(
        operationID: 'op-1',
        serverInstanceID: 'srv-memory',
        assistantID: 'asst-1',
        text: 'hello from share',
        source: 'android-share',
      ),
    );
    await controller.drainShares();

    expect(transport.shareCalls, isNotEmpty);
    expect(transport.shareCalls.single['operationID'], 'op-1');
    expect(inbox.acked, ['op-1']);
    expect(inbox.released, ['op-1']);
    expect(controller.pendingDeepLink?.raw, 'openchamber://session/sess-catalog');
  });

  test('one failed share does not block the next envelope', () async {
    final transport = MemoryOpenChamberTransport();
    final api = OpenChamberApi(transport: transport);
    final inbox = MemoryShareInbox();
    final controller = AppController(store: MemorySecureStore(), api: api, shareInbox: inbox);
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');

    inbox.pending.addAll([
      const NativeShareEnvelope(
        operationID: 'op-stale',
        serverInstanceID: 'srv-memory',
        assistantID: 'missing',
        text: 'stale',
      ),
      const NativeShareEnvelope(
        operationID: 'op-ok',
        serverInstanceID: 'srv-memory',
        assistantID: 'asst-1',
        text: 'ok',
      ),
    ]);
    await controller.drainShares();

    expect(transport.shareCalls.single['operationID'], 'op-ok');
    expect(inbox.acked, ['op-ok']);
    expect(inbox.released, ['op-ok']);
    expect(inbox.acked, isNot(contains('op-stale')));
  });

  testWidgets('share-inbox deep link drains and opens the bound session', (tester) async {
    SecondaryChrome.debugReset();
    final transport = MemoryOpenChamberTransport();
    final inbox = MemoryShareInbox();
    inbox.pending.add(
      const NativeShareEnvelope(
        operationID: 'op-link',
        serverInstanceID: 'srv-memory',
        assistantID: 'asst-1',
        text: 'from inbox',
      ),
    );
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: transport),
      shareInbox: inbox,
    );
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pump();
    await controller.handleIncomingLink('openchamber://share-inbox');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(inbox.acked, ['op-link']);
  });

  testWidgets('untargeted draft opens recipient picker and delivers the chosen assistant', (tester) async {
    SecondaryChrome.debugReset();
    final transport = MemoryOpenChamberTransport();
    final inbox = MemoryShareInbox();
    inbox.drafts.add(
      const NativeShareDraft(draftID: 'draft-1', text: 'pick me'),
    );
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: transport),
      shareInbox: inbox,
    );
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await controller.drainShares();
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pump();

    expect(find.byKey(const Key('share-recipient-picker')), findsOneWidget);
    expect(find.text('Choose an assistant'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byKey(const Key('share-recipient-picker')), matching: find.text('Home')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(inbox.cancelled, ['draft-1']);
    expect(transport.shareCalls, isEmpty);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byKey(const Key('share-recipient-picker')), findsNothing);
    expect(find.text('pick me'), findsWidgets);
  });

  test('Android assigned draft fills composer and does not POST /share', () async {
    final transport = MemoryOpenChamberTransport();
    final inbox = MemoryShareInbox();
    inbox.drafts.add(
      const NativeShareDraft(
        draftID: 'draft-assigned',
        serverInstanceID: 'srv-memory',
        assistantID: 'asst-1',
        text: 'assigned hello',
        source: 'android-share',
      ),
    );
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport), shareInbox: inbox);
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await controller.drainShares();
    expect(transport.shareCalls, isEmpty);
    expect(inbox.cancelled, ['draft-assigned']);
    expect(controller.pendingComposerHandoff?.text, 'assigned hello');
    expect(controller.pendingComposerHandoff?.session.id, 'sess-catalog');
  });

  test('iOS assigned draft still POSTs official assistant share', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final transport = MemoryOpenChamberTransport();
    final inbox = MemoryShareInbox();
    inbox.drafts.add(
      const NativeShareDraft(
        draftID: 'draft-ios',
        serverInstanceID: 'srv-memory',
        assistantID: 'asst-1',
        text: 'ios share',
        source: 'ios-share',
      ),
    );
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport), shareInbox: inbox);
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await controller.drainShares();
    expect(transport.shareCalls.single['operationID'], 'draft-ios');
    expect(controller.pendingComposerHandoff, isNull);
  });
}
