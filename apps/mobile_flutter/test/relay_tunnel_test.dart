import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/pairing_payload.dart';
import 'package:openchamber/data/relay/codec.dart';
import 'package:openchamber/data/relay/crypto.dart';
import 'package:openchamber/data/relay/handshake.dart';
import 'package:openchamber/data/relay/protocol.dart';
import 'package:openchamber/data/relay/tunnel_client.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/data/sse.dart';

void main() {
  test('codec round-trips frames and single-frame batches', () {
    final payload = encodeJsonPayload({'method': 'GET', 'path': '/health', 'query': '', 'headers': {}});
    final frame = encodeTunnelFrame(TunnelFrameType.httpRequest, 1, payload);
    final decoded = decodeTunnelFrame(frame);
    expect(decoded.frameType, TunnelFrameType.httpRequest);
    expect(decoded.streamId, 1);
    expect(decodeJsonPayload(decoded.payload), containsPair('path', '/health'));

    final batch = encodeFrameBatch([frame]);
    expect(batch.first, batchContainerTagSingle);
    expect(decodeFrameBatch(batch), [frame]);
  });

  test('client and host handshake derive matching AES keys', () {
    final hostKeys = generateEcdhKeyPair();
    final host = HostHandshake(hostKeys.privateKey);
    final client = ClientHandshake.create(hostKeys.publicJwk);
    final hostAction = host.handleText(client.helloText);
    expect(hostAction.kind, 'established');
    expect(hostAction.replyText, isNotNull);
    final clientAction = client.handleText(hostAction.replyText!);
    expect(clientAction.kind, 'established');

    final message = Uint8List.fromList([1, 2, 3, 4]);
    final cipher = clientAction.channel!.encryptor.encrypt(message);
    expect(hostAction.channel!.decryptor.decrypt(cipher), message);
    final reply = hostAction.channel!.encryptor.encrypt(message);
    expect(clientAction.channel!.decryptor.decrypt(reply), message);
  });

  test('relay HTTP mux health and redeem through a memory wire', () async {
    final http = MemoryOpenChamberTransport();
    final opened = await _openMemoryTunnel(http);
    final tunnel = opened.client;
    final health = await OpenChamberApi(transport: tunnel).health(RelayTunnelTransport.dummyBase);
    expect(health.ok, isTrue);
    expect(health.serverId, 'srv_test');
    final redeem = await OpenChamberApi(transport: tunnel).redeemPairing(
      base: RelayTunnelTransport.dummyBase,
      pairingId: 'pair_1',
      secret: 'one-time',
      deviceId: 'dev-1',
    );
    expect(redeem.ok, isTrue);
    expect(redeem.clientToken, 'oc_client_pair');
    expect(http.calls.any((call) => call.path == OpenChamberPaths.pairingRedeem), isTrue);
    await tunnel.close();
    await opened.host.close();
  });

  test('relay-only pairing redeems through the tunnel and loads session-index', () async {
    final http = MemoryOpenChamberTransport()
      ..redeem = {
        'ok': true,
        'clientToken': 'oc_client_pair',
        'server': {'label': 'Studio'},
      };
    final hostKeys = generateEcdhKeyPair();
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: http),
      openRelayTunnel: (relay) async {
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
      },
    );
    await controller.bootstrap(skipDelay: true);
    final encoded = encodePairingConnectionPayload(
      PairingConnectionPayload(
        pairingId: 'pair_relay_only',
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
    final ok = await controller.connect(pairingLink: encoded);
    expect(ok, isTrue);
    expect(controller.phase, AppPhase.shell);
    expect(controller.activeInstance?.url, 'relay://srv_test');
    expect(controller.activeInstance?.relayUrl, 'wss://relay.example/ws');
    expect(controller.activeInstance?.clientToken, 'oc_client_pair');
    expect(controller.sessions, isNotEmpty);
    expect(http.calls.any((call) => call.path == OpenChamberPaths.pairingRedeem), isTrue);
    expect(http.calls.any((call) => call.path == OpenChamberPaths.sessionIndex), isTrue);
  });

  test('SSE parser reads Last-Event-ID and session.status data', () {
    final event = parseSseBlock('id: 42\nevent: session.status\ndata: {"type":"session.status"}\n');
    expect(event?.id, '42');
    expect(event?.event, 'session.status');
    expect(eventTypeOf(decodeSseJson(event!.data)), 'session.status');
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
    handler: (request) => http.send(Uri.parse('http://memory.invalid'), request),
  );
  final client = RelayTunnelTransport(
    wire: pair.client,
    handshake: ClientHandshake.create(hostKeys.publicJwk),
  );
  await client.establish();
  return (client: client, host: host);
}
