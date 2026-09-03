import 'dart:convert';

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
    this.needsPassword = false,
  });

  final String id;
  final String url;
  final String label;
  final String clientToken;
  final String? relayUrl;
  final bool needsPassword;

  String get displayLabel {
    final trimmed = label.trim();
    return trimmed.isEmpty ? url : trimmed;
  }

  SavedInstance copyWith({
    String? label,
    String? clientToken,
    String? relayUrl,
    bool? needsPassword,
  }) {
    return SavedInstance(
      id: id,
      url: url,
      label: label ?? this.label,
      clientToken: clientToken ?? this.clientToken,
      relayUrl: relayUrl ?? this.relayUrl,
      needsPassword: needsPassword ?? this.needsPassword,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'url': url,
        'label': label,
        'clientToken': clientToken,
        'relayUrl': relayUrl,
        'needsPassword': needsPassword,
      };

  static SavedInstance fromJson(Map<String, Object?> json) {
    return SavedInstance(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      label: json['label'] as String? ?? '',
      clientToken: json['clientToken'] as String? ?? '',
      relayUrl: json['relayUrl'] as String?,
      needsPassword: json['needsPassword'] as bool? ?? false,
    );
  }
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
/// First slice persists the raw payload URL; redeem/handshake is later.
class PairingLink {
  const PairingLink({required this.raw, this.payload, this.version});

  final String raw;
  final String? payload;
  final String? version;

  bool get isV2 => version == '2' && (payload != null && payload!.isNotEmpty);
}

PairingLink? parsePairingLink(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'openchamber') return null;
  if (uri.host != 'connect' && uri.path != '/connect' && uri.pathSegments.isEmpty) {
    if (uri.host != 'connect') return null;
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
