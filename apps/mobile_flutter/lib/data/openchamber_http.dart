import 'dart:convert';
import 'dart:io';

/// Official OpenChamber / OpenCode paths used by `packages/ui` mobile.
/// Do not invent endpoints. See `packages/ui/src/apps/mobileConnections.ts`
/// and `packages/ui/src/lib/session-index-api.ts`.
abstract final class OpenChamberPaths {
  static const health = '/health';
  static const authSession = '/auth/session';
  static const pairingRedeem = '/api/client-auth/pairing/redeem';
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
  static const globalEvent = '/api/global/event';
  static const pushApnsToken = '/api/push/apns-token';
  static const pushVisibility = '/api/push/visibility';
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
    this.bearer,
    this.extraHeaders = const {},
    this.stream = false,
    this.timeout = const Duration(seconds: 8),
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, Object?>? body;
  final String? bearer;
  final Map<String, String> extraHeaders;
  final bool stream;
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
    if (request.body != null) {
      httpRequest.headers.contentType = ContentType.json;
      httpRequest.add(utf8.encode(jsonEncode(request.body)));
    }
    final httpResponse = await httpRequest.close().timeout(request.timeout);
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
