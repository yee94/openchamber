import 'dart:convert';

import 'chat_parts.dart';
import 'chat_timeline.dart';
import 'home_session.dart';
import 'openchamber_http.dart';
import 'prompt_attachment.dart';
import 'session_index.dart';

/// Official OpenChamber / OpenCode calls used by mobile connect + home + chat.
class CreatedSession {
  const CreatedSession({required this.id, this.title, this.directory});

  final String id;
  final String? title;
  final String? directory;
}

class FilesystemEntry {
  const FilesystemEntry({required this.name, required this.path, required this.type});

  final String name;
  final String path;
  final String type;

  bool get isDirectory => type == 'directory';
}

class OpenChamberApi {
  OpenChamberApi({OpenChamberTransport? transport})
      : transport = transport ?? LiveOpenChamberTransport();

  OpenChamberTransport transport;

  Future<HealthResult> health(Uri base) async {
    final response = await transport.send(
      base,
      const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.health, timeout: Duration(milliseconds: 2500)),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.health);
    }
    final body = response.map;
    return HealthResult(
      ok: true,
      serverId: body['serverId'] as String?,
      openchamberVersion: body['openchamberVersion'] as String?,
    );
  }

  Future<AuthSessionResult> getAuthSession(Uri base, {String? bearer}) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(method: 'GET', path: OpenChamberPaths.authSession, bearer: bearer),
    );
    final body = response.map;
    if (response.status == 401) {
      return AuthSessionResult(
        authenticated: body['authenticated'] == true,
        locked: body['locked'] == true || body['authenticated'] != true,
        tunnelLocked: body['tunnelLocked'] == true,
        scope: body['scope'] as String?,
      );
    }
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.authSession);
    }
    return AuthSessionResult(
      authenticated: body['authenticated'] == true,
      locked: body['locked'] == true,
      disabled: body['disabled'] == true,
      scope: body['scope'] as String?,
      tunnelLocked: body['tunnelLocked'] == true,
    );
  }

  Future<UnlockResult> unlockWithPassword({
    required Uri base,
    required String password,
    required String deviceId,
    String? devicePlatform,
  }) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.authSession,
        body: {
          'password': password,
          'trustDevice': true,
          'issueClientToken': true,
          'clientLabel': 'OpenChamber Mobile',
          'clientKind': 'mobile',
          if (devicePlatform != null) 'devicePlatform': devicePlatform,
          'dedupeKey': 'mobile:$deviceId',
        },
      ),
    );
    if (response.status == 401 || response.status == 429 || response.status == 400 || response.status == 403) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.authSession, code: 'auth');
    }
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.authSession);
    }
    final body = response.map;
    return UnlockResult(
      authenticated: body['authenticated'] == true,
      clientToken: body['clientToken'] as String?,
    );
  }

  Future<RedeemResult> redeemPairing({
    required Uri base,
    required String pairingId,
    required String secret,
    required String deviceId,
    String? devicePlatform,
    String? bearer,
  }) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.pairingRedeem,
        bearer: bearer,
        body: {
          'pairingId': pairingId,
          'secret': secret,
          'clientLabel': 'OpenChamber Mobile',
          'clientKind': 'mobile',
          'deviceName': 'OpenChamber Mobile',
          if (devicePlatform != null) 'devicePlatform': devicePlatform,
          'dedupeKey': 'mobile:$deviceId',
        },
      ),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.pairingRedeem, code: 'redeem');
    }
    final body = response.map;
    final server = body['server'];
    Map<String, Object?> serverMap = const {};
    if (server is Map) {
      serverMap = server.map((key, value) => MapEntry(key.toString(), value));
    }
    return RedeemResult(
      ok: body['ok'] == true,
      clientToken: body['clientToken'] as String?,
      serverLabel: serverMap['label'] as String?,
      serverUrl: serverMap['url'] as String?,
    );
  }

  /// Official `GET /api/client-auth/connection/candidates`. Fetch failure is
  /// `null` (skip) — never an authoritative empty LAN list.
  Future<Map<String, Object?>?> loadConnectionCandidates(Uri base, {String? bearer}) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(method: 'GET', path: OpenChamberPaths.connectionCandidates, bearer: bearer),
    );
    if (!response.ok) return null;
    return response.map;
  }

  Future<SessionIndexSnapshot?> loadSessionIndex(Uri base, {required String bearer}) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(method: 'GET', path: OpenChamberPaths.sessionIndex, bearer: bearer),
    );
    if (response.status == 501) return null;
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.sessionIndex);
    }
    return parseSessionIndexSnapshot(response.body);
  }

  Future<void> startSessionIndexSync(Uri base, {required String bearer, required List<String> directories}) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.sessionIndexSync,
        bearer: bearer,
        body: {'directories': directories},
      ),
    );
    if (response.status == 501) return;
    if (!response.ok && response.status != 202) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.sessionIndexSync);
    }
  }

  Future<List<ChatMessage>> loadTranscript({
    required Uri base,
    required String bearer,
    required String sessionId,
    required String directory,
  }) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'GET',
        path: OpenChamberPaths.sessionMessages(sessionId),
        bearer: bearer,
        query: {
          'directory': directory,
          'turns': '6',
        },
      ),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.sessionMessages(sessionId));
    }
    List<PermissionRequestRecord> permissions = const [];
    try {
      final permissionPayload = await getPermissions(base: base, bearer: bearer, directory: directory);
      permissions = parsePermissionList(permissionPayload, sessionId: sessionId);
    } on OpenChamberHttpException {
      // Transcript still renders; missing permission list is not empty success.
    }
    return parseTurnPageMessages(response.body, permissions: permissions);
  }

  Future<Object?> getPermissions({required Uri base, String? bearer, String? directory}) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'GET',
        path: OpenChamberPaths.permissions,
        query: {
          if (directory != null && directory.isNotEmpty) 'directory': directory,
        },
      ),
      bearer,
    );
  }

  Future<Object?> replyToPermission({
    required Uri base,
    String? bearer,
    required String requestId,
    required String reply,
    String? directory,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.permissionReply(requestId),
        body: {
          'reply': reply,
          if (directory != null && directory.isNotEmpty) 'directory': directory,
        },
      ),
      bearer,
    );
  }

  Future<Object?> startProviderOAuth({
    required Uri base,
    String? bearer,
    required String providerId,
    int method = 0,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.providerOAuthAuthorize(providerId),
        body: {'method': method},
      ),
      bearer,
    );
  }

  Future<Object?> completeProviderOAuth({
    required Uri base,
    String? bearer,
    required String providerId,
    int method = 0,
    String? code,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.providerOAuthCallback(providerId),
        body: {
          'method': method,
          if (code != null && code.isNotEmpty) 'code': code,
        },
      ),
      bearer,
    );
  }

  Future<Object?> startMcpOAuth({required Uri base, String? bearer, required String name}) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.mcpAuthStart(name),
        body: {'name': name},
      ),
      bearer,
    );
  }

  Future<Object?> completeMcpOAuth({
    required Uri base,
    String? bearer,
    required String name,
    required String code,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.mcpAuthCallback(name),
        body: {'name': name, 'code': code},
      ),
      bearer,
    );
  }

  Future<Object?> queueMcpAuthPending({
    required Uri base,
    String? bearer,
    required String state,
    required String name,
    String? directory,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.mcpAuthPending,
        body: {
          'state': state,
          'name': name,
          'directory': directory,
        },
      ),
      bearer,
    );
  }

  Future<Object?> getMcpAuthPending({required Uri base, String? bearer, required String state}) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'GET',
        path: OpenChamberPaths.mcpAuthPending,
        query: {'state': state},
      ),
      bearer,
    );
  }

  Future<void> clearMcpAuthPending({required Uri base, String? bearer, required String state}) async {
    try {
      await _requireOk(
        base,
        OpenChamberRequest(
          method: 'DELETE',
          path: OpenChamberPaths.mcpAuthPending,
          query: {'state': state},
        ),
        bearer,
      );
    } on OpenChamberHttpException {
      // Cleanup is best-effort, same as the official callback page.
    }
  }

  Future<Object?> getPluginFile({required Uri base, String? bearer, required String id}) {
    return _requireOk(
      base,
      OpenChamberRequest(method: 'GET', path: OpenChamberPaths.pluginFile(id)),
      bearer,
    );
  }

  Future<Object?> runScheduledTaskNow({
    required Uri base,
    String? bearer,
    required String projectId,
    required String taskId,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.scheduledTaskRun(projectId, taskId),
      ),
      bearer,
    );
  }

  Future<void> promptAsync({
    required Uri base,
    required String bearer,
    required String sessionId,
    required String directory,
    required String messageId,
    String text = '',
    List<PromptFilePart> files = const [],
  }) async {
    final path = OpenChamberPaths.sessionPromptAsync(sessionId);
    final parts = <Map<String, Object?>>[
      if (text.isNotEmpty) {'type': 'text', 'text': text},
      for (final file in files)
        {
          'type': 'file',
          'mime': file.mime,
          'filename': file.filename,
          'url': file.url,
        },
    ];
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: path,
        bearer: bearer,
        body: {
          'sessionID': sessionId,
          'directory': directory,
          'messageID': messageId,
          'parts': parts,
        },
      ),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, path);
    }
  }

  Future<PromptAttachmentUploadResult> putPromptAttachment({
    required Uri base,
    String? bearer,
    required String attachmentId,
    required List<int> bytes,
    required String mime,
    required String sha256,
    String? filename,
  }) async {
    final path = OpenChamberPaths.promptAttachment(attachmentId);
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'PUT',
        path: path,
        bearer: bearer,
        bytes: bytes,
        extraHeaders: {
          'Content-Type': mime,
          'Content-Length': '${bytes.length}',
          'X-OpenChamber-Content-Length': '${bytes.length}',
          'X-OpenChamber-Sha256': sha256,
          'X-OpenChamber-Mime': mime,
          if (filename != null && filename.isNotEmpty)
            'X-OpenChamber-Filename': Uri.encodeComponent(filename),
        },
        timeout: const Duration(seconds: 30),
      ),
    );
    if (response.status == 413) {
      throw const PromptAttachmentUploadError(413, 'too-large');
    }
    if (!response.ok) {
      throw PromptAttachmentUploadError(
        response.status,
        response.status >= 500 || response.status == 0 ? 'unavailable' : 'rejected',
      );
    }
    final body = response.map;
    final storedPath = body['path']?.toString() ?? '';
    if (storedPath.isEmpty) {
      throw PromptAttachmentUploadError(response.status, 'unavailable');
    }
    final size = body['size'];
    return PromptAttachmentUploadResult(
      path: storedPath,
      url: toPromptAttachmentFileUrl(storedPath),
      mime: body['mime']?.toString().isNotEmpty == true ? body['mime'].toString() : mime,
      size: size is int ? size : bytes.length,
      sha256: body['sha256']?.toString() ?? sha256,
    );
  }

  Future<void> abortSession({
    required Uri base,
    required String bearer,
    required String sessionId,
    required String directory,
  }) async {
    final path = OpenChamberPaths.sessionAbort(sessionId);
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: path,
        bearer: bearer,
        body: {
          'sessionID': sessionId,
          if (directory.isNotEmpty) 'directory': directory,
        },
      ),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, path);
    }
  }

  Future<Map<String, String>> sessionStatus({
    required Uri base,
    required String bearer,
    String? directory,
  }) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'GET',
        path: OpenChamberPaths.sessionStatus,
        bearer: bearer,
        query: {
          if (directory != null && directory.isNotEmpty) 'directory': directory,
        },
      ),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.sessionStatus);
    }
    return parseSessionStatusMap(response.body);
  }

  Future<void> registerPushToken({
    required Uri base,
    required String bearer,
    required String token,
    required String platform,
    String? locale,
  }) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.pushApnsToken,
        bearer: bearer,
        body: {
          'token': token,
          'platform': platform,
          if (locale != null) 'locale': locale,
        },
      ),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.pushApnsToken);
    }
  }

  Future<void> setVisibility({
    required Uri base,
    required String bearer,
    required bool visible,
    required String platform,
  }) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.pushVisibility,
        bearer: bearer,
        body: {
          'visible': visible,
          'platform': platform,
        },
      ),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.pushVisibility);
    }
  }

  /// OpenCode `session.create` → `POST /api/session` with `directory` query.
  /// See `packages/ui/src/lib/opencode/client.ts` `createSession`.
  Future<CreatedSession> createSession({
    required Uri base,
    required String bearer,
    required String directory,
    String? title,
  }) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.sessionCreate,
        bearer: bearer,
        query: {
          if (directory.isNotEmpty) 'directory': directory,
        },
        body: {
          if (title != null && title.isNotEmpty) 'title': title,
        },
      ),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.sessionCreate);
    }
    final created = parseCreatedSession(response.body);
    if (created == null || created.id.isEmpty) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.sessionCreate, code: 'malformed');
    }
    return created;
  }

  /// OpenCode `session.update` → PATCH `/api/session/:id?directory=`.
  Future<Object?> updateSession({
    required Uri base,
    required String bearer,
    required String sessionId,
    String? directory,
    String? title,
    num? archivedAt,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'PATCH',
        path: OpenChamberPaths.session(sessionId),
        bearer: bearer,
        query: {
          if (directory != null && directory.isNotEmpty) 'directory': directory,
        },
        body: {
          if (title != null) 'title': title,
          if (archivedAt != null) 'time': {'archived': archivedAt},
        },
      ),
      bearer,
    );
  }

  /// OpenCode `session.delete` → DELETE `/api/session/:id?directory=`.
  /// Official cascade treats 404 as success.
  Future<void> deleteSession({
    required Uri base,
    required String bearer,
    required String sessionId,
    String? directory,
  }) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'DELETE',
        path: OpenChamberPaths.session(sessionId),
        bearer: bearer,
        query: {
          if (directory != null && directory.isNotEmpty) 'directory': directory,
        },
      ),
    );
    if (response.status == 404 || response.ok) return;
    throw OpenChamberHttpException(response.status, OpenChamberPaths.session(sessionId));
  }

  /// GET `/api/session/:id?directory=` — hydrates official `share.url`.
  Future<Map<String, Object?>> getSession({
    required Uri base,
    required String bearer,
    required String sessionId,
    String? directory,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(
        method: 'GET',
        path: OpenChamberPaths.session(sessionId),
        bearer: bearer,
        query: {
          if (directory != null && directory.isNotEmpty) 'directory': directory,
        },
      ),
      bearer,
    );
  }

  /// OpenCode `session.share` → POST `/api/session/:id/share?directory=`.
  Future<Map<String, Object?>> shareSession({
    required Uri base,
    required String bearer,
    required String sessionId,
    String? directory,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.sessionShare(sessionId),
        bearer: bearer,
        query: {
          if (directory != null && directory.isNotEmpty) 'directory': directory,
        },
      ),
      bearer,
    );
  }

  /// OpenCode `session.unshare` → DELETE `/api/session/:id/share?directory=`.
  Future<Map<String, Object?>> unshareSession({
    required Uri base,
    required String bearer,
    required String sessionId,
    String? directory,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(
        method: 'DELETE',
        path: OpenChamberPaths.sessionShare(sessionId),
        bearer: bearer,
        query: {
          if (directory != null && directory.isNotEmpty) 'directory': directory,
        },
      ),
      bearer,
    );
  }

  /// POST `/api/openchamber/session-index/session/:id/pin`. 501 = unsupported.
  Future<void> pinSession({
    required Uri base,
    required String bearer,
    required String sessionId,
  }) async {
    await _requirePin(
      base,
      OpenChamberRequest(method: 'POST', path: OpenChamberPaths.sessionIndexPin(sessionId), bearer: bearer),
    );
  }

  /// DELETE `/api/openchamber/session-index/session/:id/pin`. 501 = unsupported.
  Future<void> unpinSession({
    required Uri base,
    required String bearer,
    required String sessionId,
  }) async {
    await _requirePin(
      base,
      OpenChamberRequest(method: 'DELETE', path: OpenChamberPaths.sessionIndexPin(sessionId), bearer: bearer),
    );
  }

  Future<String> getFilesystemHome({required Uri base, String? bearer}) async {
    final body = await _requireMap(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.fsHome), bearer);
    final home = body['home']?.toString().trim() ?? '';
    if (home.isEmpty) {
      throw const OpenChamberHttpException(200, OpenChamberPaths.fsHome, code: 'malformed');
    }
    return home;
  }

  Future<List<FilesystemEntry>> listFilesystem({
    required Uri base,
    String? bearer,
    required String path,
  }) async {
    final body = await _requireMap(
      base,
      OpenChamberRequest(method: 'GET', path: OpenChamberPaths.fsList, query: {'path': path}),
      bearer,
    );
    final entries = body['entries'];
    if (entries is! List) return const [];
    return entries.whereType<Map>().map((item) {
      final map = item.map((key, value) => MapEntry(key.toString(), value));
      return FilesystemEntry(
        name: map['name']?.toString() ?? '',
        path: map['path']?.toString() ?? '',
        type: map['type']?.toString() ?? '',
      );
    }).where((entry) => entry.path.isNotEmpty).toList();
  }

  Future<bool> checkIsGitRepository({
    required Uri base,
    String? bearer,
    required String directory,
  }) async {
    final body = await _requireMap(
      base,
      OpenChamberRequest(method: 'GET', path: OpenChamberPaths.gitCheck, query: {'directory': directory}),
      bearer,
    );
    return body['isGitRepository'] == true;
  }

  Future<Map<String, Object?>> createGitWorktree({
    required Uri base,
    String? bearer,
    required String directory,
    required String worktreeName,
    String? branchName,
    String? startRef,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.gitWorktrees,
        query: {'directory': directory},
        body: {
          'mode': 'new',
          'worktreeName': worktreeName,
          if (branchName != null && branchName.trim().isNotEmpty) 'branchName': branchName.trim(),
          if (startRef != null && startRef.trim().isNotEmpty) 'startRef': startRef.trim(),
        },
      ),
      bearer,
    );
  }

  /// Official DirectoryExplorer `POST /api/fs/mkdir`.
  Future<String> createDirectory({
    required Uri base,
    String? bearer,
    required String path,
  }) async {
    final body = await _requireMap(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.fsMkdir,
        body: {'path': path},
      ),
      bearer,
    );
    final created = body['path']?.toString().trim();
    if (created != null && created.isNotEmpty) return created;
    return path;
  }

  Future<bool> githubAuthConnected({
    required Uri base,
    String? bearer,
  }) async {
    final body = await _requireMap(
      base,
      const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.githubAuthStatus),
      bearer,
    );
    return body['connected'] == true;
  }

  Future<Map<String, Object?>> listGithubIssues({
    required Uri base,
    String? bearer,
    required String directory,
    int page = 1,
    String? query,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(
        method: 'GET',
        path: OpenChamberPaths.githubIssuesList,
        query: {
          'directory': directory,
          'page': '$page',
          if (query != null && query.isNotEmpty) 'query': query,
        },
      ),
      bearer,
    );
  }

  Future<Map<String, Object?>> listGithubPulls({
    required Uri base,
    String? bearer,
    required String directory,
    int page = 1,
    String? query,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(
        method: 'GET',
        path: OpenChamberPaths.githubPullsList,
        query: {
          'directory': directory,
          'page': '$page',
          if (query != null && query.isNotEmpty) 'query': query,
        },
      ),
      bearer,
    );
  }

  Future<Map<String, Object?>> fetchWorktreeOrder({
    required Uri base,
    String? bearer,
    required String projectDirectory,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(
        method: 'GET',
        path: OpenChamberPaths.messageQueueWorktreeOrder,
        query: {'projectDirectory': projectDirectory},
      ),
      bearer,
    );
  }

  Future<Map<String, Object?>> putWorktreeOrder({
    required Uri base,
    String? bearer,
    required String requestId,
    required String projectDirectory,
    required int expectedRevision,
    required List<String> orderedPaths,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(
        method: 'PUT',
        path: OpenChamberPaths.messageQueueWorktreeOrder,
        body: {
          'requestID': requestId,
          'projectDirectory': projectDirectory,
          'expectedRevision': expectedRevision,
          'orderedPaths': orderedPaths,
        },
      ),
      bearer,
    );
  }

  Future<Map<String, Object?>> upsertScheduledTask({
    required Uri base,
    String? bearer,
    required String projectId,
    required Map<String, Object?> task,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(
        method: 'PUT',
        path: OpenChamberPaths.scheduledTasksForProject(projectId),
        body: {'task': task},
      ),
      bearer,
    );
  }

  Future<Map<String, Object?>> forkSession({
    required Uri base,
    String? bearer,
    required String sessionId,
    String? messageId,
    String? directory,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.sessionFork(sessionId),
        query: {
          if (directory != null && directory.isNotEmpty) 'directory': directory,
        },
        body: {
          if (messageId != null && messageId.isNotEmpty) 'messageID': messageId,
        },
      ),
      bearer,
    );
  }

  /// Official DirectoryExplorer `POST /api/fs/clone`.
  Future<String> cloneRepository({
    required Uri base,
    String? bearer,
    required String remoteUrl,
    required String destinationPath,
    String? gitIdentityId,
  }) async {
    final body = await _requireMap(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.fsClone,
        body: {
          'remoteUrl': remoteUrl,
          'destinationPath': destinationPath,
          if (gitIdentityId != null && gitIdentityId.isNotEmpty) 'gitIdentityId': gitIdentityId,
        },
      ),
      bearer,
    );
    final path = body['path']?.toString().trim();
    if (path != null && path.isNotEmpty) return path;
    return destinationPath;
  }

  /// Official `POST /api/projects/:id/icon/discover`.
  Future<Map<String, Object?>> discoverProjectIcon({
    required Uri base,
    String? bearer,
    required String projectId,
    bool force = false,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.projectIconDiscover(projectId),
        body: {'force': force},
      ),
      bearer,
    );
  }

  Future<void> deleteGitWorktree({
    required Uri base,
    String? bearer,
    required String directory,
    required String worktreePath,
  }) async {
    await _requireOk(
      base,
      OpenChamberRequest(
        method: 'DELETE',
        path: OpenChamberPaths.gitWorktrees,
        query: {'directory': directory},
        body: {'directory': worktreePath},
      ),
      bearer,
    );
  }

  Future<void> _requirePin(Uri base, OpenChamberRequest request) async {
    final response = await transport.send(base, request);
    if (response.status == 501) {
      throw OpenChamberHttpException(501, request.path, code: 'unsupported');
    }
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, request.path);
    }
  }

  Stream<List<int>> openGlobalEventStream({
    required Uri base,
    required String bearer,
    String? lastEventId,
  }) {
    return transport.openByteStream(
      base,
      OpenChamberRequest(
        method: 'GET',
        path: OpenChamberPaths.globalEvent,
        bearer: bearer,
        stream: true,
        extraHeaders: {
          'accept': 'text/event-stream',
          if (lastEventId != null && lastEventId.isNotEmpty) 'Last-Event-ID': lastEventId,
        },
        timeout: const Duration(seconds: 30),
      ),
    );
  }

  Future<Map<String, Object?>> getConfigSettings({required Uri base, String? bearer}) {
    return _requireMap(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.configSettings), bearer);
  }

  Future<Map<String, Object?>> putConfigSettings({
    required Uri base,
    String? bearer,
    required Map<String, Object?> changes,
  }) {
    return _requireMap(
      base,
      OpenChamberRequest(method: 'PUT', path: OpenChamberPaths.configSettings, body: changes),
      bearer,
    );
  }

  Future<Object?> getProviderCatalog({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.providerCatalog), bearer);
  }

  Future<Object?> getAgents({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.agents), bearer);
  }

  Future<Object?> getAssistantsSnapshot({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.assistantsSnapshot), bearer);
  }

  Future<Object?> getCommandCatalog({required Uri base, String? bearer}) {
    return _requireOk(
      base,
      const OpenChamberRequest(method: 'POST', path: OpenChamberPaths.commandsMetadata, body: {'catalog': true}),
      bearer,
    );
  }

  Future<Object?> getMcpConfigs({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.mcp), bearer);
  }

  Future<Object?> getPlugins({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.plugins), bearer);
  }

  Future<Object?> getInstalledSkills({required Uri base, String? bearer}) {
    return _requireOk(
      base,
      const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.skills, query: {'summary': 'true'}),
      bearer,
    );
  }

  Future<Object?> getSnippets({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.snippets), bearer);
  }

  Future<Object?> getMagicPrompts({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.magicPrompts), bearer);
  }

  Future<Object?> getGitIdentities({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.gitIdentities), bearer);
  }

  Future<Object?> getBehaviorAgentsMd({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.behaviorAgentsMd), bearer);
  }

  Future<String?> mintUrlToken({required Uri base, String? bearer}) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(method: 'POST', path: OpenChamberPaths.authUrlToken, bearer: bearer),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.authUrlToken);
    }
    final token = response.map['token']?.toString().trim() ?? '';
    return token.isEmpty ? null : token;
  }

  Future<Object?> getSmallModel({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.smallModel), bearer);
  }

  Future<Object?> getQuota({required Uri base, String? bearer, required String providerId}) {
    return _requireOk(base, OpenChamberRequest(method: 'GET', path: OpenChamberPaths.quota(providerId)), bearer);
  }

  Future<Object?> getAssistantsCapability({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.assistantsCapability), bearer);
  }

  Future<Object?> getScheduledTasks({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.scheduledTasks), bearer);
  }

  Future<Object?> getScheduledTaskRuns({
    required Uri base,
    String? bearer,
    String? projectId,
    String? taskId,
    int limit = 20,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'GET',
        path: OpenChamberPaths.scheduledTaskRuns,
        query: {
          'limit': '$limit',
          if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
          if (taskId != null && taskId.isNotEmpty) 'taskId': taskId,
        },
      ),
      bearer,
    );
  }

  Future<Object?> setProviderApiKey({
    required Uri base,
    String? bearer,
    required String providerId,
    required String key,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'PUT',
        path: OpenChamberPaths.providerAuth(providerId),
        body: {'type': 'api', 'key': key},
      ),
      bearer,
    );
  }

  Future<Object?> deleteProviderAuth({
    required Uri base,
    String? bearer,
    required String providerId,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'DELETE',
        path: OpenChamberPaths.providerAuthDelete(providerId),
        query: const {'scope': 'all'},
      ),
      bearer,
    );
  }

  Future<Object?> mutateConfigEntity({
    required Uri base,
    String? bearer,
    required String method,
    required String path,
    Map<String, Object?>? body,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(method: method, path: path, body: body),
      bearer,
    );
  }

  Future<Object?> createAssistantDraft({
    required Uri base,
    String? bearer,
    required Map<String, Object?> draft,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(method: 'POST', path: OpenChamberPaths.assistants, body: draft),
      bearer,
    );
  }

  Future<Object?> patchAssistant({
    required Uri base,
    String? bearer,
    required String id,
    required Map<String, Object?> draft,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(method: 'PATCH', path: OpenChamberPaths.assistant(id), body: draft),
      bearer,
    );
  }

  Future<Object?> deleteAssistant({
    required Uri base,
    String? bearer,
    required String id,
    required int expectedRevision,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'DELETE',
        path: OpenChamberPaths.assistant(id),
        body: {'expectedRevision': expectedRevision},
      ),
      bearer,
    );
  }

  Future<Object?> putAssistantsSettings({
    required Uri base,
    String? bearer,
    required bool enabled,
    required int expectedRevision,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'PUT',
        path: OpenChamberPaths.assistantsSettings,
        body: {'enabled': enabled, 'expectedRevision': expectedRevision},
      ),
      bearer,
    );
  }

  Future<Object?> newAssistantSession({
    required Uri base,
    String? bearer,
    required String assistantId,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(method: 'POST', path: OpenChamberPaths.assistantSessionNew(assistantId)),
      bearer,
    );
  }

  Future<Object?> sendAssistantShare({
    required Uri base,
    String? bearer,
    required String assistantId,
    required String operationID,
    required String messageID,
    required List<Map<String, Object?>> parts,
    required String source,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: OpenChamberPaths.assistantShare(assistantId),
        body: {
          'operationID': operationID,
          'payload': {'messageID': messageID, 'parts': parts, 'source': source},
        },
      ),
      bearer,
    );
  }

  Future<Object?> getAssistantShareOperation({
    required Uri base,
    String? bearer,
    required String operationID,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(method: 'GET', path: OpenChamberPaths.assistantShareOperation(operationID)),
      bearer,
    );
  }

  Future<String> readFile({
    required Uri base,
    required String bearer,
    required String path,
  }) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: 'GET',
        path: OpenChamberPaths.fsRead,
        bearer: bearer,
        query: {'path': path},
      ),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, OpenChamberPaths.fsRead);
    }
    final body = response.body;
    if (body is String) return body;
    if (body is List<int>) return utf8.decode(body);
    if (body is Map) {
      return body['content']?.toString() ?? body['text']?.toString() ?? '';
    }
    return body?.toString() ?? '';
  }

  Future<Object?> installSkillFromSource({
    required Uri base,
    String? bearer,
    required Map<String, Object?> request,
  }) {
    return _requireOk(
      base,
      OpenChamberRequest(method: 'POST', path: OpenChamberPaths.skillsInstall, body: request),
      bearer,
    );
  }

  Future<Map<String, Object?>> _requireMap(Uri base, OpenChamberRequest request, String? bearer) async {
    final body = await _requireOk(base, request, bearer);
    if (body is Map<String, Object?>) return body;
    if (body is Map) return body.map((key, value) => MapEntry(key.toString(), value));
    throw OpenChamberHttpException(200, request.path, code: 'malformed');
  }

  Future<Object?> _requireOk(Uri base, OpenChamberRequest request, String? bearer) async {
    final response = await transport.send(
      base,
      OpenChamberRequest(
        method: request.method,
        path: request.path,
        query: request.query,
        body: request.body,
        bytes: request.bytes,
        bearer: bearer,
        extraHeaders: request.extraHeaders,
        stream: request.stream,
        timeout: request.timeout,
      ),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, request.path);
    }
    return response.body;
  }
}


