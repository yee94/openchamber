import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/connection_candidates.dart';
import 'package:openchamber/data/instance_store.dart';
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

  test('iOS Info.plist declares official local-network usage', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>NSLocalNetworkUsageDescription</key>'));
    expect(plist, contains('OpenChamber connects to OpenChamber servers on your local network.'));
    expect(plist, contains('<key>NSAllowsLocalNetworking</key>'));
    expect(plist, contains('<key>NSCameraUsageDescription</key>'));
  });

  test('Android debug identity is side-by-side with Capacitor release', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "com.yee94.openchamber"'));
    expect(gradle, contains('applicationIdSuffix = ".debug"'));
    expect(gradle, contains('resValue("string", "app_name", "OpenChamber v2")'));
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:label="@string/app_name"'));
    expect(manifest, contains('android:scheme="openchamber"'));
    final strings = File('android/app/src/main/res/values/strings.xml').readAsStringSync();
    expect(strings, contains('<string name="app_name">OpenChamber</string>'));
    final services = File('android/app/google-services.json').readAsStringSync();
    expect(services, contains('"package_name": "com.yee94.openchamber"'));
    expect(services, contains('"package_name": "com.yee94.openchamber.debug"'));
  });

  test('relay-only probe skips the 1.5s headstart and never probes LAN', () async {
    var waited = false;
    var lanProbed = false;
    final started = Stopwatch()..start();
    final result = await probeConnectionCandidates<String>(
      hasDirect: false,
      hasRelay: true,
      probeDirects: () async {
        lanProbed = true;
        return CandidateProbeOutcome.unreachable();
      },
      probeRelay: () async => CandidateProbeOutcome.ok('relay'),
      headstart: const Duration(seconds: 5),
      wait: (duration) async {
        waited = true;
        await Future<void>.delayed(duration);
      },
    );
    started.stop();
    expect(result.status, ProbeStatus.ok);
    expect(result.value, 'relay');
    expect(lanProbed, isFalse);
    expect(waited, isFalse);
    expect(started.elapsed, lessThan(const Duration(milliseconds: 500)));
  });

  test('LAN wins inside headstart', () async {
    final lan = Completer<CandidateProbeOutcome<String>>();
    final relay = Completer<CandidateProbeOutcome<String>>();
    var relayStarted = false;
    var discarded = '';
    final future = probeConnectionCandidates<String>(
      hasDirect: true,
      hasRelay: true,
      probeDirects: () => lan.future,
      probeRelay: () {
        relayStarted = true;
        return relay.future;
      },
      headstart: const Duration(milliseconds: 40),
    );
    lan.complete(CandidateProbeOutcome.ok('lan', discard: () => discarded = 'lan'));
    expect(await future, predicate<CandidateProbeOutcome<String>>((result) {
      return result.status == ProbeStatus.ok && result.value == 'lan';
    }));
    expect(relayStarted, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(relayStarted, isFalse);
    expect(discarded, isEmpty);
  });

  test('relay adopted after LAN timeout', () async {
    final lan = Completer<CandidateProbeOutcome<String>>();
    var discarded = '';
    final future = probeConnectionCandidates<String>(
      hasDirect: true,
      hasRelay: true,
      probeDirects: () => lan.future,
      probeRelay: () async => CandidateProbeOutcome.ok('relay', discard: () => discarded = 'relay'),
      headstart: const Duration(milliseconds: 20),
    );
    expect(await future, predicate<CandidateProbeOutcome<String>>((result) {
      return result.status == ProbeStatus.ok && result.value == 'relay';
    }));
    lan.complete(CandidateProbeOutcome.ok('lan', discard: () => discarded = 'lan'));
    await Future<void>.delayed(Duration.zero);
    expect(discarded, 'lan');
  });

  test('persist+reload keeps full lan + relay candidates', () async {
    final store = MemorySecureStore();
    final repo = InstanceRepository(store);
    final candidates = pairingCandidatesToMobile([
      const PairingDirectCandidate(type: 'lan', url: 'http://192.168.1.20:4096'),
      const PairingDirectCandidate(type: 'lan', url: 'http://192.168.1.21:4096'),
      const PairingRelayCandidate(
        relayUrl: 'wss://relay.example/ws',
        serverId: 'srv_test',
        hostEncPubJwk: hostEncPubJwk,
        grant: 'grant-1',
      ),
    ]);
    final saved = SavedInstance(
      id: 'inst-full',
      url: connectionDisplayUrl(candidates),
      candidates: candidates,
      label: 'Studio',
      relayUrl: 'wss://relay.example/ws',
      serverId: 'srv_test',
      hostEncPubJwk: hostEncPubJwk,
      grant: 'grant-1',
    );
    await repo.persist(InstanceSnapshot(instances: [saved], activeId: saved.id));
    final raw = jsonDecode(store.snapshot[instancesStorageKey]!) as List<dynamic>;
    final record = raw.first as Map<String, dynamic>;
    expect(record['candidates'], hasLength(3));
    expect(record['candidates'][0]['kind'], 'direct');
    expect(record['candidates'][1]['kind'], 'direct');
    expect(record['candidates'][2]['kind'], 'relay');
    expect((record['candidates'][2]['relay'] as Map)['grant'], 'grant-1');

    final reloaded = await repo.load();
    expect(reloaded.instances.single.transportCandidates, hasLength(3));
    expect(reloaded.instances.single.relayCandidate?.relayUrl, 'wss://relay.example/ws');
    expect(reloaded.instances.single.relayCandidate?.grant, 'grant-1');
    expect(directCandidatesOf(reloaded.instances.single.transportCandidates).map((item) => item.url).toList(), [
      'http://192.168.1.20:4096',
      'http://192.168.1.21:4096',
    ]);
  });

  test('connect persists full pairing candidates across reload', () async {
    final store = MemorySecureStore();
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(
      store: store,
      api: OpenChamberApi(transport: transport),
    );
    await controller.bootstrap(skipDelay: true);
    final encoded = encodePairingConnectionPayload(
      const PairingConnectionPayload(
        pairingId: 'pair_full',
        secret: 'one-time-secret',
        label: 'Studio',
        candidates: [
          PairingDirectCandidate(type: 'lan', url: 'http://192.168.1.20:4096'),
          PairingRelayCandidate(
            relayUrl: 'wss://relay.example/ws',
            serverId: 'srv_test',
            hostEncPubJwk: hostEncPubJwk,
            grant: 'grant-keep',
          ),
        ],
      ),
    );
    expect(await controller.connect(pairingLink: encoded), isTrue);
    expect(controller.activeInstance?.transportCandidates, hasLength(2));
    expect(controller.activeTransportKind, ActiveTransportKind.direct);
    expect(
      AppStrings.of(AppStrings.zhCN).t(controller.activeConnectionStatusKey!),
      '已连接 · 局域网',
    );

    final again = AppController(
      store: store,
      api: OpenChamberApi(transport: MemoryOpenChamberTransport()),
    );
    await again.bootstrap(skipDelay: true);
    expect(again.activeInstance?.transportCandidates, hasLength(2));
    expect(again.activeInstance?.relayUrl, 'wss://relay.example/ws');
    expect(again.activeInstance?.grant, 'grant-keep');
    expect(again.activeInstance?.url, 'http://192.168.1.20:4096');
  });

  test('candidates refresh hot-switches relay to a new LAN', () async {
    final http = MemoryOpenChamberTransport()
      ..healthStatusByHost['192.168.1.20'] = 503
      ..connectionCandidates = {
        'serverId': 'srv_test',
        'candidates': [
          {'type': 'lan', 'url': 'http://192.168.1.30:4096', 'priority': 10},
        ],
      };
    final hostKeys = generateEcdhKeyPair();
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: http),
      relayRaceHeadstart: const Duration(milliseconds: 15),
      openRelayTunnel: (relay) => _openMemoryTunnel(http, hostKeys),
    );
    await controller.bootstrap(skipDelay: true);
    final encoded = encodePairingConnectionPayload(
      PairingConnectionPayload(
        pairingId: 'pair_switch',
        secret: 'one-time-secret',
        label: 'Studio',
        candidates: [
          const PairingDirectCandidate(type: 'lan', url: 'http://192.168.1.20:4096'),
          PairingRelayCandidate(
            relayUrl: 'wss://relay.example/ws',
            serverId: 'srv_test',
            hostEncPubJwk: hostKeys.publicJwk,
          ),
        ],
      ),
    );
    expect(await controller.connect(pairingLink: encoded), isTrue);
    expect(controller.activeTransportKind, ActiveTransportKind.relay);
    expect(
      AppStrings.of(AppStrings.zhCN).t(controller.activeConnectionStatusKey!),
      '已连接 · 中继',
    );
    expect(controller.activeInstance?.transportCandidates, hasLength(2));

    expect(await controller.refreshActiveConnectionCandidates(), CandidateRefreshResult.updated);
    expect(
      directCandidatesOf(controller.activeInstance!.transportCandidates).single.url,
      'http://192.168.1.30:4096',
    );
    expect(relayCandidateOf(controller.activeInstance!.transportCandidates), isNotNull);

    expect(await controller.reprobeActiveConnection(), ReprobeOutcome.switched);
    expect(controller.activeTransportKind, ActiveTransportKind.direct);
    expect(controller.activeInstance?.url, 'http://192.168.1.30:4096');
    expect(
      AppStrings.of(AppStrings.en).t(controller.activeConnectionStatusKey!),
      'Connected · Local network',
    );
    expect(http.calls.any((call) => call.path == OpenChamberPaths.connectionCandidates), isTrue);
  });

  test('relay-only pairing connects promptly and reports relay status, never LAN', () async {
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
      relayRaceHeadstart: const Duration(seconds: 5),
      openRelayTunnel: (relay) => _openMemoryTunnel(http, hostKeys),
    );
    await controller.bootstrap(skipDelay: true);
    final encoded = encodePairingConnectionPayload(
      PairingConnectionPayload(
        pairingId: 'pair_relay_only_walk',
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
    final started = Stopwatch()..start();
    expect(await controller.connect(pairingLink: encoded), isTrue);
    started.stop();
    expect(started.elapsed, lessThan(const Duration(milliseconds: 1500)));
    expect(controller.connectErrorKey, isNull);
    expect(controller.activeTransportKind, ActiveTransportKind.relay);
    expect(controller.activeConnectionStatusKey, 'mobile.instances.status.connectedRelay');
    expect(
      AppStrings.of(AppStrings.zhCN).t(controller.activeConnectionStatusKey!),
      '已连接 · 中继',
    );
    expect(
      AppStrings.of(AppStrings.en).t(controller.activeConnectionStatusKey!),
      'Connected · Relay',
    );
    expect(controller.activeConnectionStatusKey, isNot(contains('connectedDirect')));
    expect(controller.activeInstance?.url, 'relay://srv_test');
    expect(directCandidatesOf(controller.activeInstance!.transportCandidates), isEmpty);
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
