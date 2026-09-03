import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/pairing_payload.dart';
import 'package:openchamber/data/secure_store.dart';

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
            serverId: 'srv_abc',
            hostEncPubJwk: hostEncPubJwk,
          ),
        ],
      ),
    );
    final ok = await controller.connect(pairingLink: encoded);
    expect(ok, isTrue);
    expect(controller.activeInstance?.url, 'http://192.168.1.20:4096');
    expect(controller.activeInstance?.relayUrl, 'wss://relay.example/ws');
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

  test('relay-only pairing is refused instead of faking a tunnel', () async {
    final controller = AppController(store: MemorySecureStore());
    await controller.bootstrap(skipDelay: true);
    final encoded = encodePairingConnectionPayload(
      const PairingConnectionPayload(
        pairingId: 'pair_relay_only',
        secret: 'one-time-secret',
        candidates: [
          PairingRelayCandidate(
            relayUrl: 'wss://relay.example/ws',
            serverId: 'srv_abc',
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
}