Map<String, String> parseSessionStatusMap(Object? payload) {
  Object? root = payload;
  if (root is Map && root['data'] != null) root = root['data'];
  if (root is! Map) return const {};
  final out = <String, String>{};
  root.forEach((key, value) {
    if (value is Map) {
      final type = value['type']?.toString();
      if (type != null && type.isNotEmpty) out[key.toString()] = type;
    }
  });
  return out;
}

CreatedSession? parseCreatedSession(Object? payload) {
  Object? root = payload;
  if (root is Map && root['data'] != null) root = root['data'];
  if (root is! Map) return null;
  final id = root['id']?.toString() ?? '';
  if (id.isEmpty) return null;
  return CreatedSession(
    id: id,
    title: root['title']?.toString(),
    directory: root['directory']?.toString(),
  );
}


/// In-memory transport for widget/unit tests. Speaks the official paths only.
class MemoryOpenChamberTransport implements OpenChamberTransport {
  MemoryOpenChamberTransport({
    this.health = const {'status': 'ok', 'serverId': 'srv_test'},
    this.auth = const {'authenticated': true, 'disabled': true},
    this.unlock = const {'authenticated': true, 'clientToken': 'oc_client_test'},
    this.redeem = const {
      'ok': true,
      'clientToken': 'oc_client_pair',
      'server': {'label': 'Studio', 'url': 'http://192.168.1.20:4096'},
    },
    Map<String, Object?>? sessionIndex,
    List<Map<String, Object?>>? transcript,
    this.statusBySession = const {},
    this.unlockPassword,
  })  : sessionIndex = _cloneJsonMap(sessionIndex ?? defaultTestSessionIndex),
        transcript = transcript ?? defaultTestTranscript;

