import 'dart:math';

import 'message_id.dart';

/// Official `/api/openchamber/message-queue` shapes from
/// `packages/ui/src/lib/message-queue-server.ts`. Do not invent a local ledger.
const messageQueueRoute = '/api/openchamber/message-queue';

class MessageQueueServerError implements Exception {
  const MessageQueueServerError(this.status, this.code);

  final int status;
  final String code;

  @override
  String toString() => 'MessageQueueServerError($status $code)';
}

class MessageQueueSendConfig {
  const MessageQueueSendConfig({
    required this.providerID,
    required this.modelID,
    this.agent,
    this.variant,
  });

  final String providerID;
  final String modelID;
  final String? agent;
  final String? variant;

  Map<String, Object?> toJson() => {
        'providerID': providerID,
        'modelID': modelID,
        if (agent != null && agent!.isNotEmpty) 'agent': agent,
        if (variant != null && variant!.isNotEmpty) 'variant': variant,
      };
}

class MessageQueueItem {
  const MessageQueueItem({
    required this.queueItemID,
    required this.operationID,
    required this.messageID,
    required this.content,
    required this.status,
    required this.attemptCount,
    required this.position,
    required this.rowVersion,
    required this.createdAt,
    this.manualDispatchRequested = false,
  });

  final String queueItemID;
  final String operationID;
  final String messageID;
  final String content;
  final String status;
  final int attemptCount;
  final int position;
  final int rowVersion;
  final int createdAt;
  final bool manualDispatchRequested;
}

class MessageQueueScopeDescriptor {
  const MessageQueueScopeDescriptor({
    required this.scopeID,
    required this.revision,
    required this.directory,
    required this.sessionID,
    required this.worktreeState,
    required this.itemCount,
  });

  final String scopeID;
  final int revision;
  final String directory;
  final String sessionID;
  final String worktreeState;
  final int itemCount;
}

class MessageQueueScope {
  const MessageQueueScope({
    required this.scopeID,
    required this.revision,
    required this.directory,
    required this.sessionID,
    required this.worktreeState,
    required this.items,
    required this.itemCount,
  });

  final String scopeID;
  final int revision;
  final String directory;
  final String sessionID;
  final String worktreeState;
  final List<MessageQueueItem> items;
  final int itemCount;

  static MessageQueueScope empty({
    required String directory,
    required String sessionID,
    int revision = 0,
  }) {
    return MessageQueueScope(
      scopeID: '',
      revision: revision,
      directory: directory,
      sessionID: sessionID,
      worktreeState: 'ready',
      items: const [],
      itemCount: 0,
    );
  }
}

class MessageQueueSnapshot {
  const MessageQueueSnapshot({required this.revision, required this.scopes});

  final int revision;
  final List<MessageQueueScopeDescriptor> scopes;
}

class MessageQueueMutation {
  const MessageQueueMutation({
    required this.revision,
    this.scopeID,
    this.queueItemID,
    this.rowVersion,
    this.removedQueueItemID,
  });

  final int revision;
  final String? scopeID;
  final String? queueItemID;
  final int? rowVersion;
  final String? removedQueueItemID;
}

class MessageQueueAdmissionIdentity {
  const MessageQueueAdmissionIdentity({
    required this.requestID,
    required this.queueItemID,
    required this.operationID,
    required this.messageID,
    required this.createdAt,
  });

  final String requestID;
  final String queueItemID;
  final String operationID;
  final String messageID;
  final int createdAt;
}

final _random = Random.secure();

String _queueUuid() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

/// Cap `createServerQueueAdmissionIdentity` — `queued-` / `operation-` / `msg_`.
MessageQueueAdmissionIdentity createServerQueueAdmissionIdentity() {
  final id = _queueUuid();
  return MessageQueueAdmissionIdentity(
    requestID: id,
    queueItemID: 'queued-$id',
    operationID: 'operation-$id',
    messageID: ascendingId('msg'),
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
}

int? _asRevision(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value == value.roundToDouble()) return value.toInt();
  return null;
}

