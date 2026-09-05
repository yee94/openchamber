import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/event_pipeline.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/relay/crypto.dart';
import 'package:openchamber/data/relay/handshake.dart';
import 'package:openchamber/data/relay/tunnel_client.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/data/sse.dart';

void main() {
  test('event WS URI prefers official path with lastEventId and oc_url_token', () {
    final uri = globalEventWebSocketUri(
      Uri.parse('http://192.168.1.74:2606'),
      urlToken: 'oc_url_secret',
      lastEventId: 'evt-1',
    );
    expect(uri.scheme, 'ws');
    expect(uri.path, OpenChamberPaths.globalEventWs);
    expect(uri.queryParameters['lastEventId'], 'evt-1');
    expect(uri.queryParameters['oc_url_token'], 'oc_url_secret');
  });

  test('event WS frames match event-pipeline.ts ready/event/error', () {
    expect(parseEventWsFrame('{"type":"ready"}').kind, EventWsFrameKind.ready);
    final event = parseEventWsFrame(
      '{"type":"event","eventId":"7","directory":"/workspace","payload":{"type":"session.status"}}',
    );
    expect(event.kind, EventWsFrameKind.event);
    expect(event.eventId, '7');
    expect(eventTypeOf(event.payload), 'session.status');
    expect(sseEventFromWsFrame(event).id, '7');
    expect(parseEventWsFrame('{"type":"error","message":"nope"}').kind, EventWsFrameKind.error);
    expect(parseEventWsFrame('{"type":"backpressure"}').kind, EventWsFrameKind.backpressure);
    expect(parseEventWsFrame('not-json').kind, EventWsFrameKind.invalid);
  });

  test('memory transport stays on official SSE fallback', () async {
    final transport = MemoryOpenChamberTransport()
      ..statusBySession = {'sess-busy': 'busy'}
      ..eventChunks = [
        'id: 7\ndata: {"type":"session.status"}\n\n',
      ];
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: transport),
    );
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.liveEventTransport, 'sse');
    expect(transport.calls.any((call) => call.path == OpenChamberPaths.globalEvent), isTrue);
    expect(transport.calls.any((call) => call.path == OpenChamberPaths.globalEventWs), isFalse);
    expect(controller.sessionStatusById['sess-busy'], 'busy');
  });

  test('relay prefers tunneled /api/global/event/ws', () async {
    final http = MemoryOpenChamberTransport()..statusBySession = {'sess-busy': 'busy'};
    final opened = await _openMemoryTunnel(http);
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: opened.client),
    );
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'relay');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.liveEventTransport, 'ws');
    expect(opened.host.lastWsQuery, contains('oc_url_token=oc_url_test'));
    expect(controller.sessionStatusById['sess-busy'], 'busy');
    await opened.client.close();
    await opened.host.close();
  });
}

Future<({RelayTunnelTransport client, MemoryRelayHost host})> _openMemoryTunnel(
  MemoryOpenChamberTransport http,
) async {
  final hostKeys = generateEcdhKeyPair();
  final pair = MemoryTunnelPair();
  final host = MemoryRelayHost(
    handshake: HostHandshake(hostKeys.privateKey),
    wire: pair.host,
    handler: (request) => http.send(RelayTunnelTransport.dummyBase, request),
  );
  final client = RelayTunnelTransport(
    wire: pair.client,
    handshake: ClientHandshake.create(hostKeys.publicJwk),
  );
  await client.establish();
  return (client: client, host: host);
}
