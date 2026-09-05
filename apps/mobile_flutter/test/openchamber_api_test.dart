import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/data/session_index.dart';
import 'package:openchamber/data/message_id.dart';
import 'package:openchamber/data/widget_snapshot.dart';

void main() {
  test('health, session probe, and pairing redeem use official paths', () async {
    final transport = MemoryOpenChamberTransport();
    final api = OpenChamberApi(transport: transport);
    final base = Uri.parse('http://192.168.1.74:2606');

    await api.health(base);
    expect(transport.calls.first.path, OpenChamberPaths.health);

    await api.getAuthSession(base);
    expect(transport.calls[1].path, OpenChamberPaths.authSession);
    expect(transport.calls[1].method, 'GET');

    await api.unlockWithPassword(base: base, password: 'secret', deviceId: 'dev-1', devicePlatform: 'ios');
    final unlock = transport.calls[2];
    expect(unlock.method, 'POST');
    expect(unlock.path, OpenChamberPaths.authSession);
    expect(unlock.body?['issueClientToken'], isTrue);
    expect(unlock.body?['dedupeKey'], 'mobile:dev-1');

    await api.redeemPairing(base: base, pairingId: 'pair_1', secret: 'one-time', deviceId: 'dev-1');
    expect(transport.calls[3].path, OpenChamberPaths.pairingRedeem);
    expect(transport.calls[3].body?['secret'], 'one-time');
  });

  test('connect refuses unreachable servers and does not fake shell', () async {
    final transport = MemoryOpenChamberTransport()..healthStatus = 503;
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    final ok = await controller.connect(url: 'http://192.168.1.74:2606');
    expect(ok, isFalse);
    expect(controller.phase, AppPhase.connect);
    expect(controller.connectErrorKey, 'connect.error.unreachable');
  });

  test('password unlock posts /auth/session and stores client token', () async {
    final transport = MemoryOpenChamberTransport()..auth = {'authenticated': false, 'locked': true};
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    final opened = await controller.connect(url: 'http://10.0.0.8:2606');
    expect(opened, isFalse);
    expect(controller.connectForm, ConnectForm.password);

    final unlocked = await controller.unlockWithPassword('ui-password');
    expect(unlocked, isTrue);
    expect(controller.phase, AppPhase.shell);
    expect(controller.activeInstance?.clientToken, 'oc_client_test');
    expect(transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.authSession), isTrue);
  });

  test('session search matches titles and highlight query', () {
    final rows = fixtureHomeSessions();
    expect(filterSessionsForSearch(rows, 'Release').single.id, 'sess-pinned');
    expect(filterSessionsForSearch(rows, 'feat/home').single.id, 'sess-busy');
    expect(sessionMatchesQuery(rows.first, 'openchamber'), isTrue);
  });

  test('widget snapshot is sparse live index JSON', () {
    final snapshot = buildWidgetSnapshot(fixtureHomeSessions());
    expect(snapshot.attentionCount, 1);
    expect(snapshot.recentSessions.first.id, 'sess-pinned');
    expect(snapshot.encode(), contains('"attentionCount":1'));
  });

  test('send prompt hits prompt_async and is not a local echo', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.refreshSessions();
    final session = controller.sessions.firstWhere((row) => row.id == 'sess-catalog');
    await controller.sendPrompt(session: session, messageId: 'msg-1', text: 'hello from flutter');
    expect(transport.sentPrompts, ['hello from flutter']);
    expect(transport.calls.any((call) => call.path.endsWith('/prompt_async')), isTrue);
    final messages = await controller.loadTranscript(session);
    expect(messages.any((item) => item.body == 'hello from flutter' && item.isUser), isTrue);
  });

  test('ascending message ids match OpenCode Identifier.ascending', () {
    final id = ascendingId('msg');
    expect(id, matches(RegExp(r'^msg_[0-9a-f]{12}[0-9A-Za-z]{14}$')));
    final next = ascendingId('msg');
    expect(next, isNot(id));
  });

  test('plus-menu createSession posts /api/session with a live directory', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.refreshSessions();
    final created = await controller.createSession();
    expect(created, isNotNull);
    expect(created!.id, startsWith('ses_flutter_'));
    expect(created.directory, '/workspace/openchamber');
    expect(
      transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionCreate && call.query['directory'] == '/workspace/openchamber',
      ),
      isTrue,
    );
  });

  test('createSession does not fake success without a live directory', () async {
    final transport = MemoryOpenChamberTransport()..indexStatus = 501;
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    final created = await controller.createSession();
    expect(created, isNull);
    expect(controller.createSessionErrorKey, 'projects.newChat.needsServer');
    expect(transport.calls.any((call) => call.path == OpenChamberPaths.sessionCreate), isFalse);
  });

  test('global event SSE refreshes busy status without inventing a connected poll', () async {
    final transport = MemoryOpenChamberTransport()
      ..statusBySession = {'sess-busy': 'busy'}
      ..eventChunks = [
        'id: 7\ndata: {"type":"session.status"}\n\n',
      ];
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(transport.calls.any((call) => call.path == OpenChamberPaths.globalEvent), isTrue);
    expect(controller.sessionStatusById['sess-busy'], 'busy');
  });

  test('live activity is armed from real busy session status', () async {
    final transport = MemoryOpenChamberTransport()..statusBySession = {'sess-busy': 'busy'};
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.refreshSessions();
    controller.liveActivity.selectSession('sess-busy');
    await controller.refreshSessionStatus(directory: '/workspace/openchamber');
    expect(controller.sessions.any((row) => row.id == 'sess-busy' && row.kind == HomeSessionKind.inProgress), isTrue);
    expect(controller.sessionStatusById['sess-busy'], 'busy');
    expect(controller.liveActivity.catalog.map((item) => item.sessionId), contains('sess-busy'));
    expect(controller.liveActivity.hasWorkStarted, isTrue);
    expect(controller.sessionRowForId('sess-busy').id, 'sess-busy');
  });
}
