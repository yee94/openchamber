import 'chat_timeline.dart';
import 'home_session.dart';
import 'openchamber_http.dart';
import 'session_index.dart';

/// Official OpenChamber / OpenCode calls used by mobile connect + home + chat.
class OpenChamberApi {
  OpenChamberApi({OpenChamberTransport? transport})
      : _transport = transport ?? LiveOpenChamberTransport();

  final OpenChamberTransport _transport;

  Future<HealthResult> health(Uri base) async {
    final response = await _transport.send(
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
    final response = await _transport.send(
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
    final response = await _transport.send(
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
    final response = await _transport.send(
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

  Future<SessionIndexSnapshot?> loadSessionIndex(Uri base, {required String bearer}) async {
    final response = await _transport.send(
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
    final response = await _transport.send(
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
    final response = await _transport.send(
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
    return parseTurnPageMessages(response.body);
  }

  Future<void> promptAsync({
    required Uri base,
    required String bearer,
    required String sessionId,
    required String directory,
    required String messageId,
    required String text,
  }) async {
    final path = OpenChamberPaths.sessionPromptAsync(sessionId);
    final response = await _transport.send(
      base,
      OpenChamberRequest(
        method: 'POST',
        path: path,
        bearer: bearer,
        body: {
          'sessionID': sessionId,
          'directory': directory,
          'messageID': messageId,
          'parts': [
            {'type': 'text', 'text': text},
          ],
        },
      ),
    );
    if (!response.ok) {
      throw OpenChamberHttpException(response.status, path);
    }
  }

  Future<void> abortSession({
    required Uri base,
    required String bearer,
    required String sessionId,
    required String directory,
  }) async {
    final path = OpenChamberPaths.sessionAbort(sessionId);
    final response = await _transport.send(
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
    final response = await _transport.send(
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
    final response = await _transport.send(
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
    final response = await _transport.send(
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
}

List<ChatMessage> parseTurnPageMessages(Object? payload) {
  if (payload is! Map) return const [];
  final records = payload['records'];
  if (records is! List) return const [];
  final messages = <ChatMessage>[];
  for (final record in records) {
    if (record is! Map) continue;
    final info = record['info'];
    if (info is! Map) continue;
    final id = info['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final role = info['role']?.toString() ?? '';
    final parts = record['parts'];
    final body = _textFromParts(parts);
    if (body.isEmpty && role.isEmpty) continue;
    messages.add(ChatMessage(id: id, body: body, isUser: role == 'user'));
  }
  return messages;
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

String _textFromParts(Object? parts) {
  if (parts is! List) return '';
  final chunks = <String>[];
  for (final part in parts) {
    if (part is! Map) continue;
    final type = part['type']?.toString();
    if (type == 'text') {
      final text = part['text']?.toString();
      if (text != null && text.isNotEmpty) chunks.add(text);
    }
  }
  return chunks.join('\n');
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
  })  : sessionIndex = sessionIndex ?? defaultTestSessionIndex,
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
  int authStatus = 200;
  int unlockStatus = 200;
  int redeemStatus = 200;
  int indexStatus = 200;
  int messagesStatus = 200;
  int promptStatus = 200;
  int abortStatus = 200;
  int statusStatus = 200;
  int pushStatus = 200;

  final List<OpenChamberRequest> calls = [];
  final List<String> sentPrompts = [];

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
            'time': {'updated': 1, 'pinned': '2026-09-01T00:00:00.000Z'},
            'branch': 'work/flutter-native',
            'unread': true,
          },
          {
            'id': 'sess-busy',
            'title': 'Fix composer IME',
            'directory': '/workspace/openchamber',
            'parentID': null,
            'project': {'name': 'openchamber'},
            'time': {'updated': 2},
            'branch': 'feat/home',
          },
          {
            'id': 'sess-catalog',
            'title': 'New Session',
            'directory': '/workspace/openchamber',
            'parentID': null,
            'project': {'name': 'openchamber'},
            'time': {'updated': 3},
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

  @override
  Future<OpenChamberResponse> send(Uri base, OpenChamberRequest request) async {
    calls.add(request);
    switch (request.path) {
      case OpenChamberPaths.health:
        return OpenChamberResponse(status: healthStatus, body: health);
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
      default:
        if (request.path.contains('/messages')) {
          return OpenChamberResponse(status: messagesStatus, body: {'records': transcript, 'complete': true});
        }
        if (request.path.endsWith('/prompt_async')) {
          final parts = request.body?['parts'];
          if (parts is List && parts.isNotEmpty && parts.first is Map) {
            sentPrompts.add((parts.first as Map)['text']?.toString() ?? '');
            transcript = [
              ...transcript,
              {
                'info': {'id': request.body?['messageID'] ?? 'local', 'role': 'user'},
                'parts': [
                  {'type': 'text', 'text': (parts.first as Map)['text']},
                ],
              },
            ];
          }
          return OpenChamberResponse(status: promptStatus, body: true);
        }
        if (request.path.endsWith('/abort')) {
          return OpenChamberResponse(status: abortStatus, body: true);
        }
        return const OpenChamberResponse(status: 404, body: {'error': 'not_found'});
    }
  }
}

List<HomeSessionRow> fixtureHomeSessions() => rowsFromSessionIndex(parseSessionIndexSnapshot(MemoryOpenChamberTransport.defaultTestSessionIndex)!);