  Map<String, Object?> health;
  Map<String, Object?> auth;
  Map<String, Object?> unlock;
  Map<String, Object?> redeem;
  Map<String, Object?> sessionIndex;
  List<Map<String, Object?>> transcript;
  Map<String, String> statusBySession;
  String? unlockPassword;
  int healthStatus = 200;
  Duration healthDelay = Duration.zero;
  final Map<String, int> healthStatusByHost = {};
  final Map<String, Duration> healthDelayByHost = {};
  Map<String, Object?>? connectionCandidates;
  int connectionCandidatesStatus = 200;
  int authStatus = 200;
  int unlockStatus = 200;
  int redeemStatus = 200;
  int indexStatus = 200;
  int messagesStatus = 200;
  int promptStatus = 200;
  int abortStatus = 200;
  int statusStatus = 200;
  int pushStatus = 200;
  int createStatus = 200;
  int sessionMutationStatus = 200;
  int pinStatus = 200;
  int fsStatus = 200;
  int gitStatus = 200;
  String fsHome = '/workspace';
  List<Map<String, Object?>> fsEntries = [
    {'name': 'openchamber', 'path': '/workspace/openchamber', 'type': 'directory'},
    {'name': 'notes', 'path': '/workspace/notes', 'type': 'directory'},
    {'name': '.hidden', 'path': '/workspace/.hidden', 'type': 'directory'},
    {'name': 'README.md', 'path': '/workspace/README.md', 'type': 'file'},
  ];
  final Map<String, String> sessionShareUrls = {};
  int cloneStatus = 200;
  int mkdirStatus = 200;
  int githubStatus = 200;
  bool githubConnected = true;
  List<Map<String, Object?>> githubIssues = [
    {'number': 42, 'title': 'Native gap audit'},
  ];
  List<Map<String, Object?>> githubPulls = [
    {'number': 19, 'title': 'Session share', 'head': 'feat/share'},
  ];
  int worktreeOrderStatus = 200;
  final Map<String, List<String>> worktreeOrders = {};
  final Map<String, int> worktreeOrderRevisions = {};
  int discoverStatus = 200;
  int settingsStatus = 200;
  int catalogStatus = 200;
  int mutationStatus = 200;
  int uploadStatus = 200;
  int fileStatus = 200;
  Map<String, String> fileContents = {
    '/workspace/openchamber/docs/index.html':
        '<!doctype html><html><body><h1>Preview</h1></body></html>',
  };

