import 'dart:async';

import 'pairing_payload.dart';

/// Official LAN-first / relay-fallback race from
/// `packages/ui/src/apps/mobileConnections.ts` `probeConnectionCandidates`.
/// Direct candidates keep a ~1.5s headstart; relay starts after that (or
/// immediately when every direct probe is already unreachable).
const Duration relayRaceHeadstart = Duration(milliseconds: 1500);

/// Background candidate refresh delay after a successful switch.
const Duration candidateRefreshDelay = Duration(seconds: 5);

enum ProbeStatus { ok, needsLogin, unreachable }

enum CandidateRefreshResult { updated, unchanged, skipped }

sealed class TransportCandidate {
  const TransportCandidate();
}

class DirectTransportCandidate extends TransportCandidate {
  const DirectTransportCandidate({required this.url});

  final String url;
}

class RelayTransportCandidate extends TransportCandidate {
  const RelayTransportCandidate({required this.relay});

  final PairingRelayCandidate relay;
}

class CandidateProbeOutcome<T> {
  const CandidateProbeOutcome({
    required this.status,
    this.value,
    this.discard,
  });

  final ProbeStatus status;
  final T? value;
  final void Function()? discard;

  static CandidateProbeOutcome<T> ok<T>(T value, {void Function()? discard}) =>
      CandidateProbeOutcome<T>(status: ProbeStatus.ok, value: value, discard: discard);

  static CandidateProbeOutcome<T> needsLogin<T>() =>
      const CandidateProbeOutcome(status: ProbeStatus.needsLogin);

  static CandidateProbeOutcome<T> unreachable<T>() =>
      const CandidateProbeOutcome(status: ProbeStatus.unreachable);
}

String? normalizeConnectionUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final withScheme = RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed) ? trimmed : 'http://$trimmed';
  final parsed = Uri.tryParse(withScheme);
  if (parsed == null || parsed.host.isEmpty) return null;
  if (parsed.scheme != 'http' && parsed.scheme != 'https') return null;
  var path = parsed.path.replaceFirst(RegExp(r'/+$'), '');
  if (path == '/') path = '';
  return Uri(
    scheme: parsed.scheme,
    userInfo: parsed.userInfo,
    host: parsed.host,
    port: parsed.hasPort ? parsed.port : null,
    path: path,
  ).toString().replaceFirst(RegExp(r'/+$'), '');
}

String connectionStorageKey(String url) {
  return normalizeConnectionUrl(url) ?? url.trim().replaceFirst(RegExp(r'/+$'), '');
}

bool isSameConnectionUrl(String left, String right) => connectionStorageKey(left) == connectionStorageKey(right);

List<DirectTransportCandidate> directCandidatesOf(List<TransportCandidate> candidates) =>
    candidates.whereType<DirectTransportCandidate>().toList();

RelayTransportCandidate? relayCandidateOf(List<TransportCandidate> candidates) {
  for (final candidate in candidates) {
    if (candidate is RelayTransportCandidate) return candidate;
  }
  return null;
}

String connectionDisplayUrl(List<TransportCandidate> candidates) {
  final direct = directCandidatesOf(candidates);
  if (direct.isNotEmpty) return direct.first.url;
  final relay = relayCandidateOf(candidates);
  return relay == null ? '' : 'relay://${relay.relay.serverId}';
}

List<TransportCandidate> legacyCandidatesFromFields({
  required String url,
  String? relayUrl,
  String? serverId,
  Map<String, String>? hostEncPubJwk,
  String? grant,
}) {
  final list = <TransportCandidate>[];
  final trimmed = url.trim();
  if (trimmed.isNotEmpty) {
    final parsed = Uri.tryParse(trimmed);
    final isRelayPseudo = parsed != null && parsed.scheme == 'relay';
    if (!isRelayPseudo) {
      final normalized = normalizeConnectionUrl(trimmed) ?? trimmed;
      list.add(DirectTransportCandidate(url: normalized));
    }
  }
  final relay = relayUrl?.trim();
  final sid = serverId?.trim();
  if (relay != null && relay.isNotEmpty && sid != null && sid.isNotEmpty && hostEncPubJwk != null) {
    list.add(
      RelayTransportCandidate(
        relay: PairingRelayCandidate(
          relayUrl: relay,
          serverId: sid,
          hostEncPubJwk: hostEncPubJwk,
          grant: grant,
        ),
      ),
    );
  }
  return list;
}

