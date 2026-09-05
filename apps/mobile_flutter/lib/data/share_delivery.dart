import 'assistant_scheduled.dart';
import 'message_id.dart';
import '../native/share_targeting.dart';

/// Official `MobileShareState` plus cleanup phases from `MobileShareBridge.tsx`.
enum ShareDeliveryState {
  pending,
  resolvingInstance,
  connecting,
  offline,
  targetStale,
  dispatching,
  reconciling,
  delivered,
  failed,
}

enum ShareCleanupPhase { serverCompleted, nativeAcked, filesReleased }

class NativeShareAttachment {
  const NativeShareAttachment({
    required this.stagedPath,
    required this.originalName,
    required this.mime,
    required this.byteSize,
  });

  final String stagedPath;
  final String originalName;
  final String mime;
  final int byteSize;
}

class NativeShareEnvelope {
  const NativeShareEnvelope({
    required this.operationID,
    required this.serverInstanceID,
    required this.assistantID,
    this.text,
    this.attachments = const [],
    this.source = 'android-share',
    this.createdAt = 0,
    this.expiresAt = 0,
  });

  final String operationID;
  final String serverInstanceID;
  final String assistantID;
  final String? text;
  final List<NativeShareAttachment> attachments;
  final String source;
  final int createdAt;
  final int expiresAt;

  bool get hasAssignee => serverInstanceID.isNotEmpty && assistantID.isNotEmpty;
}

class NativeShareDraft {
  const NativeShareDraft({
    required this.draftID,
    this.serverInstanceID,
    this.assistantID,
    this.text,
    this.attachments = const [],
    this.source = 'android-share',
    this.createdAt = 0,
    this.expiresAt = 0,
  });

  final String draftID;
  final String? serverInstanceID;
  final String? assistantID;
  final String? text;
  final List<NativeShareAttachment> attachments;
  final String source;
  final int createdAt;
  final int expiresAt;

  bool get isAssigned {
    final server = serverInstanceID;
    final assistant = assistantID;
    return server != null && server.isNotEmpty && assistant != null && assistant.isNotEmpty;
  }
}

class ShareOperation {
  const ShareOperation({
    required this.operationID,
    required this.assistantID,
    required this.state,
    required this.phase,
    this.sessionID,
    this.messageID,
    this.attempt = 1,
    this.errorCode,
  });

  final String operationID;
  final String assistantID;
  final String state;
  final String phase;
  final String? sessionID;
  final String? messageID;
  final int attempt;
  final String? errorCode;

  bool get isRunning => state == 'running' || state == 'submitting';
  bool get isCompleted => state == 'completed';
  bool get isFailed => state == 'failed';
}

class ShareOutboxItem {
  ShareOutboxItem({
    required this.envelope,
    required this.messageID,
    this.state = ShareDeliveryState.pending,
    this.cleanupPhase,
    this.error,
    this.updatedAt = 0,
  });

  final NativeShareEnvelope envelope;
  final String messageID;
  ShareDeliveryState state;
  ShareCleanupPhase? cleanupPhase;
  String? error;
  int updatedAt;
}

class ShareDeliveryResult {
  const ShareDeliveryResult({
    required this.state,
    this.sessionID,
    this.assistantID,
    this.error,
    this.cleanupPhase,
  });

  final ShareDeliveryState state;
  final String? sessionID;
  final String? assistantID;
  final String? error;
  final ShareCleanupPhase? cleanupPhase;
}

/// Official `POST /api/openchamber/assistants/:id/share` parts.
class AssistantSharePart {
  const AssistantSharePart.text(this.text) : type = 'text', mime = null, url = null;
  const AssistantSharePart.file({required this.mime, required this.url}) : type = 'file', text = null;

  final String type;
  final String? text;
  final String? mime;
  final String? url;

  Map<String, Object?> toJson() {
    if (type == 'file') {
      return {'type': 'file', 'mime': mime, 'url': url};
    }
    return {'type': 'text', 'text': text};
  }
}

/// Builds native share-shortcut rows from the assistants snapshot — never
/// `assistantID = instance.id`.
List<ShareTarget> shareCatalogFromSnapshot({
  required String serverInstanceID,
  required String connectionKey,
  required String serverLabel,
  required bool featureEnabled,
  required List<AssistantRecord> assistants,
}) {
  if (serverInstanceID.isEmpty) return const [];
  return [
    for (final assistant in assistants)
      if (assistant.id.isNotEmpty)
        ShareTarget(
          serverInstanceId: serverInstanceID,
          assistantId: assistant.id,
          name: assistant.name.isEmpty ? assistant.id : assistant.name,
          enabled: featureEnabled && assistant.enabled,
          connectionKey: connectionKey,
          serverLabel: serverLabel,
        ),
  ];
}