  Map<String, Object?> settings = Map<String, Object?>.from(defaultTestSettings);
  Object? providerCatalog = defaultTestProviderCatalog;
  Object? agents = defaultTestAgents;
  Object? assistants = defaultTestAssistants;
  Object? commands = defaultTestCommands;
  Object? mcp = defaultTestMcp;
  Object? plugins = defaultTestPlugins;
  Object? skills = defaultTestSkills;
  Object? snippets = defaultTestSnippets;
  Object? magicPrompts = defaultTestMagicPrompts;
  Object? gitIdentities = defaultTestGitIdentities;
  Object? agentsMd = const {'content': 'Use official APIs. Do not invent endpoints.'};
  Object? smallModel = defaultTestSmallModel;
  Map<String, Object?> quotas = Map<String, Object?>.from(defaultTestQuotas);

  final List<OpenChamberRequest> calls = [];
  final List<Uri> bases = [];
  final List<String> sentPrompts = [];
  final List<List<Map<String, Object?>>> sentPromptParts = [];
  final List<Map<String, Object?>> uploadedAttachments = [];
  final List<Map<String, Object?>> createdSessions = [];
  final List<Map<String, Object?>> oauthCalls = [];
  final List<Map<String, Object?>> permissionReplies = [];
  final Map<String, Map<String, Object?>> mcpPending = {};
  final Map<String, Map<String, Object?>> pluginFiles = {
    'file-1': {
      'id': 'file-1',
      'fileName': 'local.ts',
      'scope': 'user',
      'content': 'export const ping = () => 1\n',
    },
  };
  List<Object?> permissions = [
    {
      'id': 'perm-1',
      'sessionID': 'sess-catalog',
      'permission': 'bash',
      'patterns': ['git status'],
      'metadata': {'command': 'git status'},
    },
  ];
  List<String> eventChunks = const [];
  Object? scheduledTasks = defaultTestScheduledTasks;
  Object? scheduledRuns = defaultTestScheduledRuns;
  Object? assistantsCapability = defaultTestAssistantsCapability;
  final List<Map<String, Object?>> shareCalls = [];
  final Map<String, Map<String, Object?>> shareOperations = {};

  @override
  Stream<List<int>> openByteStream(Uri base, OpenChamberRequest request) async* {
    calls.add(request);
    for (final chunk in eventChunks) {
      yield chunk.codeUnits;
    }
  }

  @override
  Future<void> close() async {}

  void _appendAssistant(Map<String, Object?> created) {
    final root = assistants is Map ? Map<String, Object?>.from((assistants as Map).map((key, value) => MapEntry(key.toString(), value))) : <String, Object?>{'revision': 1, 'enabled': true, 'assistants': <Object?>[]};
    final list = [...(root['assistants'] is List ? (root['assistants'] as List) : const [])];
    list.add(created);
    root['assistants'] = list;
    assistants = root;
  }

  void _appendPlugin(Map<String, Object?> created) {
    final root = plugins is Map ? Map<String, Object?>.from((plugins as Map).map((key, value) => MapEntry(key.toString(), value))) : <String, Object?>{'entries': <Object?>[]};
    final list = [...(root['entries'] is List ? (root['entries'] as List) : const [])];
    list.add(created);
    root['entries'] = list;
    plugins = root;
  }

  void _appendPluginFile(Map<String, Object?> created) {
    final root = plugins is Map ? Map<String, Object?>.from((plugins as Map).map((key, value) => MapEntry(key.toString(), value))) : <String, Object?>{'files': <Object?>[]};
    final list = [...(root['files'] is List ? (root['files'] as List) : const [])];
    list.add({'id': created['id'], 'fileName': created['fileName'], 'scope': created['scope'], 'kind': 'file'});
    root['files'] = list;
    plugins = root;
  }

  void _removePluginFile(String id) {
    final root = plugins is Map ? Map<String, Object?>.from((plugins as Map).map((key, value) => MapEntry(key.toString(), value))) : <String, Object?>{};
    final list = [...(root['files'] is List ? (root['files'] as List) : const [])]
        .where((item) => item is! Map || item['id']?.toString() != id)
        .toList();
    root['files'] = list;
    plugins = root;
  }

  void _upsertMemoryScheduledTask(String projectId, Map<String, Object?> task) {
    final root = scheduledTasks is Map
        ? Map<String, Object?>.from((scheduledTasks as Map).map((key, value) => MapEntry(key.toString(), value)))
        : <String, Object?>{};
    final tasks = [...(root['tasks'] is List ? (root['tasks'] as List) : const [])];
    tasks.add({'projectId': projectId, 'task': task});
    root['tasks'] = tasks;
    scheduledTasks = root;
  }

  void _markScheduledRunning(String path) {
    final parts = path.split('/');
    final taskId = parts.length >= 2 ? Uri.decodeComponent(parts[parts.length - 2]) : '';
    final root = scheduledTasks is Map ? Map<String, Object?>.from((scheduledTasks as Map).map((key, value) => MapEntry(key.toString(), value))) : <String, Object?>{};
    final tasks = [...(root['tasks'] is List ? (root['tasks'] as List) : const [])].map((item) {
      if (item is! Map) return item;
      final task = item['task'] is Map ? Map<String, Object?>.from(item['task'] as Map) : <String, Object?>{};
      if (task['id']?.toString() != taskId) return item;
      final state = task['state'] is Map ? Map<String, Object?>.from(task['state'] as Map) : <String, Object?>{};
      state['lastStatus'] = 'running';
      task['state'] = state;
      return {...item, 'task': task};
    }).toList();
    root['tasks'] = tasks;
    scheduledTasks = root;
    final runsRoot = scheduledRuns is Map ? Map<String, Object?>.from((scheduledRuns as Map).map((key, value) => MapEntry(key.toString(), value))) : <String, Object?>{'runs': <Object?>[]};
    final runs = [...(runsRoot['runs'] is List ? (runsRoot['runs'] as List) : const [])];
    runs.insert(0, {
      'id': 'run-live',
      'projectId': 'proj-1',
      'taskId': taskId,
      'taskName': 'Nightly review',
      'status': 'running',
      'sessionId': 'sess-catalog',
      'directory': '/workspace/openchamber',
      'startedAt': 3,
    });
    runsRoot['runs'] = runs;
    scheduledRuns = runsRoot;
  }

  OpenChamberResponse _mutateNamedList(
    OpenChamberRequest request, {
    required Object? current,
    required void Function(Object? next) assign,
    required String idKey,
  }) {
    final name = Uri.decodeComponent(request.path.split('/').last);
    var items = current is List ? [...current] : <Object?>[];
    if (request.method == 'DELETE') {
      items = items.where((item) => item is! Map || item[idKey]?.toString() != name).toList();
    } else if (request.method == 'POST') {
      items = [...items, {idKey: name, ...?request.body}];
    } else if (request.method == 'PATCH') {
      items = items.map((item) {
        if (item is Map && item[idKey]?.toString() == name) {
          return {...item.map((key, value) => MapEntry(key.toString(), value)), ...?request.body};
        }
        return item;
      }).toList();
    }
    assign(items);
    return OpenChamberResponse(status: mutationStatus, body: {'ok': true});
  }

  OpenChamberResponse _mutateNamedCatalog(
    OpenChamberRequest request, {
    required Object? current,
    required void Function(Object? next) assign,
    required String listKey,
    String idKey = 'name',
  }) {
    final root = current is Map ? Map<String, Object?>.from(current.map((key, value) => MapEntry(key.toString(), value))) : <String, Object?>{listKey: <Object?>[]};
    final name = Uri.decodeComponent(request.path.split('/').last);
    var items = root[listKey] is List ? [...(root[listKey] as List)] : <Object?>[];
    if (request.method == 'DELETE') {
      items = items.where((item) => item is! Map || item[idKey]?.toString() != name).toList();
    } else if (request.method == 'POST') {
      items = [...items, {idKey: name, ...?request.body}];
    } else if (request.method == 'PATCH') {
      items = items.map((item) {
        if (item is Map && item[idKey]?.toString() == name) {
          return {...item.map((key, value) => MapEntry(key.toString(), value)), ...?request.body};
        }
        return item;
      }).toList();
    }
    root[listKey] = items;
    assign(root);
    return OpenChamberResponse(status: mutationStatus, body: {'ok': true});
  }

