import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Official OpenChamber / OpenCode paths used by `packages/ui` mobile.
/// Do not invent endpoints. See `packages/ui/src/apps/mobileConnections.ts`
/// and `packages/ui/src/lib/session-index-api.ts`.
abstract final class OpenChamberPaths {
  static const health = '/health';
  static const authSession = '/auth/session';
  static const pairingRedeem = '/api/client-auth/pairing/redeem';
  static const connectionCandidates = '/api/client-auth/connection/candidates';
  static const sessionIndex = '/api/openchamber/session-index';
  static const sessionIndexSync = '/api/openchamber/session-index/sync';
  static String sessionMessages(String sessionId) =>
      '/api/openchamber/sessions/${Uri.encodeComponent(sessionId)}/messages';
  static String sessionPromptAsync(String sessionId) =>
      '/api/session/${Uri.encodeComponent(sessionId)}/prompt_async';
  static String sessionAbort(String sessionId) =>
      '/api/session/${Uri.encodeComponent(sessionId)}/abort';
  static const sessionStatus = '/api/session/status';
  static const sessionCreate = '/api/session';
  static String session(String sessionId) =>
      '/api/session/${Uri.encodeComponent(sessionId)}';
  /// OpenCode `session.share` / `session.unshare`.
  static String sessionShare(String sessionId) => '${session(sessionId)}/share';
  static String sessionIndexPin(String sessionId) =>
      '/api/openchamber/session-index/session/${Uri.encodeComponent(sessionId)}/pin';
  static const fsHome = '/api/fs/home';
  static const fsList = '/api/fs/list';
  static const fsClone = '/api/fs/clone';
  static const fsMkdir = '/api/fs/mkdir';
  static const gitCheck = '/api/git/check';
  static const gitWorktrees = '/api/git/worktrees';
  static const githubAuthStatus = '/api/github/auth/status';
  static const githubIssuesList = '/api/github/issues/list';
  static const githubPullsList = '/api/github/pulls/list';
  static const messageQueueWorktreeOrder = '/api/openchamber/message-queue/worktrees/order';
  static const globalEvent = '/api/global/event';
  static const globalEventWs = '/api/global/event/ws';
  static const pushApnsToken = '/api/push/apns-token';
  static const pushVisibility = '/api/push/visibility';
  static const configSettings = '/api/config/settings';
  static const providerCatalog = '/api/config/catalog/providers';
  static const agents = '/api/agent';
  static const agentsMetadata = '/api/config/agents/metadata';
  static const assistantsSnapshot = '/api/openchamber/assistants/snapshot';
  static const assistantsCapability = '/api/openchamber/assistants/capability';
  static const commandsMetadata = '/api/config/commands/metadata';
  static const mcp = '/api/config/mcp';
  static const plugins = '/api/config/plugins';
  static const skills = '/api/config/skills';
  static const snippets = '/api/config/snippets';
  static const magicPrompts = '/api/magic-prompts';
  static const gitIdentities = '/api/git/identities';
  static const gitGlobalIdentity = '/api/git/global-identity';
  static const behaviorAgentsMd = '/api/behavior/agents-md';
  static const smallModel = '/api/small-model';
  static const authUrlToken = '/auth/url-token';
  static const assistants = '/api/openchamber/assistants';
  static const assistantsSettings = '/api/openchamber/assistants/settings';
  static const scheduledTasks = '/api/openchamber/scheduled-tasks';
  static const scheduledTaskRuns = '/api/openchamber/scheduled-task-runs';
  static const pluginsEntry = '/api/config/plugins/entry';
  static const pluginsFile = '/api/config/plugins/file';
  static const skillsInstall = '/api/config/skills/install';
  static const mcpAuthPending = '/api/mcp/auth/pending';
  static const permissions = '/api/permission';
  static String quota(String providerId) =>
      '/api/quota/${Uri.encodeComponent(providerId)}';
  static String promptAttachment(String attachmentId) =>
      '/api/fs/prompt-attachments/${Uri.encodeComponent(attachmentId)}';
  static const fsRead = '/api/fs/read';
  static String fsServe(String path) {
    final normalized = path.replaceAll('\\', '/');
    final encoded = normalized.startsWith('/') ? normalized : '/$normalized';
    return '/api/fs/serve$encoded';
  }
  static String providerAuth(String providerId) =>
      '/api/auth/${Uri.encodeComponent(providerId)}';
  static String providerAuthDelete(String providerId) =>
      '/api/provider/${Uri.encodeComponent(providerId)}/auth';
  static String configAgent(String name) =>
      '/api/config/agents/${Uri.encodeComponent(name)}';
  static String assistant(String id) =>
      '/api/openchamber/assistants/${Uri.encodeComponent(id)}';
  static String assistantSessionNew(String id) =>
      '${assistant(id)}/session/new';
  static String assistantShare(String id) => '${assistant(id)}/share';
  static String assistantShareOperation(String operationId) =>
      '/api/openchamber/assistants/share-operations/${Uri.encodeComponent(operationId)}';
  static String configMcp(String name) =>
      '/api/config/mcp/${Uri.encodeComponent(name)}';
  static String pluginEntry(String id) =>
      '/api/config/plugins/entry/${Uri.encodeComponent(id)}';
  static String pluginFile(String id) =>
      '/api/config/plugins/file/${Uri.encodeComponent(id)}';
  static String providerOAuthAuthorize(String providerId) =>
      '/api/provider/${Uri.encodeComponent(providerId)}/oauth/authorize';
  static String providerOAuthCallback(String providerId) =>
      '/api/provider/${Uri.encodeComponent(providerId)}/oauth/callback';
  static String mcpAuthStart(String name) =>
      '/api/mcp/${Uri.encodeComponent(name)}/auth';
  static String mcpAuthCallback(String name) =>
      '/api/mcp/${Uri.encodeComponent(name)}/auth/callback';
  static String permissionReply(String requestId) =>
      '/api/permission/${Uri.encodeComponent(requestId)}/reply';
  static String scheduledTasksForProject(String projectId) =>
      '/api/projects/${Uri.encodeComponent(projectId)}/scheduled-tasks';
  static String scheduledTaskRun(String projectId, String taskId) =>
      '${scheduledTasksForProject(projectId)}/${Uri.encodeComponent(taskId)}/run';
  static String sessionFork(String sessionId) => '${session(sessionId)}/fork';
  static String configSkill(String name) =>
      '/api/config/skills/${Uri.encodeComponent(name)}';
  static String configCommand(String name) =>
      '/api/config/commands/${Uri.encodeComponent(name)}';
  static String projectIconDiscover(String projectId) =>
      '/api/projects/${Uri.encodeComponent(projectId)}/icon/discover';
}

