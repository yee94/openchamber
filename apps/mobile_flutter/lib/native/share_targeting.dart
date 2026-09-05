/// Exact instance + assistant targeting. Never silently pick a default.
class ShareTarget {
  const ShareTarget({
    required this.serverInstanceId,
    required this.assistantId,
    required this.name,
    this.enabled = true,
    this.connectionKey = '',
    this.serverLabel = '',
  });

  final String serverInstanceId;
  final String assistantId;
  final String name;
  final bool enabled;
  final String connectionKey;
  final String serverLabel;

  String get conversationId {
    final identity = '$serverInstanceId\u{0}$assistantId';
    return 'openchamber.assistant.v1.${Uri.encodeComponent(identity)}';
  }

  Map<String, Object?> toNativeEntry() {
    return {
      'serverInstanceID': serverInstanceId,
      'assistantID': assistantId,
      'name': name,
      'avatarSeed': assistantId,
      'serverLabel': serverLabel,
      'connectionKey': connectionKey,
      'enabled': enabled,
      'isDefaultShareTarget': false,
    };
  }
}

ShareTarget? exactShareTarget({
  required List<ShareTarget> catalog,
  String? serverInstanceId,
  String? assistantId,
}) {
  if (serverInstanceId == null || assistantId == null) return null;
  if (serverInstanceId.isEmpty || assistantId.isEmpty) return null;
  for (final entry in catalog) {
    if (!entry.enabled) continue;
    if (entry.serverInstanceId == serverInstanceId && entry.assistantId == assistantId) {
      return entry;
    }
  }
  return null;
}