  static String _basename(String path) {
    final trimmed = path.replaceAll(RegExp(r'[/\\]+$'), '');
    final parts = trimmed.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? path : parts.last;
  }

  static Map<String, Object?> _cloneJsonMap(Map<String, Object?> source) {
    return (jsonDecode(jsonEncode(source)) as Map).map((key, value) => MapEntry(key.toString(), value));
  }

  List<Object?> _indexDirectories() {
    final raw = sessionIndex['directories'];
    return raw is List ? [...raw] : [];
  }

  void _writeIndexDirectories(List<Object?> directories) {
    sessionIndex = {
      ...sessionIndex,
      'directories': directories,
      'revision': (sessionIndex['revision'] is num ? (sessionIndex['revision'] as num).toInt() : 0) + 1,
    };
  }

  String? _sessionIdFromSharePath(String path) {
    final parts = path.split('/');
    if (parts.length >= 5 && parts.last == 'share') {
      return Uri.decodeComponent(parts[parts.length - 2]);
    }
    return null;
  }

  Map<String, Object?> _sessionPayload(String id, {String? shareUrl}) {
    for (final directory in _indexDirectories()) {
      if (directory is! Map) continue;
      final sessions = directory['sessions'];
      if (sessions is! List) continue;
      for (final row in sessions) {
        if (row is! Map || row['id']?.toString() != id) continue;
        final current = Map<String, Object?>.from(row.map((key, value) => MapEntry(key.toString(), value)));
        final url = shareUrl ?? sessionShareUrls[id];
        if (url != null && url.isNotEmpty) {
          current['share'] = {'url': url};
        } else {
          current.remove('share');
        }
        return current;
      }
    }
    return {
      'id': id,
      if (shareUrl != null && shareUrl.isNotEmpty) 'share': {'url': shareUrl},
    };
  }

  void _upsertIndexedSession(Map<String, Object?> session) {
    final id = session['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final directory = session['directory']?.toString() ?? '';
    final directories = _indexDirectories();
    var foundDirectory = false;
    final next = directories.map((item) {
      if (item is! Map) return item;
      final dir = item.map((key, value) => MapEntry(key.toString(), value));
      if (dir['directory']?.toString() != directory) return item;
      foundDirectory = true;
      final sessions = [...(dir['sessions'] is List ? dir['sessions'] as List : const [])];
      final index = sessions.indexWhere((row) => row is Map && row['id']?.toString() == id);
      if (index >= 0) {
        final current = Map<String, Object?>.from((sessions[index] as Map).map((key, value) => MapEntry(key.toString(), value)));
        sessions[index] = {...current, ...session};
      } else {
        sessions.add(session);
      }
      return {...dir, 'sessions': sessions};
    }).toList();
    if (!foundDirectory && directory.isNotEmpty) {
      next.add({
        'directory': directory,
        'sessions': [session],
      });
    }
    _writeIndexDirectories(next);
  }

  void _patchIndexedSession(String id, Map<String, Object?> patch) {
    final directories = _indexDirectories().map((item) {
      if (item is! Map) return item;
      final dir = item.map((key, value) => MapEntry(key.toString(), value));
      final sessions = [...(dir['sessions'] is List ? dir['sessions'] as List : const [])];
      var changed = false;
      for (var i = 0; i < sessions.length; i += 1) {
        if (sessions[i] is! Map) continue;
        final current = Map<String, Object?>.from((sessions[i] as Map).map((key, value) => MapEntry(key.toString(), value)));
        if (current['id']?.toString() != id) continue;
        final time = current['time'] is Map
            ? Map<String, Object?>.from((current['time'] as Map).map((key, value) => MapEntry(key.toString(), value)))
            : <String, Object?>{};
        if (patch['title'] != null) current['title'] = patch['title'];
        if (patch.containsKey('share')) {
          if (patch['share'] == null) {
            current.remove('share');
          } else {
            current['share'] = patch['share'];
          }
        }
        final patchTime = patch['time'];
        if (patchTime is Map) {
          time.addAll(patchTime.map((key, value) => MapEntry(key.toString(), value)));
          current['time'] = time;
        }
        sessions[i] = current;
        changed = true;
      }
      if (!changed) return item;
      return {...dir, 'sessions': sessions};
    }).toList();
    _writeIndexDirectories(directories);
  }

  void _removeIndexedSession(String id) {
    final directories = _indexDirectories().map((item) {
      if (item is! Map) return item;
      final dir = item.map((key, value) => MapEntry(key.toString(), value));
      final sessions = [...(dir['sessions'] is List ? dir['sessions'] as List : const [])]
          .where((row) => row is! Map || row['id']?.toString() != id)
          .toList();
      return {...dir, 'sessions': sessions};
    }).toList();
    _writeIndexDirectories(directories);
  }

  void _setPinned(String id, {required bool pinned}) {
    final ids = [...(sessionIndex['pinnedSessionIds'] is List ? sessionIndex['pinnedSessionIds'] as List : const [])]
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty && item != id)
        .toList();
    if (pinned) ids.add(id);
    sessionIndex = {...sessionIndex, 'pinnedSessionIds': ids};
    _patchIndexedSession(id, {
      'time': pinned ? {'pinned': '2026-09-05T00:00:00.000Z'} : {'pinned': null},
    });
    // Clearing pin: drop the time.pinned key rather than store null.
    if (!pinned) {
      final directories = _indexDirectories().map((item) {
        if (item is! Map) return item;
        final dir = item.map((key, value) => MapEntry(key.toString(), value));
        final sessions = [...(dir['sessions'] is List ? dir['sessions'] as List : const [])].map((row) {
          if (row is! Map || row['id']?.toString() != id) return row;
          final current = Map<String, Object?>.from(row.map((key, value) => MapEntry(key.toString(), value)));
          final time = current['time'] is Map
              ? Map<String, Object?>.from((current['time'] as Map).map((key, value) => MapEntry(key.toString(), value)))
              : <String, Object?>{};
          time.remove('pinned');
          current['time'] = time;
          return current;
        }).toList();
        return {...dir, 'sessions': sessions};
      }).toList();
      _writeIndexDirectories(directories);
    }
  }

  void _removeIndexDirectory(String directory) {
    final next = _indexDirectories().where((item) {
      return item is! Map || item['directory']?.toString() != directory;
    }).toList();
    _writeIndexDirectories(next);
  }

  OpenChamberResponse _mutateAssistant(OpenChamberRequest request) {
    final id = Uri.decodeComponent(request.path.split('/').last);
    final root = assistants is Map ? Map<String, Object?>.from((assistants as Map).map((key, value) => MapEntry(key.toString(), value))) : <String, Object?>{'revision': 1, 'enabled': true, 'assistants': <Object?>[]};
    var items = root['assistants'] is List ? [...(root['assistants'] as List)] : <Object?>[];
    if (request.method == 'DELETE') {
      items = items.where((item) => item is! Map || item['id']?.toString() != id).toList();
    } else if (request.method == 'PATCH') {
      items = items.map((item) {
        if (item is Map && item['id']?.toString() == id) {
          return {...item.map((key, value) => MapEntry(key.toString(), value)), ...?request.body};
        }
        return item;
      }).toList();
    }
    root['assistants'] = items;
    assistants = root;
    return OpenChamberResponse(status: mutationStatus, body: {'ok': true});
  }

  static final Map<String, Object?> defaultTestSessionIndex = {
    'available': true,
    'revision': 1,
    'pinnedSessionIds': ['sess-pinned'],
    'directories': [
      {
        'directory': '/workspace/openchamber',
        'sessions': [
          {
            'id': 'sess-pinned',
            'title': 'Release notes',
            'directory': '/workspace/openchamber',
            'parentID': null,
            'project': {'name': 'openchamber'},
            'time': {'updated': 1756900740000, 'pinned': '2026-09-01T00:00:00.000Z'},
            'branch': 'work/flutter-native',
            'unread': true,
          },
          {
            'id': 'sess-busy',
            'title': 'Fix composer IME',
            'directory': '/workspace/openchamber',
            'parentID': null,
            'project': {'name': 'openchamber'},
            'time': {'updated': 1756899000000},
            'branch': 'feat/home',
          },
          {
            'id': 'sess-catalog',
            'title': 'New Session',
            'directory': '/workspace/openchamber',
            'parentID': null,
            'project': {'name': 'openchamber'},
            'time': {'updated': 1756895400000},
            'branch': 'main',
          },
        ],
      },
    ],
  };

  static final List<Map<String, Object?>> defaultTestTranscript = [
    {
      'info': {'id': 'm1', 'role': 'user'},
      'parts': [
        {'type': 'text', 'text': 'Open a session from Projects.'},
      ],
    },
    {
      'info': {'id': 'm2', 'role': 'assistant'},
      'parts': [
        {
          'type': 'text',
          'text':
              'This list is a reverse LegendList analogue. Older history prepends without jumping the live edge.',
        },
      ],
    },
    {
      'info': {'id': 'm3', 'role': 'user'},
      'parts': [
        {'type': 'text', 'text': 'Re-entering this session jumps to the latest message.'},
      ],
    },
  ];

  static const Map<String, Object?> defaultTestSettings = {
    'chatRenderMode': 'sorted',
    'messageStreamTransport': 'sse',
    'followUpBehavior': 'steer',
    'showReasoningTraces': true,
    'codeBlockLineWrap': false,
    'inputSpellcheckEnabled': true,
    'nativeNotificationsEnabled': true,
    'notifyOnCompletion': true,
    'notifyOnError': true,
    'notifyOnQuestion': true,
    'defaultModel': 'anthropic/claude-sonnet-4',
    'defaultAgent': 'build',
    'autoDeleteEnabled': false,
    'autoDeleteAfterDays': 30,
    'sessionRetentionAction': 'archive',
    'gitmojiEnabled': true,
    'gitChangesViewMode': 'tree',
    'summaryModelMode': 'provider',
    'summaryProviderID': 'anthropic',
    'summaryModelID': 'claude-haiku-4-5',
    'sttProvider': 'local',
    'responseStyleEnabled': false,
    'responseStylePreset': 'concise',
    'usageDropdownProviders': ['openai', 'claude'],
    'projects': [
      {'id': 'proj-1', 'path': '/workspace/openchamber', 'label': 'openchamber'},
    ],
  };