class OpenChamberHttpException implements Exception {
  const OpenChamberHttpException(this.status, this.path, {this.code});

  final int status;
  final String path;
  final String? code;

  @override
  String toString() => 'OpenChamberHttpException($status $path)';
}

class HealthResult {
  const HealthResult({required this.ok, this.serverId, this.openchamberVersion});

  final bool ok;
  final String? serverId;
  final String? openchamberVersion;
}

class AuthSessionResult {
  const AuthSessionResult({
    required this.authenticated,
    this.locked = false,
    this.disabled = false,
    this.scope,
    this.tunnelLocked = false,
  });

  final bool authenticated;
  final bool locked;
  final bool disabled;
  final String? scope;
  final bool tunnelLocked;

  bool get needsPassword => locked && !disabled && !authenticated;
  bool get isUsable => authenticated && (disabled || scope == 'client' || scope == null);
}

class UnlockResult {
  const UnlockResult({required this.authenticated, this.clientToken});

  final bool authenticated;
  final String? clientToken;
}

class RedeemResult {
  const RedeemResult({
    required this.ok,
    this.clientToken,
    this.serverLabel,
    this.serverUrl,
  });

  final bool ok;
  final String? clientToken;
  final String? serverLabel;
  final String? serverUrl;
}

class OpenChamberRequest {
  const OpenChamberRequest({
    required this.method,
    required this.path,
    this.query = const {},
    this.body,
    this.bytes,
    this.bearer,
    this.extraHeaders = const {},
    this.stream = false,
    this.rawResponse = false,
    this.timeout = const Duration(seconds: 8),
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, Object?>? body;
  /// Raw body for `PUT /api/fs/prompt-attachments/:id`. Never log these bytes.
  final List<int>? bytes;
  final String? bearer;
  final Map<String, String> extraHeaders;
  final bool stream;
  /// When true, [OpenChamberResponse.body] is raw bytes.
  final bool rawResponse;
  final Duration timeout;
}

/// Dummy parse base from `packages/ui/src/lib/relay/tunnel-payloads.ts`.
const tunnelParseBase = 'http://tunnel.invalid';

/// Transport for official OpenChamber HTTP. Implementations must never log
/// bearer tokens, pairing secrets, or passwords.
abstract class OpenChamberTransport {
  Future<OpenChamberResponse> send(Uri base, OpenChamberRequest request);

  /// Long-lived byte stream (SSE). Direct uses HttpClient; relay uses HTTP mux
  /// `HttpBody` frames. Must yield chunks as they arrive — do not wait for
  /// `StreamEnd` before the first event.
  Stream<List<int>> openByteStream(Uri base, OpenChamberRequest request);

  Future<void> close();
}

class OpenChamberResponse {
  const OpenChamberResponse({required this.status, required this.body});

  final int status;
  final Object? body;

  bool get ok => status >= 200 && status < 300;

  Map<String, Object?> get map {
    final value = body;
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }
}

class LiveOpenChamberTransport implements OpenChamberTransport {
  LiveOpenChamberTransport({HttpClient? http}) : _http = http ?? HttpClient();

  final HttpClient _http;

  @override
  Future<OpenChamberResponse> send(Uri base, OpenChamberRequest request) async {
    final uri = base.replace(
      path: _join(base.path, request.path),
      queryParameters: request.query.isEmpty ? null : request.query,
    );
    final httpRequest = await _http.openUrl(request.method, uri);
    httpRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (request.bearer != null && request.bearer!.isNotEmpty) {
      httpRequest.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${request.bearer}');
    }
    request.extraHeaders.forEach(httpRequest.headers.set);
    final bytes = request.bytes;
    if (bytes != null) {
      httpRequest.contentLength = bytes.length;
      httpRequest.add(bytes);
    } else if (request.body != null) {
      httpRequest.headers.contentType = ContentType.json;
      httpRequest.add(utf8.encode(jsonEncode(request.body)));
    }
    final httpResponse = await httpRequest.close().timeout(request.timeout);
    if (request.rawResponse) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in httpResponse) {
        builder.add(chunk);
      }
      return OpenChamberResponse(status: httpResponse.statusCode, body: builder.takeBytes());
    }
    final raw = await utf8.decodeStream(httpResponse);
    Object? decoded;
    if (raw.isNotEmpty) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = raw;
      }
    }
    return OpenChamberResponse(status: httpResponse.statusCode, body: decoded);
  }

  static String _join(String basePath, String path) {
    if (basePath.isEmpty || basePath == '/') return path;
    if (path.startsWith('/')) return '$basePath$path';
    return '$basePath/$path';
  }

  @override
  Stream<List<int>> openByteStream(Uri base, OpenChamberRequest request) async* {
    final uri = base.replace(
      path: _join(base.path, request.path),
      queryParameters: request.query.isEmpty ? null : request.query,
    );
    final httpRequest = await _http.openUrl(request.method, uri);
    httpRequest.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    if (request.bearer != null && request.bearer!.isNotEmpty) {
      httpRequest.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${request.bearer}');
    }
    request.extraHeaders.forEach(httpRequest.headers.set);
    final httpResponse = await httpRequest.close();
    if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
      throw OpenChamberHttpException(httpResponse.statusCode, request.path);
    }
    await for (final chunk in httpResponse) {
      yield chunk;
    }
  }

  @override
  Future<void> close() async {
    _http.close(force: true);
  }
}

Uri? normalizeServerBase(String raw) {
  final error = raw.trim();
  if (error.isEmpty) return null;
  final uri = Uri.tryParse(error);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
    return null;
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );
}

String connectionKeyFor({required String url, String? relayUrl, String? serverId}) {
  final relay = relayUrl?.trim();
  final sid = serverId?.trim();
  if (relay != null && relay.isNotEmpty && sid != null && sid.isNotEmpty) {
    return 'relay:$sid@$relay';
  }
  return normalizeServerBase(url)?.toString() ?? url.trim();
}

String tokenStorageKey(String connectionKey) =>
    'openchamber.mobile.token.${Uri.encodeComponent(connectionKey)}';

const deviceIdStorageKey = 'openchamber.mobile.deviceId';
