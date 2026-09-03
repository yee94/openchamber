import 'dart:convert';

/// Pairing v2 payload. Port of `packages/ui/src/lib/connectionPayload.ts`.
/// Persist the parsed payload. Redeem uses POST /api/client-auth/pairing/redeem.

const maxPairingPayloadLength = 16384;

class PairingDirectCandidate {
  const PairingDirectCandidate({
    required this.type,
    required this.url,
    this.priority,
  });

  final String type;
  final String url;
  final double? priority;
}

class PairingRelayCandidate {
  const PairingRelayCandidate({
    required this.relayUrl,
    required this.serverId,
    required this.hostEncPubJwk,
    this.grant,
    this.priority,
  });

  final String relayUrl;
  final String serverId;
  final Map<String, String> hostEncPubJwk;
  final String? grant;
  final double? priority;
}

class PairingConnectionPayload {
  const PairingConnectionPayload({
    required this.pairingId,
    required this.secret,
    required this.candidates,
    this.label,
    this.fingerprint,
    this.expiresAt,
  });

  final String pairingId;
  final String secret;
  final String? label;
  final String? fingerprint;
  final String? expiresAt;
  final List<Object> candidates;

  String? get firstDirectUrl {
    for (final candidate in candidates) {
      if (candidate is PairingDirectCandidate) return candidate.url;
    }
    return null;
  }

  String? get firstRelayUrl => firstRelay?.relayUrl;

  PairingRelayCandidate? get firstRelay {
    for (final candidate in candidates) {
      if (candidate is PairingRelayCandidate) return candidate;
    }
    return null;
  }
}

String? _normalizeHttpUrl(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https')) {
    return null;
  }
  if (parsed.host.isEmpty) return null;
  final cleared = Uri(
    scheme: parsed.scheme,
    userInfo: parsed.userInfo,
    host: parsed.host,
    port: parsed.hasPort ? parsed.port : null,
    path: parsed.path == '/' ? '' : parsed.path,
  );
  return cleared.toString().replaceFirst(RegExp(r'/+$'), '');
}

String? _normalizeWsUrl(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || (parsed.scheme != 'ws' && parsed.scheme != 'wss')) {
    return null;
  }
  if (parsed.userInfo.isNotEmpty) return null;
  return Uri(
    scheme: parsed.scheme,
    host: parsed.host,
    port: parsed.hasPort ? parsed.port : null,
    path: parsed.path,
  ).toString();
}

Map<String, String>? _normalizeEcPublicJwk(Object? value) {
  if (value is! Map) return null;
  final jwk = value.map((key, item) => MapEntry(key.toString(), item));
  if (jwk['kty'] != 'EC' || jwk['crv'] != 'P-256') return null;
  final x = jwk['x'];
  final y = jwk['y'];
  if (x is! String || x.isEmpty || y is! String || y.isEmpty) return null;
  return {'kty': 'EC', 'crv': 'P-256', 'x': x, 'y': y};
}

double? _normalizePriority(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  return null;
}

Object? _normalizeCandidate(Object? value) {
  if (value is! Map) return null;
  final record = value.map((key, item) => MapEntry(key.toString(), item));
  final priority = _normalizePriority(record['priority']);
  final type = record['type'];
  if (type == 'lan' || type == 'tunnel') {
    final url = _normalizeHttpUrl(record['url']);
    if (url == null) return null;
    return PairingDirectCandidate(type: type as String, url: url, priority: priority);
  }
  if (type == 'relay') {
    final relayUrl = _normalizeWsUrl(record['relayUrl']);
    if (relayUrl == null) return null;
    final serverId = record['serverId'] is String ? (record['serverId'] as String).trim() : '';
    if (serverId.isEmpty) return null;
    final jwk = _normalizeEcPublicJwk(record['hostEncPubJwk']);
    if (jwk == null) return null;
    final grantRaw = record['grant'];
    final grant = grantRaw is String && grantRaw.trim().isNotEmpty ? grantRaw.trim() : null;
    return PairingRelayCandidate(
      relayUrl: relayUrl,
      serverId: serverId,
      hostEncPubJwk: jwk,
      grant: grant,
      priority: priority,
    );
  }
  return null;
}