double _priorityOf(Object candidate) {
  if (candidate is PairingDirectCandidate) return candidate.priority ?? 100;
  if (candidate is PairingRelayCandidate) return candidate.priority ?? 100;
  return 100;
}

int _rankOf(Object candidate) {
  if (candidate is PairingRelayCandidate) return 2;
  if (candidate is PairingDirectCandidate) {
    return candidate.url.startsWith('https://') ? 0 : 1;
  }
  return 3;
}

/// Convert pairing-payload candidates into the ordered mobile set: priority
/// ascending, relay last on ties. This is what gets persisted and re-probed.
List<TransportCandidate> pairingCandidatesToMobile(List<Object> candidates) {
  final sorted = [...candidates]..sort((left, right) {
        final delta = _priorityOf(left).compareTo(_priorityOf(right));
        if (delta != 0) return delta;
        return _rankOf(left).compareTo(_rankOf(right));
      });
  final list = <TransportCandidate>[];
  for (final candidate in sorted) {
    if (candidate is PairingRelayCandidate) {
      list.add(RelayTransportCandidate(relay: candidate));
      continue;
    }
    if (candidate is PairingDirectCandidate) {
      final url = normalizeConnectionUrl(candidate.url);
      if (url != null) list.add(DirectTransportCandidate(url: url));
    }
  }
  return list;
}

List<Map<String, Object?>> serializeTransportCandidates(List<TransportCandidate> candidates) {
  return candidates.map((candidate) {
    if (candidate is RelayTransportCandidate) {
      return <String, Object?>{
        'kind': 'relay',
        'relay': {
          'relayUrl': candidate.relay.relayUrl,
          'serverId': candidate.relay.serverId,
          'hostEncPubJwk': candidate.relay.hostEncPubJwk,
          if (candidate.relay.grant != null && candidate.relay.grant!.isNotEmpty) 'grant': candidate.relay.grant,
        },
      };
    }
    final direct = candidate as DirectTransportCandidate;
    return <String, Object?>{'kind': 'direct', 'url': direct.url};
  }).toList();
}

List<TransportCandidate> parseTransportCandidates(Object? raw) {
  if (raw is! List) return const [];
  final list = <TransportCandidate>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final record = item.map((key, value) => MapEntry(key.toString(), value));
    if (record['kind'] == 'direct') {
      final url = record['url'] is String ? normalizeConnectionUrl(record['url'] as String) : null;
      if (url != null) list.add(DirectTransportCandidate(url: url));
      continue;
    }
    if (record['kind'] == 'relay') {
      final relayRaw = record['relay'];
      if (relayRaw is! Map) continue;
      final relay = relayRaw.map((key, value) => MapEntry(key.toString(), value));
      final relayUrl = relay['relayUrl'] is String ? (relay['relayUrl'] as String).trim() : '';
      final serverId = relay['serverId'] is String ? (relay['serverId'] as String).trim() : '';
      final jwkRaw = relay['hostEncPubJwk'];
      if (relayUrl.isEmpty || serverId.isEmpty || jwkRaw is! Map) continue;
      final x = jwkRaw['x']?.toString();
      final y = jwkRaw['y']?.toString();
      if (x == null || y == null || x.isEmpty || y.isEmpty) continue;
      final grantRaw = relay['grant'];
      list.add(
        RelayTransportCandidate(
          relay: PairingRelayCandidate(
            relayUrl: relayUrl,
            serverId: serverId,
            hostEncPubJwk: {'kty': 'EC', 'crv': 'P-256', 'x': x, 'y': y},
            grant: grantRaw is String && grantRaw.trim().isNotEmpty ? grantRaw.trim() : null,
          ),
        ),
      );
    }
  }
  return list;
}

