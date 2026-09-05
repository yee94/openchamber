import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/secure_store.dart';

void main() {
  Future<({AppController controller, MemoryOpenChamberTransport transport})> connected() async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.refreshSessions();
    return (controller: controller, transport: transport);
  }

  test('rename PATCHes /api/session/:id and updates the home row', () async {
    final env = await connected();
    final session = env.controller.sessionById('sess-catalog')!;
    final ok = await env.controller.renameSession(session, 'Renamed catalog');
    expect(ok, isTrue);
    expect(
      env.transport.calls.any(
        (call) =>
            call.method == 'PATCH' &&
            call.path == OpenChamberPaths.session('sess-catalog') &&
            call.body?['title'] == 'Renamed catalog',
      ),
      isTrue,
    );
    expect(env.controller.sessionById('sess-catalog')?.title, 'Renamed catalog');
  });

  test('pin POSTs the session-index pin path and rolls back on 501', () async {
    final env = await connected();
    final session = env.controller.sessionById('sess-catalog')!;
    expect(session.kind, isNot(HomeSessionKind.pinned));
    final ok = await env.controller.toggleSessionPin(session);
    expect(ok, isTrue);
    expect(
      env.transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionIndexPin('sess-catalog'),
      ),
      isTrue,
    );
    expect(env.controller.sessionById('sess-catalog')?.kind, HomeSessionKind.pinned);

    env.transport.pinStatus = 501;
    final pinned = env.controller.sessionById('sess-catalog')!;
    final failed = await env.controller.toggleSessionPin(pinned);
    expect(failed, isFalse);
    expect(env.controller.lastMutationErrorKey, 'sessions.sidebar.session.pin.error');
    expect(env.controller.sessionById('sess-catalog')?.kind, HomeSessionKind.pinned);
  });

  test('unpin DELETEs the pin path', () async {
    final env = await connected();
    final session = env.controller.sessionById('sess-pinned')!;
    expect(session.kind, HomeSessionKind.pinned);
    final ok = await env.controller.toggleSessionPin(session);
    expect(ok, isTrue);
    expect(
      env.transport.calls.any(
        (call) => call.method == 'DELETE' && call.path == OpenChamberPaths.sessionIndexPin('sess-pinned'),
      ),
      isTrue,
    );
    expect(env.controller.sessionById('sess-pinned')?.kind, isNot(HomeSessionKind.pinned));
  });

  test('archive PATCHes time.archived and drops the home row', () async {
    final env = await connected();
    final session = env.controller.sessionById('sess-catalog')!;
    final ok = await env.controller.archiveSession(session);
    expect(ok, isTrue);
    final patch = env.transport.calls.lastWhere(
      (call) => call.method == 'PATCH' && call.path == OpenChamberPaths.session('sess-catalog'),
    );
    expect(patch.body?['time'], isA<Map>());
    expect((patch.body?['time'] as Map)['archived'], isA<num>());
    expect(env.controller.sessionById('sess-catalog'), isNull);
  });

  test('delete treats 404 as success and removes the row', () async {
    final env = await connected();
    env.transport.sessionMutationStatus = 404;
    final session = env.controller.sessionById('sess-catalog')!;
    final ok = await env.controller.deleteSession(session);
    expect(ok, isTrue);
    expect(
      env.transport.calls.any(
        (call) => call.method == 'DELETE' && call.path == OpenChamberPaths.session('sess-catalog'),
      ),
      isTrue,
    );
    expect(env.controller.sessionById('sess-catalog'), isNull);
  });

  test('hydrateSessionShare GETs /api/session/:id when the index omitted share.url', () async {
    final env = await connected();
    env.transport.sessionShareUrls['sess-catalog'] = 'https://share.example/sess-catalog';
    final session = env.controller.sessionById('sess-catalog')!;
    expect(session.isShared, isFalse);
    final hydrated = await env.controller.hydrateSessionShare(session);
    expect(hydrated.shareUrl, 'https://share.example/sess-catalog');
    expect(
      env.transport.calls.any(
        (call) => call.method == 'GET' && call.path == OpenChamberPaths.session('sess-catalog'),
      ),
      isTrue,
    );
  });

  test('share POSTs /api/session/:id/share and stores the official url', () async {
    final env = await connected();
    final session = env.controller.sessionById('sess-catalog')!;
    expect(session.isShared, isFalse);
    final ok = await env.controller.shareSession(session);
    expect(ok, isTrue);
    expect(
      env.transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionShare('sess-catalog'),
      ),
      isTrue,
    );
    expect(env.controller.sessionById('sess-catalog')?.shareUrl, 'https://share.example/sess-catalog');
  });

  test('unshare DELETEs /api/session/:id/share and rolls back on 500', () async {
    final env = await connected();
    final session = env.controller.sessionById('sess-catalog')!;
    expect(await env.controller.shareSession(session), isTrue);
    final shared = env.controller.sessionById('sess-catalog')!;
    final ok = await env.controller.unshareSession(shared);
    expect(ok, isTrue);
    expect(
      env.transport.calls.any(
        (call) => call.method == 'DELETE' && call.path == OpenChamberPaths.sessionShare('sess-catalog'),
      ),
      isTrue,
    );
    expect(env.controller.sessionById('sess-catalog')?.isShared, isFalse);

    env.transport.sessionShareUrls['sess-catalog'] = 'https://share.example/sess-catalog';
    await env.controller.hydrateSessionShare(env.controller.sessionById('sess-catalog')!);
    env.transport.sessionMutationStatus = 500;
    final failed = await env.controller.unshareSession(env.controller.sessionById('sess-catalog')!);
    expect(failed, isFalse);
    expect(env.controller.lastMutationErrorKey, 'sessions.sidebar.session.unshare.error');
    expect(env.controller.sessionById('sess-catalog')?.isShared, isTrue);
  });

  test('failed delete rolls back the optimistic removal', () async {
    final env = await connected();
    env.transport.sessionMutationStatus = 500;
    final session = env.controller.sessionById('sess-catalog')!;
    final ok = await env.controller.deleteSession(session);
    expect(ok, isFalse);
    expect(env.controller.lastMutationErrorKey, 'sessions.sidebar.session.delete.error');
    expect(env.controller.sessionById('sess-catalog'), isNotNull);
  });
}
