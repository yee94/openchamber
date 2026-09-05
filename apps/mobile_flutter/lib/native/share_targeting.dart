/// Exact instance + assistant targeting. Never silently pick a default.
class ShareTarget {
  const ShareTarget({
    required this.serverInstanceId,
    required this.assistantId,
    required this.name,
    this.enabled = true,
  });

  final String serverInstanceId;
  final String assistantId;
  final String name;
  final bool enabled;

  String get conversationId {
    final identity = '$serverInstanceId\u{0}$assistantId';
    return 'openchamber.assistant.v1.${Uri.encodeComponent(identity)}';
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
