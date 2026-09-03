import 'dart:convert';

import 'pairing_payload.dart';
import 'secure_store.dart';

const instancesStorageKey = 'openchamber.instances.v1';
const activeInstanceStorageKey = 'openchamber.instances.active';
const localeStorageKey = 'openchamber.locale';
const themeStorageKey = 'openchamber.theme';

/// Saved OpenChamber server. Tokens are persisted via [SecureStore] and
/// must never be logged or interpolated into UI diagnostics.
class SavedInstance {
  const SavedInstance({
    required this.id,
    required this.url,
    this.label = '',
    this.clientToken = '',
    this.relayUrl,
    this.pairingId,
    this.pairingSecret = '',
    this.needsPassword = false,
    this.serverId,
    this.hostEncPubJwk,
    this.grant,
    this.lastUsedAt = 0,
  });

  final String id;
  final String url;
  final String label;
  final String clientToken;
  final String? relayUrl;
  final String? pairingId;
  final String pairingSecret;
  final bool needsPassword;
  final String? serverId;
  /// Public host ECDH JWK from pairing v2. Required to open the official tunnel.
  final Map<String, String>? hostEncPubJwk;
  /// Optional Layer-1 relay grant. Persist for reconnect; never log.
  final String? grant;
  final int lastUsedAt;

  String get displayLabel {
    final trimmed = label.trim();
    return trimmed.isEmpty ? url : trimmed;
  }

  SavedInstance copyWith({
    String? label,
    String? clientToken,
    String? relayUrl,
    String? pairingId,
    String? pairingSecret,
    bool? needsPassword,
    String? serverId,
    Map<String, String>? hostEncPubJwk,
    String? grant,
    int? lastUsedAt,
  }) {
    return SavedInstance(
      id: id,
      url: url,
      label: label ?? this.label,
      clientToken: clientToken ?? this.clientToken,
      relayUrl: relayUrl ?? this.relayUrl,
      pairingId: pairingId ?? this.pairingId,
      pairingSecret: pairingSecret ?? this.pairingSecret,
      needsPassword: needsPassword ?? this.needsPassword,
      serverId: serverId ?? this.serverId,
      hostEncPubJwk: hostEncPubJwk ?? this.hostEncPubJwk,
      grant: grant ?? this.grant,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  PairingRelayCandidate? get relayCandidate {
    final url = relayUrl?.trim();
    final sid = serverId?.trim();
    final jwk = hostEncPubJwk;
    if (url == null || url.isEmpty || sid == null || sid.isEmpty || jwk == null) {
      return null;
    }
    return PairingRelayCandidate(
      relayUrl: url,
      serverId: sid,
      hostEncPubJwk: jwk,
      grant: grant,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'url': url,
        'label': label,
        'relayUrl': relayUrl,
        'pairingId': pairingId,
        'needsPassword': needsPassword,
        'serverId': serverId,
        'hostEncPubJwk': hostEncPubJwk,
        if (grant != null && grant!.isNotEmpty) 'grant': grant,
        'lastUsedAt': lastUsedAt,
        'hasToken': clientToken.isNotEmpty,
      };

  static SavedInstance fromJson(Map<String, Object?> json) {
    return SavedInstance(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      label: json['label'] as String? ?? '',
      clientToken: json['clientToken'] as String? ?? '',
      relayUrl: json['relayUrl'] as String?,
      pairingId: json['pairingId'] as String?,
      pairingSecret: json['pairingSecret'] as String? ?? '',
      needsPassword: json['needsPassword'] as bool? ?? false,
      serverId: json['serverId'] as String?,
      hostEncPubJwk: _jwkFromJson(json['hostEncPubJwk']),
      grant: json['grant'] as String?,
      lastUsedAt: json['lastUsedAt'] is num ? (json['lastUsedAt'] as num).toInt() : 0,
    );
  }
}

Map<String, String>? _jwkFromJson(Object? value) {
  if (value is! Map) return null;
  final x = value['x']?.toString();
  final y = value['y']?.toString();
  if (x == null || y == null || x.isEmpty || y.isEmpty) return null;
  return {'kty': 'EC', 'crv': 'P-256', 'x': x, 'y': y};
}

String relayDisplayUrl(String serverId) => 'relay://$serverId';

bool isRelayDisplayUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  return uri != null && uri.scheme == 'relay' && uri.host.isNotEmpty;
}

class InstanceSnapshot {
  const InstanceSnapshot({
    required this.instances,
    this.activeId,
  });

  final List<SavedInstance> instances;
  final String? activeId;

  SavedInstance? get active {
    if (activeId == null) return null;
    for (final instance in instances) {
      if (instance.id == activeId) return instance;
    }
    return null;
  }
}

/// Validates a user-entered server URL. LAN `http://` is required on Android.
String? validateServerUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'connect.error.urlRequired';
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'connect.error.invalidUrl';
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return 'connect.error.invalidUrl';
  }
  return null;
}

/// Pairing v2 deep link: `openchamber://connect?v=2&p=...`.
class PairingLink {
  const PairingLink({
    required this.raw,
    this.payload,
    this.version,
    this.decoded,
  });

  final String raw;
  final String? payload;
  final String? version;
  final PairingConnectionPayload? decoded;

  bool get isV2 => version == '2' && (payload != null && payload!.isNotEmpty);
}

PairingLink? parsePairingLink(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final decoded = parsePairingConnectionPayload(value);
  if (decoded != null) {
    return PairingLink(raw: value, payload: 'decoded', version: '2', decoded: decoded);
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'openchamber') return null;
  if (uri.host != 'connect' && uri.path != '/connect') {
    return null;
  }
  final version = uri.queryParameters['v'];
  final payload = uri.queryParameters['p'];
  if (version == null && payload == null) return null;
  return PairingLink(raw: value, payload: payload, version: version);
}

class InstanceRepository {
  InstanceRepository(this._store);

  final SecureStore _store;

  Future<InstanceSnapshot> load() async {
    final raw = await _store.read(instancesStorageKey);
    final activeId = await _store.read(activeInstanceStorageKey);
    if (raw == null || raw.isEmpty) {
      return const InstanceSnapshot(instances: []);
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const InstanceSnapshot(instances: []);
    }
    final instances = <SavedInstance>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final instance = SavedInstance.fromJson(item.cast<String, Object?>());
        if (instance.id.isNotEmpty && instance.url.isNotEmpty) {
          instances.add(instance);
        }
      } else if (item is Map) {
        final instance = SavedInstance.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (instance.id.isNotEmpty && instance.url.isNotEmpty) {
          instances.add(instance);
        }
      }
    }
    return InstanceSnapshot(instances: instances, activeId: activeId);
  }

  Future<void> persist(InstanceSnapshot snapshot) async {
    final payload = jsonEncode(snapshot.instances.map((item) => item.toJson()).toList());
    await _store.write(instancesStorageKey, payload);
    if (snapshot.activeId == null) {
      await _store.delete(activeInstanceStorageKey);
    } else {
      await _store.write(activeInstanceStorageKey, snapshot.activeId!);
    }
  }
}