List<AssistantSharePart> partsForShareEnvelope(NativeShareEnvelope envelope) {
  final parts = <AssistantSharePart>[];
  final text = envelope.text?.trim();
  if (text != null && text.isNotEmpty) {
    parts.add(AssistantSharePart.text(text));
  }
  if (envelope.attachments.length > 10) {
    throw const FormatException('too_many_share_attachments');
  }
  for (final attachment in envelope.attachments) {
    if (attachment.byteSize <= 0 || attachment.byteSize > 20 * 1024 * 1024) {
      throw const FormatException('invalid_share_attachment');
    }
    if (!attachment.mime.startsWith('image/')) {
      throw const FormatException('unsupported_share_attachment');
    }
    final path = attachment.stagedPath.trim();
    if (path.isEmpty) {
      throw const FormatException('staged_file_unavailable');
    }
    final url = path.contains(':') ? path : 'file://$path';
    parts.add(AssistantSharePart.file(mime: attachment.mime, url: url));
  }
  if (parts.isEmpty) {
    throw const FormatException('empty_share');
  }
  return parts;
}

NativeShareEnvelope envelopeFromAssignedDraft(NativeShareDraft draft) {
  return NativeShareEnvelope(
    operationID: draft.draftID,
    serverInstanceID: draft.serverInstanceID ?? '',
    assistantID: draft.assistantID ?? '',
    text: draft.text,
    attachments: draft.attachments,
    source: draft.source,
    createdAt: draft.createdAt,
    expiresAt: draft.expiresAt,
  );
}

class ShareDrainItem {
  const ShareDrainItem({required this.operationID, this.cleanupPhase});

  final String operationID;
  final ShareCleanupPhase? cleanupPhase;
}

Future<void> retryShareCleanupStage(Future<void> Function() work, {int attempts = 3}) async {
  Object? error;
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    try {
      await work();
      return;
    } catch (caught) {
      error = caught;
    }
  }
  throw error ?? Exception('cleanup_failed');
}

/// Official `drainMobileShareItems` — one failed operation does not block the rest.
Future<void> drainShareItems(
  List<ShareDrainItem> items, {
  required Future<void> Function(String operationID) deliver,
  required Future<void> Function(String operationID) cleanup,
  int concurrency = 1,
}) async {
  final seen = <String>{};
  final queue = <ShareDrainItem>[];
  for (final item in items) {
    if (seen.add(item.operationID)) queue.add(item);
  }
  var cursor = 0;
  Future<void> worker() async {
    while (cursor < queue.length) {
      final item = queue[cursor++];
      try {
        if (item.cleanupPhase != null && item.cleanupPhase != ShareCleanupPhase.filesReleased) {
          await cleanup(item.operationID);
        } else {
          await deliver(item.operationID);
        }
      } catch (_) {
        // Each operation retains its durable phase and yields to the next slot.
      }
    }
  }

  final workers = concurrency < 1 ? 1 : concurrency;
  await Future.wait(List.generate(workers.clamp(1, queue.isEmpty ? 1 : queue.length), (_) => worker()));
}

class ShareDelivery {
  ShareDelivery({
    required this.connect,
    required this.loadCapability,
    required this.loadSnapshot,
    required this.sendShare,
    required this.fetchShareOperation,
    required this.ack,
    required this.releaseFiles,
    this.wait = _defaultWait,
    this.messageId = _defaultMessageId,
    this.maxPolls = 60,
  });

  final Future<bool> Function(String serverInstanceID) connect;
  final Future<AssistantCapability?> Function() loadCapability;
  final Future<AssistantSnapshotView?> Function({bool force}) loadSnapshot;
  final Future<ShareOperation> Function({
    required String assistantID,
    required String operationID,
    required String messageID,
    required List<AssistantSharePart> parts,
    required String source,
  }) sendShare;
  final Future<ShareOperation> Function(String operationID) fetchShareOperation;
  final Future<void> Function(String operationID) ack;
  final Future<void> Function(String operationID) releaseFiles;
  final Future<void> Function(Duration duration) wait;
  final String Function() messageId;
  final int maxPolls;

  final Map<String, ShareOutboxItem> outbox = {};

  static Future<void> _defaultWait(Duration duration) => Future<void>.delayed(duration);
  static String _defaultMessageId() => ascendingId('msg');

