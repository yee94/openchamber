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

class MessageQueueAttachment {
  const MessageQueueAttachment({
    required this.attachmentID,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.source,
    required this.locator,
    this.occurrenceRefID = const [],
  });

  final String attachmentID;
  final String filename;
  final String mimeType;
  final int size;
  final String source;
  final Map<String, Object?> locator;
  final List<String> occurrenceRefID;

  Map<String, Object?> toJson() => {
        'attachmentID': attachmentID,
        'occurrenceRefID': occurrenceRefID,
        'filename': filename,
        'mimeType': mimeType,
        'size': size,
        'source': source,
        'locator': locator,
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
    this.attachments = const [],
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
  final List<MessageQueueAttachment> attachments;
}

class MessageQueueUpload {
  const MessageQueueUpload({
    required this.uploadID,
    required this.uploadToken,
    required this.expiresAt,
  });

  final String uploadID;
  final String uploadToken;
  final int expiresAt;
}

class MessageQueueEditReservation {
  const MessageQueueEditReservation({
    required this.revision,
    required this.scopeID,
    required this.queueItemID,
    required this.rowVersion,
    required this.token,
    required this.expiresAt,
    required this.generation,
  });

  final int revision;
  final String scopeID;
  final String queueItemID;
  final int rowVersion;
  final String token;
  final int expiresAt;
  final int generation;
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
  final attachments = parseMessageQueueAttachments(value['attachments']);
  if (value.containsKey('attachments') && attachments == null) return null;
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
    attachments: attachments ?? const [],
  );
}

List<MessageQueueAttachment>? parseMessageQueueAttachments(Object? value) {
  if (value == null) return const [];
  if (value is! List) return null;
  final attachments = <MessageQueueAttachment>[];
  for (final entry in value) {
    final attachment = parseMessageQueueAttachment(entry);
    if (attachment == null) return null;
    attachments.add(attachment);
  }
  return attachments;
}

MessageQueueAttachment? parseMessageQueueAttachment(Object? value) {
  if (value is! Map) return null;
  final attachmentID = value['attachmentID']?.toString() ?? '';
  final filename = value['filename']?.toString() ?? '';
  final mimeType = value['mimeType']?.toString() ?? '';
  final size = _asRevision(value['size']);
  final source = value['source']?.toString() ?? '';
  final locator = value['locator'];
  if (attachmentID.isEmpty || filename.isEmpty || mimeType.isEmpty || size == null || source.isEmpty || locator is! Map) {
    return null;
  }
  final occurrence = value['occurrenceRefID'];
  final refs = occurrence is List ? occurrence.map((item) => item.toString()).toList() : <String>[];
  return MessageQueueAttachment(
    attachmentID: attachmentID,
    filename: filename,
    mimeType: mimeType,
    size: size,
    source: source,
    locator: locator.map((key, item) => MapEntry(key.toString(), item)),
    occurrenceRefID: refs,
  );
}

MessageQueueUpload? parseMessageQueueUpload(Object? value) {
  if (value is! Map) return null;
  final uploadID = value['uploadID']?.toString() ?? '';
  final uploadToken = value['uploadToken']?.toString() ?? '';
  final expiresAt = _asRevision(value['expiresAt']);
  if (uploadID.isEmpty || uploadToken.isEmpty || expiresAt == null) return null;
  return MessageQueueUpload(uploadID: uploadID, uploadToken: uploadToken, expiresAt: expiresAt);
}

MessageQueueEditReservation? parseMessageQueueReservation(Object? value) {
  if (value is! Map) return null;
  final revision = _asRevision(value['revision']);
  final scopeID = value['scopeID']?.toString() ?? '';
  final queueItemID = value['queueItemID']?.toString() ?? '';
  final rowVersion = _asRevision(value['rowVersion']);
  final token = value['token']?.toString() ?? '';
  final expiresAt = _asRevision(value['expiresAt']);
  final generation = _asRevision(value['generation']);
  if (revision == null ||
      scopeID.isEmpty ||
      queueItemID.isEmpty ||
      rowVersion == null ||
      token.isEmpty ||
      expiresAt == null ||
      generation == null) {
    return null;
  }
  return MessageQueueEditReservation(
    revision: revision,
    scopeID: scopeID,
    queueItemID: queueItemID,
    rowVersion: rowVersion,
    token: token,
    expiresAt: expiresAt,
    generation: generation,
  );
}

/// Cap `arrayMove` for `PUT /scopes/:id/order`.
List<String> reorderQueueItemIds(List<MessageQueueItem> items, int from, int to) {
  final ids = items.map((item) => item.queueItemID).toList();
  if (from < 0 || from >= ids.length) return ids;
  var target = to;
  if (target > from) target -= 1;
  if (target < 0) target = 0;
  if (target > ids.length) target = ids.length;
  final moved = ids.removeAt(from);
  ids.insert(target > ids.length ? ids.length : target, moved);
  return ids;
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