  static const Map<String, Object?> defaultTestProviderCatalog = {
    'schemaVersion': 1,
    'providers': [
      {
        'id': 'anthropic',
        'name': 'Anthropic',
        'models': {
          'claude-sonnet-4': {
            'id': 'claude-sonnet-4',
            'limit': {'context': 200000},
          },
        },
      },
      {
        'id': 'openai',
        'name': 'OpenAI',
        'models': {'gpt-5': {'id': 'gpt-5'}},
      },
    ],
    'default': <String, Object?>{},
    'partial': false,
  };

  static const List<Map<String, Object?>> defaultTestAgents = [
    {'name': 'build', 'mode': 'primary'},
    {'name': 'plan', 'mode': 'subagent'},
  ];

  static const Map<String, Object?> defaultTestAssistants = {
    'revision': 1,
    'enabled': true,
    'assistants': [
      {
        'id': 'asst-1',
        'revision': 1,
        'enabled': true,
        'name': 'Home',
        'defaultPrompt': '',
        'workspacePath': '/workspace/openchamber',
        'providerID': 'anthropic',
        'modelID': 'claude-sonnet-4',
        'mode': 'chat',
        'sessionID': 'sess-catalog',
      },
    ],
  };

  static const Map<String, Object?> defaultTestAssistantsCapability = {
    'supported': true,
    'enabled': true,
    'revision': 1,
    'serverInstanceID': 'srv-memory',
  };

  static const Map<String, Object?> defaultTestScheduledTasks = {
    'tasks': [
      {
        'projectId': 'proj-1',
        'task': {
          'id': 'cron-1',
          'name': 'Nightly review',
          'enabled': true,
          'schedule': {'kind': 'daily', 'time': '02:00'},
          'execution': {'prompt': 'Review the diff', 'providerID': 'anthropic', 'modelID': 'claude-sonnet-4'},
          'state': {
            'createdAt': 1,
            'updatedAt': 2,
            'lastStatus': 'success',
            'lastSessionId': 'sess-catalog',
            'nextRunAt': 1893456000000,
            'lastError': null,
          },
        },
      },
    ],
    'failedProjectIds': <Object?>[],
  };

  static const Map<String, Object?> defaultTestScheduledRuns = {
    'runs': [
      {
        'id': 'run-1',
        'projectId': 'proj-1',
        'taskId': 'cron-1',
        'taskName': 'Nightly review',
        'trigger': 'scheduled',
        'status': 'success',
        'sessionId': 'sess-catalog',
        'directory': '/workspace/openchamber',
        'error': null,
        'startedAt': 1,
        'finishedAt': 2,
        'durationMs': 1,
      },
    ],
    'nextCursor': null,
    'complete': true,
  };

  static const Map<String, Object?> defaultTestCommands = {
    'commands': [
      {'name': 'review', 'description': 'Review the current diff', 'scope': 'user', 'isBuiltIn': false},
    ],
  };

  static const List<Map<String, Object?>> defaultTestMcp = [
    {'name': 'filesystem', 'type': 'local', 'enabled': true},
  ];

  static const Map<String, Object?> defaultTestPlugins = {
    'entries': [
      {'id': 'plug-1', 'spec': 'opencode-plugin/example', 'scope': 'user'},
    ],
    'files': [
      {'id': 'file-1', 'fileName': 'local.ts', 'scope': 'user', 'kind': 'file'},
    ],
  };

  static const Map<String, Object?> defaultTestSkills = {
    'skills': [
      {'name': 'release-notes', 'path': '/skills/release-notes/SKILL.md', 'scope': 'user', 'description': 'Draft release notes'},
    ],
  };

  static const List<Map<String, Object?>> defaultTestSnippets = [
    {'name': 'repro', 'content': 'Please include a repro', 'source': 'global'},
  ];

  static const Map<String, Object?> defaultTestMagicPrompts = {
    'version': 1,
    'overrides': {'git.commit.generate.visible': 'Write a Conventional Commits subject.'},
  };

  static const List<Map<String, Object?>> defaultTestGitIdentities = [
    {'id': 'git-1', 'name': 'Work', 'userName': 'Yee', 'userEmail': 'dev@example.com'},
  ];

  static const Map<String, Object?> defaultTestSmallModel = {
    'callableModels': {
      'anthropic': ['claude-haiku-4-5'],
    },
  };

  static const Map<String, Object?> defaultTestQuotas = {
    'openai': {
      'providerId': 'openai',
      'providerName': 'OpenAI',
      'ok': true,
      'configured': true,
      'usage': {
        'windows': [
          {'usedPercent': 12},
        ],
      },
    },
    'claude': {
      'providerId': 'claude',
      'providerName': 'Claude',
      'ok': true,
      'configured': true,
      'usage': {
        'windows': [
          {'usedPercent': 4},
        ],
      },
    },
  };