  ShareOutboxItem _admit(NativeShareEnvelope envelope) {
    final existing = outbox[envelope.operationID];
    if (existing != null) return existing;
    final item = ShareOutboxItem(
      envelope: envelope,
      messageID: messageId(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    outbox[envelope.operationID] = item;
    return item;
  }

  Future<void> cleanupNativeDelivery(ShareOutboxItem item) async {
    if (item.cleanupPhase == ShareCleanupPhase.filesReleased) return;
    if (item.cleanupPhase == ShareCleanupPhase.serverCompleted) {
      await retryShareCleanupStage(() => ack(item.envelope.operationID));
      item
        ..state = ShareDeliveryState.delivered
        ..cleanupPhase = ShareCleanupPhase.nativeAcked
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
    }
    if (item.cleanupPhase == ShareCleanupPhase.nativeAcked) {
      await retryShareCleanupStage(() => releaseFiles(item.envelope.operationID));
      item
        ..state = ShareDeliveryState.delivered
        ..cleanupPhase = ShareCleanupPhase.filesReleased
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
    }
  }

  Future<ShareDeliveryResult> deliverOne(NativeShareEnvelope envelope) async {
    var item = _admit(envelope);
    if (item.cleanupPhase != null) {
      await cleanupNativeDelivery(item);
      return ShareDeliveryResult(state: item.state, cleanupPhase: item.cleanupPhase, assistantID: envelope.assistantID);
    }
    item
      ..state = ShareDeliveryState.resolvingInstance
      ..updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (!envelope.hasAssignee) {
      item
        ..state = ShareDeliveryState.targetStale
        ..error = 'missing_target';
      return ShareDeliveryResult(state: item.state, error: item.error);
    }
    item.state = ShareDeliveryState.connecting;
    final connected = await connect(envelope.serverInstanceID);
    if (!connected) {
      item
        ..state = ShareDeliveryState.offline
        ..error = 'offline';
      return ShareDeliveryResult(state: item.state, error: item.error);
    }
    final capability = await loadCapability();
    final snapshot = await loadSnapshot(force: false);
    if (capability == null ||
        !capability.supported ||
        capability.serverInstanceID != envelope.serverInstanceID ||
        snapshot == null) {
      item
        ..state = ShareDeliveryState.targetStale
        ..error = 'target_stale';
      return ShareDeliveryResult(state: item.state, error: item.error);
    }
    AssistantRecord? assistant;
    for (final candidate in snapshot.assistants) {
      if (candidate.id == envelope.assistantID && candidate.enabled) {
        assistant = candidate;
        break;
      }
    }
    if (!capability.enabled || assistant == null) {
      item
        ..state = ShareDeliveryState.targetStale
        ..error = 'target_stale';
      return ShareDeliveryResult(state: item.state, error: item.error);
    }
    item.state = ShareDeliveryState.dispatching;
    late final List<AssistantSharePart> parts;
    try {
      parts = partsForShareEnvelope(envelope);
    } on FormatException catch (error) {
      item
        ..state = ShareDeliveryState.failed
        ..error = error.message;
      return ShareDeliveryResult(state: item.state, error: item.error);
    }
    item.state = ShareDeliveryState.reconciling;
    try {
      var operation = await sendShare(
        assistantID: assistant.id,
        operationID: envelope.operationID,
        messageID: item.messageID,
        parts: parts,
        source: envelope.source == 'ios-share' ? 'ios-share' : 'android-share',
      );
      operation = await waitForShare(operation);
      final refreshed = await loadSnapshot(force: true);
      if (refreshed == null) {
        item
          ..state = ShareDeliveryState.reconciling
          ..error = 'snapshot_refresh_failed';
        return ShareDeliveryResult(state: item.state, error: item.error);
      }
      AssistantRecord? bound;
      for (final candidate in refreshed.assistants) {
        if (candidate.id == assistant.id) bound = candidate;
      }
      if (bound == null || bound.sessionId != operation.sessionID) {
        item
          ..state = ShareDeliveryState.reconciling
          ..error = 'assistant_binding_mismatch';
        return ShareDeliveryResult(state: item.state, error: item.error);
      }
      item
        ..state = ShareDeliveryState.delivered
        ..cleanupPhase = ShareCleanupPhase.serverCompleted
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      await cleanupNativeDelivery(item);
      return ShareDeliveryResult(
        state: ShareDeliveryState.delivered,
        sessionID: operation.sessionID,
        assistantID: assistant.id,
        cleanupPhase: item.cleanupPhase,
      );
    } on ShareUnresolvedException catch (error) {
      item
        ..state = ShareDeliveryState.reconciling
        ..error = error.code;
      return ShareDeliveryResult(state: item.state, error: item.error);
    } catch (error) {
      item
        ..state = ShareDeliveryState.failed
        ..error = error.toString();
      return ShareDeliveryResult(state: item.state, error: item.error);
    }
  }

  Future<ShareOperation> waitForShare(ShareOperation operation) async {
    var current = operation;
    for (var attempt = 0; attempt < maxPolls && current.isRunning; attempt += 1) {
      await wait(const Duration(milliseconds: 750));
      current = await fetchShareOperation(current.operationID);
    }
    if (current.isCompleted) return current;
    if (current.isFailed) {
      throw ShareUnresolvedException(current.errorCode ?? 'share_failed');
    }
    throw const ShareUnresolvedException('share_unresolved');
  }
}

class ShareUnresolvedException implements Exception {
  const ShareUnresolvedException(this.code);
  final String code;

  @override
  String toString() => code;
}

ShareOperation parseShareOperation(Object? payload) {
  final root = payload is Map ? payload.map((key, value) => MapEntry(key.toString(), value)) : <String, Object?>{};
  final operationID = root['operationID']?.toString() ?? '';
  final assistantID = root['assistantID']?.toString() ?? '';
  final state = root['state']?.toString() ?? '';
  final phase = root['phase']?.toString() ?? '';
  if (operationID.isEmpty || assistantID.isEmpty || state.isEmpty || phase.isEmpty) {
    throw const FormatException('invalid_share_operation');
  }
  return ShareOperation(
    operationID: operationID,
    assistantID: assistantID,
    state: state,
    phase: phase,
    sessionID: root['sessionID']?.toString(),
    messageID: root['messageID']?.toString(),
    attempt: root['attempt'] is num ? (root['attempt'] as num).toInt() : 1,
    errorCode: root['errorCode']?.toString(),
  );
}

NativeShareEnvelope? parseShareEnvelope(Object? payload) {
  if (payload is! Map) return null;
  final root = payload.map((key, value) => MapEntry(key.toString(), value));
  final operationID = root['operationID']?.toString() ?? '';
  final server = root['serverInstanceID']?.toString() ?? '';
  final assistant = root['assistantID']?.toString() ?? '';
  if (operationID.isEmpty) return null;
  final attachments = <NativeShareAttachment>[];
  final rawAttachments = root['attachments'];
  if (rawAttachments is List) {
    for (final item in rawAttachments) {
      if (item is! Map) continue;
      final row = item.map((key, value) => MapEntry(key.toString(), value));
      attachments.add(
        NativeShareAttachment(
          stagedPath: row['stagedPath']?.toString() ?? '',
          originalName: row['originalName']?.toString() ?? '',
          mime: row['mime']?.toString() ?? '',
          byteSize: row['byteSize'] is num ? (row['byteSize'] as num).toInt() : 0,
        ),
      );
    }
  }
  return NativeShareEnvelope(
    operationID: operationID,
    serverInstanceID: server,
    assistantID: assistant,
    text: root['text']?.toString(),
    attachments: attachments,
    source: root['source']?.toString() ?? 'android-share',
    createdAt: root['createdAt'] is num ? (root['createdAt'] as num).toInt() : 0,
    expiresAt: root['expiresAt'] is num ? (root['expiresAt'] as num).toInt() : 0,
  );
}

NativeShareDraft? parseShareDraft(Object? payload) {
  if (payload is! Map) return null;
  final root = payload.map((key, value) => MapEntry(key.toString(), value));
  final draftID = root['draftID']?.toString() ?? '';
  if (draftID.isEmpty) return null;
  final attachments = <NativeShareAttachment>[];
  final rawAttachments = root['attachments'];
  if (rawAttachments is List) {
    for (final item in rawAttachments) {
      if (item is! Map) continue;
      final row = item.map((key, value) => MapEntry(key.toString(), value));
      attachments.add(
        NativeShareAttachment(
          stagedPath: row['stagedPath']?.toString() ?? '',
          originalName: row['originalName']?.toString() ?? '',
          mime: row['mime']?.toString() ?? '',
          byteSize: row['byteSize'] is num ? (row['byteSize'] as num).toInt() : 0,
        ),
      );
    }
  }
  return NativeShareDraft(
    draftID: draftID,
    serverInstanceID: root['serverInstanceID']?.toString(),
    assistantID: root['assistantID']?.toString(),
    text: root['text']?.toString(),
    attachments: attachments,
    source: root['source']?.toString() ?? 'android-share',
    createdAt: root['createdAt'] is num ? (root['createdAt'] as num).toInt() : 0,
    expiresAt: root['expiresAt'] is num ? (root['expiresAt'] as num).toInt() : 0,
  );
}
