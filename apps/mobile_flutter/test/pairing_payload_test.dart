import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/pairing_payload.dart';
import 'package:openchamber/data/relay/crypto.dart';
import 'package:openchamber/data/relay/handshake.dart';
import 'package:openchamber/data/relay/tunnel_client.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/l10n/app_strings.dart';

void main() {
  const hostEncPubJwk = {'kty': 'EC', 'crv': 'P-256', 'x': 'eHhY', 'y': 'eVlZ'};

  test('round-trips v2 pairing payloads with lan + relay', () {
    final payload = PairingConnectionPayload(
      pairingId: 'pair_relay',
      secret: 'one-time-secret',
      label: 'Desktop',
      expiresAt: '2099-01-01T00:00:00.000Z',
      candidates: [
        const PairingDirectCandidate(type: 'lan', url: 'http://192.168.1.20:4096', priority: 10),
        const PairingRelayCandidate(
          relayUrl: 'wss://relay.example/ws',
          serverId: 'srv_abc',
          hostEncPubJwk: hostEncPubJwk,
          priority: 30,
        ),
      ],
    );
    final encoded = encodePairingConnectionPayload(payload);
    expect(encoded.startsWith('openchamber://connect?v=2&p='), isTrue);
    final parsed = parsePairingConnectionPayload(encoded);
    expect(parsed, isNotNull);
    expect(parsed!.pairingId, 'pair_relay');
    expect(parsed.firstDirectUrl, 'http://192.168.1.20:4096');
    expect(parsed.firstRelayUrl, 'wss://relay.example/ws');
    expect(parsed.secret, 'one-time-secret');
  });

  test('rejects expired or credential-smuggling relay URLs', () {
    final expired = encodeBase64Url(
      '{"v":2,"pairingId":"pair_123","secret":"secret","expiresAt":"2000-01-01T00:00:00.000Z","candidates":[{"type":"lan","url":"http://runtime.example"}]}',
    );
    expect(parsePairingConnectionPayload('openchamber://connect?v=2&p=$expired'), isNull);

    final userinfo = encodeBase64Url(
      '{"v":2,"pairingId":"pair_1","secret":"s","candidates":[{"type":"relay","relayUrl":"wss://user:pass@relay.example/ws","serverId":"srv","hostEncPubJwk":{"kty":"EC","crv":"P-256","x":"eHhY","y":"eVlZ"}}]}',
    );
    expect(parsePairingConnectionPayload('openchamber://connect?v=2&p=$userinfo'), isNull);
  });

  test('connect redeems LAN pairing and persists relayUrl + client token', () async {
    final store = MemorySecureStore();
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(
      store: store,
      api: OpenChamberApi(transport: transport),
    );
    await controller.bootstrap(skipDelay: true);
    final encoded = encodePairingConnectionPayload(
      const PairingConnectionPayload(
        pairingId: 'pair_persist',
        secret: 'one-time-secret',
        label: 'Studio',
        candidates: [
          PairingDirectCandidate(type: 'lan', url: 'http://192.168.1.20:4096'),
          PairingRelayCandidate(
            relayUrl: 'wss://relay.example/ws',
            serverId: 'srv_test',
            hostEncPubJwk: hostEncPubJwk,
          ),
        ],
      ),
    );
    final ok = await controller.connect(pairingLink: encoded);
    expect(ok, isTrue);
    expect(controller.activeInstance?.url, 'http://192.168.1.20:4096');
    expect(controller.activeInstance?.relayUrl, 'wss://relay.example/ws');
    expect(controller.activeInstance?.hostEncPubJwk, hostEncPubJwk);
    expect(controller.activeInstance?.transportCandidates, hasLength(2));
    expect(controller.activeInstance?.pairingId, 'pair_persist');
    expect(controller.activeInstance?.label, 'Studio');
    expect(controller.activeInstance?.clientToken, 'oc_client_pair');
    expect(controller.phase, AppPhase.shell);
    expect(transport.calls.any((call) => call.path == OpenChamberPaths.pairingRedeem), isTrue);
    expect(
      store.snapshot[tokenStorageKey(connectionKeyFor(
        url: 'http://192.168.1.20:4096',
        relayUrl: 'wss://relay.example/ws',
        serverId: 'srv_test',
      ))],
      'oc_client_pair',
    );
  });

  test('relay-only pairing without a reachable tunnel stays on connect', () async {
    final controller = AppController(store: MemorySecureStore());
    await controller.bootstrap(skipDelay: true);
    final encoded = encodePairingConnectionPayload(
      const PairingConnectionPayload(
        pairingId: 'pair_relay_only',
        secret: 'one-time-secret',
        candidates: [
          PairingRelayCandidate(
            relayUrl: 'wss://relay.example/ws',
            serverId: 'srv_test',
            hostEncPubJwk: hostEncPubJwk,
          ),
        ],
      ),
    );
    final ok = await controller.connect(pairingLink: encoded);
    expect(ok, isFalse);
    expect(controller.phase, AppPhase.connect);
    expect(controller.connectErrorKey, 'connect.error.relayTunnelMissing');
  });

  test('parses a relay-only v2 payload without inventing a LAN candidate', () {
    final encoded = encodePairingConnectionPayload(
      const PairingConnectionPayload(
        pairingId: 'pair_relay_v2',
        secret: 'one-time-secret',
        label: 'Anywhere',
        candidates: [
          PairingRelayCandidate(
            relayUrl: 'wss://relay.example/ws',
            serverId: 'srv_away',
            hostEncPubJwk: hostEncPubJwk,
            grant: 'grant-away',
          ),
        ],
      ),
    );
    expect(encoded.startsWith('openchamber://connect?v=2&p='), isTrue);
    final parsed = parsePairingConnectionPayload(encoded);
    expect(parsed, isNotNull);
    expect(parsed!.pairingId, 'pair_relay_v2');
    expect(parsed.secret, 'one-time-secret');
    expect(parsed.firstDirectUrl, isNull);
    expect(parsed.firstRelayUrl, 'wss://relay.example/ws');
    expect(parsed.firstRelay?.serverId, 'srv_away');
    expect(parsed.firstRelay?.grant, 'grant-away');
    expect(parsed.candidates, hasLength(1));
    expect(parsed.candidates.single, isA<PairingRelayCandidate>());
  });

  test('relay-only v2 redeem happy path hits official pairing redeem', () async {
    final store = MemorySecureStore();
    final http = MemoryOpenChamberTransport()
      ..redeem = {
        'ok': true,
        'clientToken': 'oc_client_pair',
        'server': {'label': 'Studio'},
      };
    final hostKeys = generateEcdhKeyPair();
    var waited = false;
    final controller = AppController(
      store: store,
      api: OpenChamberApi(transport: http),
      relayRaceHeadstart: const Duration(seconds: 5),
      relayRaceWait: (_) async {
        waited = true;
      },
      openRelayTunnel: (relay) => _openMemoryTunnel(http, hostKeys),
    );
    await controller.bootstrap(skipDelay: true);
    final encoded = encodePairingConnectionPayload(
      PairingConnectionPayload(
        pairingId: 'pair_redeem_v2',
        secret: 'one-time-secret',
        label: 'Studio',
        candidates: [
          PairingRelayCandidate(
            relayUrl: 'wss://relay.example/ws',
            serverId: 'srv_test',
            hostEncPubJwk: hostKeys.publicJwk,
            grant: 'grant-redeem',
          ),
        ],
      ),
    );
    expect(await controller.connect(pairingLink: encoded), isTrue);
    expect(waited, isFalse);
    expect(controller.phase, AppPhase.shell);
    expect(controller.activeTransportKind, ActiveTransportKind.relay);
    expect(controller.activeInstance?.clientToken, 'oc_client_pair');
    expect(controller.activeInstance?.pairingId, 'pair_redeem_v2');
    expect(controller.activeInstance?.grant, 'grant-redeem');
    expect(controller.activeInstance?.relayUrl, 'wss://relay.example/ws');
    final redeem = http.calls.singleWhere((call) => call.path == OpenChamberPaths.pairingRedeem);
    expect(redeem.method, 'POST');
    expect(redeem.body?['pairingId'], 'pair_redeem_v2');
    expect(redeem.body?['secret'], 'one-time-secret');
    expect(redeem.body?['clientKind'], 'mobile');
    expect(http.bases.any((base) => base.host.startsWith('192.168.')), isFalse);
  });

  testWidgets('relay-only pairing form redeems and shows Connected · Relay', (tester) async {
    final http = MemoryOpenChamberTransport()
      ..redeem = {
        'ok': true,
        'clientToken': 'oc_client_pair',
        'server': {'label': 'Studio'},
      };
    final hostKeys = generateEcdhKeyPair();
    var waited = false;
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: http),
      relayRaceHeadstart: const Duration(seconds: 5),
      relayRaceWait: (_) async {
        waited = true;
      },
      openRelayTunnel: (relay) => _openMemoryTunnel(http, hostKeys),
    );
    await controller.bootstrap(skipDelay: true);
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();

    final encoded = encodePairingConnectionPayload(
      PairingConnectionPayload(
        pairingId: 'pair_widget_redeem',
        secret: 'one-time-secret',
        label: 'Studio',
        candidates: [
          PairingRelayCandidate(
            relayUrl: 'wss://relay.example/ws',
            serverId: 'srv_test',
            hostEncPubJwk: hostKeys.publicJwk,
          ),
        ],
      ),
    );
    await tester.enterText(find.byKey(const Key('connect-pairing')), encoded);
    await tester.tap(find.byKey(const Key('connect-submit')));
    await tester.pumpAndSettle();

    expect(waited, isFalse);
    expect(controller.phase, AppPhase.shell);
    expect(controller.activeConnectionStatusKey, 'mobile.instances.status.connectedRelay');
    expect(find.text('Connected · Relay'), findsNothing);

    await tester.tap(find.byKey(const Key('tab-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-slug-instances')));
    await tester.tap(find.byKey(const Key('settings-slug-instances')));
    await tester.pumpAndSettle();
    expect(find.text('Connected · Relay'), findsOneWidget);
    expect(find.text('Connected · Local network'), findsNothing);
    expect(find.text('已连接 · 中继'), findsNothing);

    await controller.setLocale(AppStrings.zhCN);
    await tester.pumpAndSettle();
    expect(find.text('已连接 · 中继'), findsOneWidget);
    expect(find.text('Connected · Relay'), findsNothing);
    expect(http.calls.any((call) => call.path == OpenChamberPaths.pairingRedeem), isTrue);
  });
}

Future<OpenChamberTransport> _openMemoryTunnel(
  MemoryOpenChamberTransport http,
  RelayKeyPair hostKeys,
) async {
  final pair = MemoryTunnelPair();
  MemoryRelayHost(
    handshake: HostHandshake(hostKeys.privateKey),
    wire: pair.host,
    handler: (request) => http.send(Uri.parse('http://memory.invalid'), request),
  );
  final tunnel = RelayTunnelTransport(
    wire: pair.client,
    handshake: ClientHandshake.create(hostKeys.publicJwk),
  );
  await tunnel.establish();
  return tunnel;
}
