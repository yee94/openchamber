import 'chat_timeline.dart';
import 'home_session.dart';
import 'openchamber_http.dart';
import 'session_index.dart';

/// Official OpenChamber / OpenCode calls used by mobile connect + home + chat.
class CreatedSession {
  const CreatedSession({required this.id, this.title, this.directory});

  final String id;
  final String? title;
  final String? directory;
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

  Future<Object?> getDictationStatus({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.dictationStatus), bearer);
  }

  Future<Object?> getTtsStatus({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.ttsStatus), bearer);
  }

  Future<Object?> getSmallModel({required Uri base, String? bearer}) {
    return _requireOk(base, const OpenChamberRequest(method: 'GET', path: OpenChamberPaths.smallModel), bearer);
  }

  Future<Object?> getQuota({required Uri base, String? bearer, required String providerId}) {
    return _requireOk(base, OpenChamberRequest(method: 'GET', path: OpenChamberPaths.quota(providerId)), bearer);
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
  int createStatus = 200;
  int settingsStatus = 200;
  int catalogStatus = 200;

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
  Object? dictationStatus = defaultTestDictation;
  Object? ttsStatus = const {'available': true};
  Object? smallModel = defaultTestSmallModel;
  Map<String, Object?> quotas = Map<String, Object?>.from(defaultTestQuotas);

  final List<OpenChamberRequest> calls = [];
  final List<String> sentPrompts = [];
  final List<Map<String, Object?>> createdSessions = [];
  List<String> eventChunks = const [];

  @override
  Stream<List<int>> openByteStream(Uri base, OpenChamberRequest request) async* {
    calls.add(request);
    for (final chunk in eventChunks) {
      yield chunk.codeUnits;
    }
  }

  @override
  Future<void> close() async {}

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
        'models': {'claude-sonnet-4': {'id': 'claude-sonnet-4'}},
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
      {'id': 'asst-1', 'name': 'Home', 'providerID': 'anthropic', 'modelID': 'claude-sonnet-4', 'mode': 'chat'},
    ],
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
    'files': <Object?>[],
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

  static const Map<String, Object?> defaultTestDictation = {
    'models': [
      {'id': 'whisper-small', 'installed': true},
    ],
  };

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
      case OpenChamberPaths.sessionCreate:
        final directory = request.query['directory'] ?? '';
        final id = 'ses_flutter_${createdSessions.length + 1}';
        final created = <String, Object?>{
          'id': id,
          'title': request.body?['title'] ?? 'New Session',
          'directory': directory,
        };
        createdSessions.add(created);
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
      case OpenChamberPaths.behaviorAgentsMd:
        return OpenChamberResponse(status: catalogStatus, body: agentsMd);
      case OpenChamberPaths.dictationStatus:
        return OpenChamberResponse(status: catalogStatus, body: dictationStatus);
      case OpenChamberPaths.ttsStatus:
        return OpenChamberResponse(status: catalogStatus, body: ttsStatus);
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