  @override
  Future<OpenChamberResponse> send(Uri base, OpenChamberRequest request) async {
    calls.add(request);
    bases.add(base);
    switch (request.path) {
      case OpenChamberPaths.health:
        final delay = healthDelayByHost[base.host] ?? healthDelay;
        if (delay > Duration.zero) await Future<void>.delayed(delay);
        return OpenChamberResponse(status: healthStatusByHost[base.host] ?? healthStatus, body: health);
      case OpenChamberPaths.connectionCandidates:
        if (connectionCandidates == null) {
          return const OpenChamberResponse(status: 404, body: {'error': 'not_found'});
        }
        return OpenChamberResponse(status: connectionCandidatesStatus, body: connectionCandidates);
      case OpenChamberPaths.authSession:
        if (request.method == 'POST') {
          final password = request.body?['password']?.toString() ?? '';
          if (unlockPassword != null && password != unlockPassword) {
            return const OpenChamberResponse(status: 401, body: {'error': 'Invalid credentials'});
          }
          if (password.isEmpty) {
            return const OpenChamberResponse(status: 401, body: {'error': 'Invalid credentials'});
          }
          return OpenChamberResponse(status: unlockStatus, body: unlock);
        }
        return OpenChamberResponse(status: authStatus, body: auth);
      case OpenChamberPaths.pairingRedeem:
        return OpenChamberResponse(status: redeemStatus, body: redeem);
      case OpenChamberPaths.sessionIndex:
        return OpenChamberResponse(status: indexStatus, body: sessionIndex);
      case OpenChamberPaths.sessionIndexSync:
        return const OpenChamberResponse(status: 202, body: {'ok': true});
      case OpenChamberPaths.sessionStatus:
        return OpenChamberResponse(status: statusStatus, body: statusBySession.map((key, value) => MapEntry(key, {'type': value})));
      case OpenChamberPaths.pushApnsToken:
      case OpenChamberPaths.pushVisibility:
        return OpenChamberResponse(status: pushStatus, body: const {'ok': true});
      case OpenChamberPaths.sessionCreate:
        final directory = request.query['directory'] ?? '';
        final id = 'ses_flutter_${createdSessions.length + 1}';
        final created = <String, Object?>{
          'id': id,
          'title': request.body?['title'] ?? 'New Session',
          'directory': directory,
        };
        createdSessions.add(created);
        _upsertIndexedSession({
          ...created,
          'parentID': null,
          'project': {'name': _basename(directory)},
          'time': {'updated': DateTime.now().millisecondsSinceEpoch},
        });
        return OpenChamberResponse(status: createStatus, body: created);
      case OpenChamberPaths.globalEvent:
        return const OpenChamberResponse(status: 200, body: null);
      case OpenChamberPaths.configSettings:
        if (request.method == 'PUT') {
          final changes = request.body ?? const {};
          settings = {...settings, ...changes};
        }
        return OpenChamberResponse(status: settingsStatus, body: settings);
      case OpenChamberPaths.providerCatalog:
        return OpenChamberResponse(status: catalogStatus, body: providerCatalog);
      case OpenChamberPaths.agents:
        return OpenChamberResponse(status: catalogStatus, body: agents);
      case OpenChamberPaths.assistantsSnapshot:
        return OpenChamberResponse(status: catalogStatus, body: assistants);
      case OpenChamberPaths.assistantsCapability:
        return OpenChamberResponse(status: catalogStatus, body: assistantsCapability);
      case OpenChamberPaths.assistantsSettings:
        final enabled = request.body?['enabled'] == true;
        if (assistants is Map<String, Object?>) {
          assistants = {...assistants as Map<String, Object?>, 'enabled': enabled};
        }
        return OpenChamberResponse(status: mutationStatus, body: {'ok': true});
      case OpenChamberPaths.assistants:
        if (request.method == 'POST') {
          final created = <String, Object?>{
            'id': 'asst-${DateTime.now().microsecondsSinceEpoch}',
            'revision': 1,
            'enabled': true,
            ...?request.body,
          };
          _appendAssistant(created);
          return OpenChamberResponse(status: mutationStatus, body: created);
        }
        return OpenChamberResponse(status: catalogStatus, body: assistants);
      case OpenChamberPaths.scheduledTasks:
        return OpenChamberResponse(status: catalogStatus, body: scheduledTasks);
      case OpenChamberPaths.scheduledTaskRuns:
        return OpenChamberResponse(status: catalogStatus, body: scheduledRuns);
      case OpenChamberPaths.pluginsEntry:
        if (request.method == 'POST') {
          final created = <String, Object?>{
            'id': 'plug-${DateTime.now().microsecondsSinceEpoch}',
            'spec': request.body?['spec'],
            'scope': request.body?['scope'] ?? 'user',
          };
          _appendPlugin(created);
          return OpenChamberResponse(status: mutationStatus, body: created);
        }
        return OpenChamberResponse(status: mutationStatus, body: const {'ok': true});
      case OpenChamberPaths.skillsInstall:
        return OpenChamberResponse(status: mutationStatus, body: const {'ok': true, 'installed': <Object?>[]});
      case OpenChamberPaths.commandsMetadata:
        return OpenChamberResponse(status: catalogStatus, body: commands);
      case OpenChamberPaths.mcp:
        return OpenChamberResponse(status: catalogStatus, body: mcp);
      case OpenChamberPaths.plugins:
        return OpenChamberResponse(status: catalogStatus, body: plugins);
      case OpenChamberPaths.skills:
        return OpenChamberResponse(status: catalogStatus, body: skills);
      case OpenChamberPaths.snippets:
        return OpenChamberResponse(status: catalogStatus, body: snippets);
      case OpenChamberPaths.magicPrompts:
        return OpenChamberResponse(status: catalogStatus, body: magicPrompts);
      case OpenChamberPaths.gitIdentities:
        return OpenChamberResponse(status: catalogStatus, body: gitIdentities);
      case OpenChamberPaths.fsMkdir:
        if (mkdirStatus < 200 || mkdirStatus >= 300) {
          return OpenChamberResponse(status: mkdirStatus, body: {'error': 'mkdir_failed'});
        }
        final createdPath = request.body?['path']?.toString() ?? '';
        if (createdPath.isNotEmpty) {
          final name = createdPath.contains('/') ? createdPath.split('/').last : createdPath;
          fsEntries = [
            ...fsEntries,
            {'name': name, 'path': createdPath, 'type': 'directory'},
          ];
        }
        return OpenChamberResponse(status: mkdirStatus, body: {'success': true, 'path': createdPath});
      case OpenChamberPaths.githubAuthStatus:
        return OpenChamberResponse(status: githubStatus, body: {'connected': githubConnected});
      case OpenChamberPaths.githubIssuesList:
        if (githubStatus < 200 || githubStatus >= 300) {
          return OpenChamberResponse(status: githubStatus, body: {'error': 'issues_failed'});
        }
        return OpenChamberResponse(
          status: githubStatus,
          body: {'connected': githubConnected, 'issues': githubIssues},
        );
      case OpenChamberPaths.githubPullsList:
        if (githubStatus < 200 || githubStatus >= 300) {
          return OpenChamberResponse(status: githubStatus, body: {'error': 'prs_failed'});
        }
        return OpenChamberResponse(
          status: githubStatus,
          body: {'connected': githubConnected, 'prs': githubPulls},
        );
      case OpenChamberPaths.messageQueueWorktreeOrder:
        if (worktreeOrderStatus < 200 || worktreeOrderStatus >= 300) {
          return OpenChamberResponse(status: worktreeOrderStatus, body: {'error': 'order_failed'});
        }
        final directory = request.method == 'PUT'
            ? (request.body?['projectDirectory']?.toString() ?? '')
            : (request.query['projectDirectory'] ?? '');
        if (request.method == 'PUT') {
          final raw = request.body?['orderedPaths'];
          final paths = raw is List ? raw.map((item) => item.toString()).toList() : <String>[];
          final nextRevision = (worktreeOrderRevisions[directory] ?? 0) + 1;
          worktreeOrders[directory] = paths;
          worktreeOrderRevisions[directory] = nextRevision;
          return OpenChamberResponse(
            status: worktreeOrderStatus,
            body: {
              'revision': nextRevision,
              'projectDirectory': directory,
              'worktreeOrder': {
                'projectDirectory': directory,
                'orderedPaths': paths,
                'revision': nextRevision,
              },
            },
          );
        }
        final revision = worktreeOrderRevisions[directory] ?? 0;
        return OpenChamberResponse(
          status: worktreeOrderStatus,
          body: {
            'projectDirectory': directory,
            'orderedPaths': worktreeOrders[directory] ?? const <String>[],
            'revision': revision,
          },
        );
      case OpenChamberPaths.behaviorAgentsMd:
        return OpenChamberResponse(status: catalogStatus, body: agentsMd);
      case OpenChamberPaths.authUrlToken:
        return OpenChamberResponse(status: catalogStatus, body: {'token': 'oc_url_test', 'expiresAt': DateTime.now().millisecondsSinceEpoch + 60000});
      case OpenChamberPaths.smallModel:
        return OpenChamberResponse(status: catalogStatus, body: smallModel);
      default:
        if (request.path.startsWith('/api/quota/')) {
          final id = Uri.decodeComponent(request.path.substring('/api/quota/'.length));
          return OpenChamberResponse(status: catalogStatus, body: quotas[id] ?? {'providerId': id, 'ok': false, 'configured': false});
        }
        if (request.path.contains('/messages')) {
          return OpenChamberResponse(status: messagesStatus, body: {'records': transcript, 'complete': true});
        }
        if (request.path.endsWith('/prompt_async')) {
          final parts = request.body?['parts'];
          if (parts is List) {
            final maps = parts.whereType<Map>().map((part) => part.map((key, value) => MapEntry(key.toString(), value))).toList();
            sentPromptParts.add(maps);
            for (final part in maps) {
              if (part['type'] == 'text') {
                sentPrompts.add(part['text']?.toString() ?? '');
              }
            }
            transcript = [
              ...transcript,
              {
                'info': {'id': request.body?['messageID'] ?? 'local', 'role': 'user'},
                'parts': maps,
              },
            ];
          }
          return OpenChamberResponse(status: promptStatus, body: true);
        }
        if (request.path.endsWith('/abort')) {
          return OpenChamberResponse(status: abortStatus, body: true);
        }
        if (request.path == OpenChamberPaths.fsRead || request.path.startsWith('/api/fs/serve')) {
          final path = request.path == OpenChamberPaths.fsRead
              ? (request.query['path'] ?? '')
              : Uri.decodeComponent(request.path.substring('/api/fs/serve'.length));
          final content = fileContents[path];
          if (content == null) {
            return OpenChamberResponse(status: 404, body: 'not found');
          }
          return OpenChamberResponse(status: fileStatus, body: content);
        }
        if (request.path.startsWith('/api/fs/prompt-attachments/')) {
          final mime = request.extraHeaders['X-OpenChamber-Mime'] ?? 'application/octet-stream';
          final sha = request.extraHeaders['X-OpenChamber-Sha256'] ?? '';
          final storedPath = '/data/openchamber/prompt-attachments/${request.path.split('/').last}';
          uploadedAttachments.add({
            'path': storedPath,
            'size': request.bytes?.length ?? 0,
            'mime': mime,
            'sha256': sha,
          });
          return OpenChamberResponse(
            status: uploadStatus,
            body: {
              'success': true,
              'path': storedPath,
              'size': request.bytes?.length ?? 0,
              'mime': mime,
              'sha256': sha,
            },
          );
        }
        if (request.path.startsWith('/api/auth/')) {
          return OpenChamberResponse(status: mutationStatus, body: const {'ok': true});
        }
        if (request.path.contains('/oauth/authorize') && request.path.startsWith('/api/provider/')) {
          oauthCalls.add({'path': request.path, 'method': request.method, ...?request.body});
          return OpenChamberResponse(
            status: mutationStatus,
            body: {
              'url': 'https://example.invalid/oauth/provider',
              'method': 'code',
            },
          );
        }
        if (request.path.contains('/oauth/callback') && request.path.startsWith('/api/provider/')) {
          oauthCalls.add({'path': request.path, 'method': request.method, ...?request.body});
          return OpenChamberResponse(status: mutationStatus, body: const {'ok': true});
        }
        if (request.path.contains('/auth') && request.path.startsWith('/api/provider/')) {
          return OpenChamberResponse(status: mutationStatus, body: const {'ok': true});
        }
        if (request.path == OpenChamberPaths.mcpAuthPending) {
          final state = request.query['state'] ?? request.body?['state']?.toString() ?? '';
          if (request.method == 'POST') {
            mcpPending[state] = {
              'name': request.body?['name'],
              'directory': request.body?['directory'],
            };
            return OpenChamberResponse(status: mutationStatus, body: const {'ok': true});
          }
          if (request.method == 'GET') {
            final pending = mcpPending[state];
            if (pending == null) return const OpenChamberResponse(status: 404, body: {'error': 'missing'});
            return OpenChamberResponse(status: 200, body: pending);
          }
          mcpPending.remove(state);
          return OpenChamberResponse(status: mutationStatus, body: const {'ok': true});
        }
        if (request.path.startsWith('/api/mcp/') && request.path.endsWith('/auth')) {
          oauthCalls.add({'path': request.path, 'method': request.method, ...?request.body});
          return OpenChamberResponse(
            status: mutationStatus,
            body: {
              'authorizationUrl': 'https://example.invalid/oauth/mcp?state=mcp-state-1',
            },
          );
        }
        if (request.path.startsWith('/api/mcp/') && request.path.endsWith('/auth/callback')) {
          oauthCalls.add({'path': request.path, 'method': request.method, ...?request.body});
          return OpenChamberResponse(status: mutationStatus, body: const {'ok': true});
        }
        if (request.path == OpenChamberPaths.permissions) {
          return OpenChamberResponse(status: 200, body: permissions);
        }
        if (request.path.startsWith('/api/permission/') && request.path.endsWith('/reply')) {
          permissionReplies.add({'path': request.path, ...?request.body});
          final id = request.path.split('/')[3];
          permissions = permissions.where((item) => item is! Map || item['id'] != id).toList();
          return OpenChamberResponse(status: mutationStatus, body: const {'ok': true});
        }
        if (request.path == OpenChamberPaths.pluginsFile && request.method == 'POST') {
          final created = <String, Object?>{
            'id': 'file-${pluginFiles.length + 1}',
            'fileName': request.body?['fileName'],
            'scope': request.body?['scope'] ?? 'user',
            'content': request.body?['content'] ?? '',
          };
          pluginFiles[created['id']!.toString()] = created;
          _appendPluginFile(created);
          return OpenChamberResponse(status: mutationStatus, body: created);
        }
        if (request.path.startsWith('/api/config/plugins/file/')) {
          final id = Uri.decodeComponent(request.path.split('/').last);
          if (request.method == 'GET') {
            final file = pluginFiles[id];
            if (file == null) return const OpenChamberResponse(status: 404, body: {'error': 'missing'});
            return OpenChamberResponse(status: 200, body: file);
          }
          if (request.method == 'DELETE') {
            pluginFiles.remove(id);
            _removePluginFile(id);
            return OpenChamberResponse(status: mutationStatus, body: const {'ok': true});
          }
          final current = Map<String, Object?>.from(pluginFiles[id] ?? {'id': id});
          current['content'] = request.body?['content'] ?? current['content'];
          pluginFiles[id] = current;
          return OpenChamberResponse(status: mutationStatus, body: current);
        }
        if (request.path.contains('/scheduled-tasks/') && request.path.endsWith('/run')) {
          _markScheduledRunning(request.path);
          return OpenChamberResponse(status: mutationStatus, body: const {'sessionId': 'sess-catalog'});
        }
        if (request.path.startsWith('/api/config/agents/')) {
          return _mutateNamedList(request, current: agents, assign: (next) => agents = next, idKey: 'name');
        }
        if (request.path.startsWith('/api/config/mcp/')) {
          return _mutateNamedList(request, current: mcp, assign: (next) => mcp = next, idKey: 'name');
        }
        if (request.path.startsWith('/api/config/commands/')) {
          return _mutateNamedCatalog(request, current: commands, assign: (next) => commands = next, listKey: 'commands');
        }
        if (request.path.startsWith('/api/config/skills/') && request.path != OpenChamberPaths.skills) {
          return _mutateNamedCatalog(request, current: skills, assign: (next) => skills = next, listKey: 'skills');
        }
        if (request.path.startsWith('/api/config/plugins/entry/')) {
          return _mutateNamedCatalog(request, current: plugins, assign: (next) => plugins = next, listKey: 'entries', idKey: 'id');
        }
        if (request.path.startsWith('/api/openchamber/assistants/share-operations/')) {
          final operationID = Uri.decodeComponent(request.path.split('/').last);
          final operation = shareOperations[operationID];
          if (operation == null) {
            return const OpenChamberResponse(status: 404, body: {'error': 'missing'});
          }
          return OpenChamberResponse(status: mutationStatus, body: operation);
        }
        if (request.path.startsWith('/api/openchamber/assistants/') && request.path.endsWith('/share')) {
          final assistantId = Uri.decodeComponent(request.path.split('/')[4]);
          final operationID = request.body?['operationID']?.toString() ?? '';
          final payload = request.body?['payload'];
          final messageID = payload is Map ? payload['messageID']?.toString() : null;
          shareCalls.add({'path': request.path, 'method': request.method, ...?request.body});
          final operation = <String, Object?>{
            'operationID': operationID,
            'assistantID': assistantId,
            'sessionID': 'sess-catalog',
            'messageID': messageID,
            'state': 'completed',
            'phase': 'done',
            'attempt': 1,
            'leaseExpiresAt': null,
            'errorCode': null,
          };
          shareOperations[operationID] = operation;
          return OpenChamberResponse(status: mutationStatus, body: operation);
        }
        if (request.path.startsWith('/api/openchamber/assistants/') && request.path.endsWith('/session/new')) {
          return OpenChamberResponse(
            status: mutationStatus,
            body: {
              'sessionID': 'sess-catalog',
              'directory': '/workspace/openchamber',
              'sessionGeneration': 1,
            },
          );
        }
        if (request.path.startsWith('/api/openchamber/assistants/')) {
          return _mutateAssistant(request);
        }
        if (request.path.startsWith('/api/openchamber/session-index/session/') && request.path.endsWith('/pin')) {
          final id = Uri.decodeComponent(request.path.split('/')[request.path.split('/').length - 2]);
          if (pinStatus == 501) {
            return OpenChamberResponse(status: 501, body: {'error': 'unsupported'});
          }
          if (!pinStatus.toString().startsWith('2')) {
            return OpenChamberResponse(status: pinStatus, body: {'error': 'pin_failed'});
          }
          _setPinned(id, pinned: request.method == 'POST');
          return OpenChamberResponse(status: pinStatus, body: const {'ok': true});
        }
        if (request.path.startsWith('/api/session/') &&
            !request.path.contains('/prompt_async') &&
            !request.path.contains('/abort') &&
            !request.path.contains('/messages') &&
            !request.path.endsWith('/fork')) {
          final shareId = _sessionIdFromSharePath(request.path);
          if (shareId != null) {
            if (sessionMutationStatus < 200 || sessionMutationStatus >= 300) {
              return OpenChamberResponse(status: sessionMutationStatus, body: {'error': 'share_failed'});
            }
            if (request.method == 'POST') {
              final url = 'https://share.example/$shareId';
              sessionShareUrls[shareId] = url;
              _patchIndexedSession(shareId, {
                'share': {'url': url},
              });
              return OpenChamberResponse(
                status: sessionMutationStatus,
                body: _sessionPayload(shareId, shareUrl: url),
              );
            }
            if (request.method == 'DELETE') {
              sessionShareUrls.remove(shareId);
              _patchIndexedSession(shareId, {'share': null});
              return OpenChamberResponse(
                status: sessionMutationStatus,
                body: _sessionPayload(shareId),
              );
            }
          }
          final id = Uri.decodeComponent(request.path.split('/').last);
          if (request.method == 'GET') {
            if (sessionMutationStatus < 200 || sessionMutationStatus >= 300) {
              return OpenChamberResponse(status: sessionMutationStatus, body: {'error': 'get_failed'});
            }
            return OpenChamberResponse(
              status: sessionMutationStatus,
              body: _sessionPayload(id, shareUrl: sessionShareUrls[id]),
            );
          }
          if (request.method == 'DELETE') {
            if (sessionMutationStatus == 404) {
              _removeIndexedSession(id);
              return const OpenChamberResponse(status: 404, body: {'error': 'missing'});
            }
            if (sessionMutationStatus < 200 || sessionMutationStatus >= 300) {
              return OpenChamberResponse(status: sessionMutationStatus, body: {'error': 'delete_failed'});
            }
            _removeIndexedSession(id);
            return OpenChamberResponse(status: sessionMutationStatus, body: const {'ok': true});
          }
          if (request.method == 'PATCH') {
            if (sessionMutationStatus < 200 || sessionMutationStatus >= 300) {
              return OpenChamberResponse(status: sessionMutationStatus, body: {'error': 'update_failed'});
            }
            _patchIndexedSession(id, request.body ?? const {});
            return OpenChamberResponse(status: sessionMutationStatus, body: const {'ok': true});
          }
        }
        if (request.path == OpenChamberPaths.fsClone) {
          if (cloneStatus < 200 || cloneStatus >= 300) {
            return OpenChamberResponse(status: cloneStatus, body: {'error': 'clone_failed'});
          }
          final destination = request.body?['destinationPath']?.toString() ?? '';
          final name = destination.contains('/') ? destination.split('/').last : destination;
          if (destination.isNotEmpty) {
            fsEntries = [
              ...fsEntries,
              {'name': name, 'path': destination, 'type': 'directory'},
            ];
          }
          return OpenChamberResponse(status: cloneStatus, body: {'success': true, 'path': destination});
        }
        if (request.path.startsWith('/api/projects/') &&
            request.path.endsWith('/scheduled-tasks') &&
            request.method == 'PUT') {
          final parts = request.path.split('/');
          final projectId = parts.length >= 4 ? Uri.decodeComponent(parts[3]) : '';
          final taskInput = request.body?['task'];
          if (taskInput is! Map) {
            return const OpenChamberResponse(status: 400, body: {'error': 'task payload is required'});
          }
          final created = <String, Object?>{
            'id': taskInput['id']?.toString().isNotEmpty == true
                ? taskInput['id']
                : 'task-${DateTime.now().microsecondsSinceEpoch}',
            ...taskInput.map((key, value) => MapEntry(key.toString(), value)),
          };
          _upsertMemoryScheduledTask(projectId, created);
          return OpenChamberResponse(
            status: mutationStatus,
            body: {
              'created': true,
              'task': created,
              'tasks': [created],
            },
          );
        }
        if (request.path.startsWith('/api/session/') && request.path.endsWith('/fork')) {
          if (sessionMutationStatus < 200 || sessionMutationStatus >= 300) {
            return OpenChamberResponse(status: sessionMutationStatus, body: {'error': 'fork_failed'});
          }
          final sourceId = Uri.decodeComponent(request.path.split('/')[request.path.split('/').length - 2]);
          final id = 'ses_fork_${createdSessions.length + 1}';
          final directory = request.query['directory'] ?? '/workspace/openchamber';
          final created = <String, Object?>{
            'id': id,
            'title': 'Fork of $sourceId',
            'directory': directory,
          };
          createdSessions.add(created);
          _upsertIndexedSession({
            ...created,
            'parentID': sourceId,
            'project': {'name': _basename(directory)},
            'time': {'updated': DateTime.now().millisecondsSinceEpoch},
          });
          return OpenChamberResponse(status: sessionMutationStatus, body: created);
        }
        if (request.path.startsWith('/api/projects/') && request.path.endsWith('/icon/discover')) {
          if (discoverStatus < 200 || discoverStatus >= 300) {
            return OpenChamberResponse(status: discoverStatus, body: {'error': 'discover_failed'});
          }
          final parts = request.path.split('/');
          final id = parts.length >= 4 ? Uri.decodeComponent(parts[3]) : '';
          final projects = settings['projects'];
          if (projects is List && id.isNotEmpty) {
            settings = {
              ...settings,
              'projects': projects.map((item) {
                if (item is! Map || item['id']?.toString() != id) return item;
                return {
                  ...item.map((key, value) => MapEntry(key.toString(), value)),
                  'iconImage': {'mime': 'image/png', 'updatedAt': 1, 'source': 'auto'},
                };
              }).toList(),
            };
          }
          return OpenChamberResponse(status: discoverStatus, body: {'ok': true, 'settings': settings});
        }
        if (request.path == OpenChamberPaths.fsHome) {
          return OpenChamberResponse(status: fsStatus, body: {'home': fsHome});
        }
        if (request.path == OpenChamberPaths.fsList) {
          final path = request.query['path'] ?? fsHome;
          final entries = fsEntries.where((entry) {
            final entryPath = entry['path']?.toString() ?? '';
            final parent = entryPath.contains('/') ? entryPath.substring(0, entryPath.lastIndexOf('/')) : '';
            return parent == path || (path == '/' && entryPath.split('/').where((part) => part.isNotEmpty).length == 1);
          }).toList();
          return OpenChamberResponse(status: fsStatus, body: {'entries': entries});
        }
        if (request.path == OpenChamberPaths.gitCheck) {
          final directory = request.query['directory'] ?? '';
          return OpenChamberResponse(
            status: gitStatus,
            body: {'isGitRepository': directory.contains('openchamber') || directory == '/workspace'},
          );
        }
        if (request.path == OpenChamberPaths.gitWorktrees) {
          if (gitStatus < 200 || gitStatus >= 300) {
            return OpenChamberResponse(status: gitStatus, body: {'error': 'git_failed'});
          }
          final parent = request.query['directory'] ?? '';
          if (request.method == 'POST') {
            final name = request.body?['worktreeName']?.toString() ?? 'worktree';
            final path = '$parent/.worktrees/$name';
            _upsertIndexedSession({
              'id': 'sess-wt-$name',
              'title': 'Worktree $name',
              'directory': path,
              'parentID': null,
              'project': {'name': _basename(parent)},
              'time': {'updated': DateTime.now().millisecondsSinceEpoch},
              'branch': name,
            });
            return OpenChamberResponse(status: gitStatus, body: {'path': path, 'worktreeName': name});
          }
          if (request.method == 'DELETE') {
            final worktreePath = request.body?['directory']?.toString() ?? '';
            _removeIndexDirectory(worktreePath);
            return OpenChamberResponse(status: gitStatus, body: const {'success': true});
          }
        }
        return const OpenChamberResponse(status: 404, body: {'error': 'not_found'});
    }
  }
}

List<HomeSessionRow> fixtureHomeSessions() => rowsFromSessionIndex(parseSessionIndexSnapshot(MemoryOpenChamberTransport.defaultTestSessionIndex)!);