MessageQueueItem? parseMessageQueueItem(Object? value) {
  if (value is! Map) return null;
  final queueItemID = value['queueItemID']?.toString() ?? '';
  final operationID = value['operationID']?.toString() ?? '';
  final messageID = value['messageID']?.toString() ?? '';
  final content = value['content']?.toString();
  final status = value['status']?.toString() ?? '';
  final attemptCount = _asRevision(value['attemptCount']);
  final position = _asRevision(value['position']);
  final rowVersion = _asRevision(value['rowVersion']);
  final createdAt = _asRevision(value['createdAt']);
  if (queueItemID.isEmpty ||
      operationID.isEmpty ||
      messageID.isEmpty ||
      content == null ||
      status.isEmpty ||
      attemptCount == null ||
      position == null ||
      rowVersion == null ||
      createdAt == null) {
    return null;
  }
  return MessageQueueItem(
    queueItemID: queueItemID,
    operationID: operationID,
    messageID: messageID,
    content: content,
    status: status,
    attemptCount: attemptCount,
    position: position,
    rowVersion: rowVersion,
    createdAt: createdAt,
    manualDispatchRequested: value['manualDispatchRequested'] == true,
  );
}

MessageQueueScope? parseMessageQueueScope(Object? value) {
  if (value is! Map) return null;
  final scopeID = value['scopeID']?.toString() ?? '';
  final revision = _asRevision(value['revision']);
  final directory = value['directory']?.toString();
  final sessionID = value['sessionID']?.toString();
  final worktreeState = value['worktreeState']?.toString() ?? '';
  final itemCount = _asRevision(value['itemCount']);
  final rawItems = value['items'];
  if (scopeID.isEmpty ||
      revision == null ||
      directory == null ||
      sessionID == null ||
      worktreeState.isEmpty ||
      itemCount == null ||
      rawItems is! List) {
    return null;
  }
  final items = <MessageQueueItem>[];
  for (final entry in rawItems) {
    final item = parseMessageQueueItem(entry);
    if (item == null) return null;
    items.add(item);
  }
  return MessageQueueScope(
    scopeID: scopeID,
    revision: revision,
    directory: directory,
    sessionID: sessionID,
    worktreeState: worktreeState,
    items: items,
    itemCount: itemCount,
  );
}

MessageQueueSnapshot? parseMessageQueueSnapshot(Object? value) {
  if (value is! Map) return null;
  final revision = _asRevision(value['revision']);
  final rawScopes = value['scopes'];
  if (revision == null || rawScopes is! List) return null;
  final scopes = <MessageQueueScopeDescriptor>[];
  for (final entry in rawScopes) {
    if (entry is! Map) return null;
    final scopeID = entry['scopeID']?.toString() ?? '';
    final scopeRevision = _asRevision(entry['revision']);
    final directory = entry['directory']?.toString();
    final sessionID = entry['sessionID']?.toString();
    final worktreeState = entry['worktreeState']?.toString() ?? '';
    final itemCount = _asRevision(entry['itemCount']);
    if (scopeID.isEmpty ||
        scopeRevision == null ||
        directory == null ||
        sessionID == null ||
        worktreeState.isEmpty ||
        itemCount == null) {
      return null;
    }
    scopes.add(
      MessageQueueScopeDescriptor(
        scopeID: scopeID,
        revision: scopeRevision,
        directory: directory,
        sessionID: sessionID,
        worktreeState: worktreeState,
        itemCount: itemCount,
      ),
    );
  }
  return MessageQueueSnapshot(revision: revision, scopes: scopes);
}

MessageQueueMutation? parseMessageQueueMutation(Object? value) {
  if (value is! Map) return null;
  final revision = _asRevision(value['revision']);
  if (revision == null) return null;
  final rowVersion = _asRevision(value['rowVersion']);
  return MessageQueueMutation(
    revision: revision,
    scopeID: value['scopeID']?.toString(),
    queueItemID: value['queueItemID']?.toString(),
    rowVersion: rowVersion,
    removedQueueItemID: value['removedQueueItemID']?.toString(),
  );
}

String? parseMessageQueueErrorCode(Object? body, int status) {
  if (status == 501) return 'unavailable';
  if (body is Map && body['code'] is String) return body['code'] as String;
  return null;
}