bool candidatesEqual(List<TransportCandidate> left, List<TransportCandidate> right) {
  return serializeTransportCandidates(left).toString() == serializeTransportCandidates(right).toString();
}

/// Merge server-reported LAN URLs into a saved set. Fresh `http://` LAN
/// addresses replace previous LAN-class directs; `https://` tunnel-class
/// directs and the relay candidate are preserved. Empty [lanUrls] is a skip
/// (caller must not treat that as authoritative empty).
List<TransportCandidate>? mergeRefreshedLanCandidates({
  required List<TransportCandidate> current,
  required List<String> lanUrls,
}) {
  if (lanUrls.isEmpty) return null;
  final relay = relayCandidateOf(current);
  final preservedHttps = directCandidatesOf(current).where((candidate) => candidate.url.startsWith('https://'));
  return [
    ...lanUrls.map((url) => DirectTransportCandidate(url: url)),
    ...preservedHttps,
    if (relay != null) relay,
  ];
}

List<String> lanUrlsFromCandidatesPayload(Object? candidates) {
  if (candidates is! List) return const [];
  final urls = <String>[];
  for (final entry in candidates) {
    if (entry is! Map) continue;
    final record = entry.map((key, value) => MapEntry(key.toString(), value));
    if (record['type'] != 'lan' || record['url'] is! String) continue;
    final url = normalizeConnectionUrl(record['url'] as String);
    if (url != null && !urls.contains(url)) urls.add(url);
  }
  return urls;
}

Future<void> _defaultWait(Duration duration) => Future<void>.delayed(duration);

/// LAN-first / relay-fallback race. [probeDirects] walks every direct
/// candidate; [probeRelay] opens the tunnel. A discarded loser must close any
/// unused tunnel via [CandidateProbeOutcome.discard].
Future<CandidateProbeOutcome<T>> probeConnectionCandidates<T>({
  required bool hasDirect,
  required bool hasRelay,
  required Future<CandidateProbeOutcome<T>> Function() probeDirects,
  required Future<CandidateProbeOutcome<T>> Function() probeRelay,
  Duration headstart = relayRaceHeadstart,
  Future<void> Function(Duration duration) wait = _defaultWait,
}) async {
  if (!hasRelay) return probeDirects();
  if (!hasDirect) return probeRelay();

  final completer = Completer<CandidateProbeOutcome<T>>();
  var settled = false;
  var relayCancelled = false;
  var relayStarted = false;
  CandidateProbeOutcome<T>? directResult;
  CandidateProbeOutcome<T>? relayResult;

  void closeUnused(CandidateProbeOutcome<T>? result) {
    result?.discard?.call();
  }

  void finish(CandidateProbeOutcome<T> result) {
    if (settled) return;
    settled = true;
    completer.complete(result);
  }

  Future<void> startRelayProbe() async {
    if (relayCancelled || settled || relayStarted) return;
    relayStarted = true;
    final result = await probeRelay();
    relayResult = result;
    if (settled || relayCancelled) {
      closeUnused(result);
      return;
    }
    if (result.status == ProbeStatus.ok || result.status == ProbeStatus.needsLogin) {
      finish(result);
      return;
    }
    if (directResult != null) finish(directResult!);
  }

  unawaited((() async {
    final result = await probeDirects();
    directResult = result;
    if (settled) {
      closeUnused(result);
      return;
    }
    if (result.status == ProbeStatus.ok || result.status == ProbeStatus.needsLogin) {
      relayCancelled = true;
      closeUnused(relayResult);
      finish(result);
      return;
    }
    if (relayResult != null) {
      finish(relayResult!);
      return;
    }
    await startRelayProbe();
  })());

  unawaited((() async {
    await wait(headstart);
    await startRelayProbe();
  })());

  return completer.future;
}