PairingConnectionPayload? normalizePairingPayload(Object? value) {
  if (value is! Map) return null;
  final record = value.map((key, item) => MapEntry(key.toString(), item));
  if (record['v'] != 2) return null;
  final pairingId = record['pairingId'] is String ? (record['pairingId'] as String).trim() : '';
  final secret = record['secret'] is String ? (record['secret'] as String).trim() : '';
  if (pairingId.isEmpty || secret.isEmpty) return null;
  final rawCandidates = record['candidates'];
  final candidates = <Object>[];
  if (rawCandidates is List) {
    for (final item in rawCandidates) {
      final normalized = _normalizeCandidate(item);
      if (normalized != null) candidates.add(normalized);
    }
  }
  if (candidates.isEmpty) return null;
  final expiresAt = record['expiresAt'] is String && (record['expiresAt'] as String).trim().isNotEmpty
      ? (record['expiresAt'] as String).trim()
      : null;
  if (expiresAt != null) {
    final expiresTime = DateTime.tryParse(expiresAt);
    if (expiresTime == null || !expiresTime.isAfter(DateTime.now().toUtc())) {
      return null;
    }
  }
  final label = record['label'] is String && (record['label'] as String).trim().isNotEmpty
      ? (record['label'] as String).trim()
      : null;
  final fingerprint = record['fingerprint'] is String && (record['fingerprint'] as String).trim().isNotEmpty
      ? (record['fingerprint'] as String).trim()
      : null;
  return PairingConnectionPayload(
    pairingId: pairingId,
    secret: secret,
    candidates: candidates,
    label: label,
    fingerprint: fingerprint,
    expiresAt: expiresAt,
  );
}

String? decodeBase64Url(String value) {
  try {
    var normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    final pad = (4 - normalized.length % 4) % 4;
    normalized = normalized.padRight(normalized.length + pad, '=');
    return utf8.decode(base64.decode(normalized));
  } catch (_) {
    return null;
  }
}

String encodeBase64Url(String value) {
  return base64Url.encode(utf8.encode(value)).replaceAll(RegExp(r'=+$'), '');
}

String encodePairingConnectionPayload(PairingConnectionPayload payload) {
  final candidates = <Map<String, Object?>>[];
  for (final candidate in payload.candidates) {
    if (candidate is PairingDirectCandidate) {
      candidates.add({
        'type': candidate.type,
        'url': candidate.url,
        if (candidate.priority != null) 'priority': candidate.priority,
      });
    } else if (candidate is PairingRelayCandidate) {
      candidates.add({
        'type': 'relay',
        'relayUrl': candidate.relayUrl,
        'serverId': candidate.serverId,
        'hostEncPubJwk': candidate.hostEncPubJwk,
        if (candidate.grant != null) 'grant': candidate.grant,
        if (candidate.priority != null) 'priority': candidate.priority,
      });
    }
  }
  final body = <String, Object?>{
    'v': 2,
    'pairingId': payload.pairingId,
    'secret': payload.secret,
    if (payload.label != null) 'label': payload.label,
    if (payload.fingerprint != null) 'fingerprint': payload.fingerprint,
    if (payload.expiresAt != null) 'expiresAt': payload.expiresAt,
    'candidates': candidates,
  };
  return 'openchamber://connect?v=2&p=${encodeBase64Url(jsonEncode(body))}';
}

/// URL-string parser that never uses [Uri] for the scheme (old WebView sibling).
PairingConnectionPayload? parsePairingConnectionPayloadString(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > maxPairingPayloadLength) return null;
  final question = trimmed.indexOf('?');
  if (question == -1) return null;
  final head = trimmed.substring(0, question);
  if (!RegExp(r'^openchamber://connect/?$', caseSensitive: false).hasMatch(head)) {
    return null;
  }
  String? version;
  String? encoded;
  for (final part in trimmed.substring(question + 1).split('&')) {
    final eq = part.indexOf('=');
    if (eq == -1) continue;
    final key = part.substring(0, eq);
    final raw = part.substring(eq + 1);
    if (key == 'v') version = raw;
    if (key == 'p') encoded = raw;
  }
  if (version != '2' || encoded == null || encoded.length > maxPairingPayloadLength) {
    return null;
  }
  final decoded = decodeBase64Url(Uri.decodeComponent(encoded));
  if (decoded == null || decoded.length > maxPairingPayloadLength) return null;
  try {
    return normalizePairingPayload(jsonDecode(decoded));
  } catch (_) {
    return null;
  }
}

PairingConnectionPayload? parsePairingConnectionPayload(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > maxPairingPayloadLength) return null;
  try {
    final url = Uri.parse(trimmed);
    if (url.scheme == 'openchamber' && url.host == 'connect') {
      if (url.queryParameters['v'] != '2') return null;
      final encoded = url.queryParameters['p'] ?? '';
      if (encoded.isEmpty || encoded.length > maxPairingPayloadLength) return null;
      final decoded = decodeBase64Url(encoded);
      if (decoded == null || decoded.length > maxPairingPayloadLength) return null;
      return normalizePairingPayload(jsonDecode(decoded));
    }
  } catch (_) {
    // Fall through to the string parser.
  }
  return parsePairingConnectionPayloadString(trimmed);
}
