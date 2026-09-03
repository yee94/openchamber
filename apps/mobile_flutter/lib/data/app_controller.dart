import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../native/deep_link.dart';
import '../native/external_browser.dart';
import '../native/live_activity_controller.dart';
import '../native/platform_channels.dart';
import '../native/push_registration.dart';
import '../native/qr_scanner.dart';
import '../native/share_targeting.dart';
import '../native/tts_playback.dart';
import 'dictation.dart';
import 'event_pipeline.dart';
import 'oauth.dart';
import 'assistant_scheduled.dart';
import 'chat_timeline.dart';
import 'home_session.dart';
import 'instance_store.dart';
import 'openchamber_api.dart';
import 'openchamber_http.dart';
import 'pairing_payload.dart';
import 'prompt_attachment.dart';
import 'relay/codec.dart';
import 'relay/tunnel_client.dart';
import 'secure_store.dart';
import 'session_index.dart';
import 'settings_remote.dart';
import 'sse.dart';
import 'widget_snapshot.dart';

typedef OpenRelayTunnel = Future<OpenChamberTransport> Function(PairingRelayCandidate relay);

enum AppPhase { splash, connect, shell }

enum ConnectForm { welcome, password }

class AppController extends ChangeNotifier {
  AppController({
    required SecureStore store,
    InstanceSnapshot? seed,
    QrScanner? qrScanner,
    DeepLinkListener? deepLinks,
    OpenChamberApi? api,
    NativePush? push,
    OpenRelayTunnel? openRelayTunnel,
    ExternalBrowser? browser,
    DictationSession? dictation,
  })  : _store = store,
        _qrScanner = qrScanner ?? QrScanner(),
        _deepLinks = deepLinks ?? DeepLinkListener(),
        _api = api ?? OpenChamberApi(transport: _defaultTransport()),
        _push = push ?? NativePush(),
        browser = browser ?? ExternalBrowser(),
        _instances = seed?.instances ?? const [],
        _activeId = seed?.activeId {
    _directTransport = _api.transport;
    _openRelayTunnel = openRelayTunnel ?? _defaultOpenRelay;
    this.dictation = dictation ??
        OfficialDictation(
          resolveBase: () => activeBase,
          resolveBearer: () => activeBearer,
          resolveTransport: () => _api.transport,
          api: _api,
        );
    remoteSettings = SettingsRemoteStore(
      api: _api,
      base: () => activeBase,
      bearer: () => activeBearer,
      onChanged: notifyListeners,
    );
  }

  late final SettingsRemoteStore remoteSettings;

  final SecureStore _store;
  final QrScanner _qrScanner;
  final DeepLinkListener _deepLinks;
  final OpenChamberApi _api;
  final NativePush _push;
  final ExternalBrowser browser;
  late final DictationSession dictation;
  OAuthCallback? pendingOAuthCallback;
  late final OpenChamberTransport _directTransport;
  late final OpenRelayTunnel _openRelayTunnel;
  late final InstanceRepository _repository = InstanceRepository(_store);

  AppPhase phase = AppPhase.splash;
  ConnectForm connectForm = ConnectForm.welcome;
  Locale locale = AppStrings.en;
  ThemeMode themeMode = ThemeMode.system;
  List<SavedInstance> _instances;
  String? _activeId;
  SavedInstance? pendingUnlock;
  String? connectErrorKey;
  bool connecting = false;
  bool notificationsEnabled = true;
  bool notifyOnCompletion = true;
  bool notifyOnError = true;
  bool notifyOnQuestion = true;
  bool backgroundPushEnabled = false;
  List<HomeSessionRow> sessions = const [];
  String? sessionsErrorKey;
  bool sessionsLoading = false;
  Map<String, String> sessionStatusById = const {};
  String? instanceVersion;
  String? lastBoundRelayUrl;
  String? _pushBindKey;
  bool _appVisible = true;
  Timer? _statusPoll;
  Timer? _liveActivityTimer;
  Timer? _visibilityHeartbeat;
  StreamSubscription<dynamic>? _eventSub;
  Timer? _eventReconnect;
  String? _lastEventId;
  int _eventFailures = 0;
  DateTime? _wsFallbackUntil;
  String liveEventTransport = 'none';
  WebSocket? _eventSocket;
  TunnelWebSocket? _eventTunnel;
  bool liveEventsConnected = false;
  int transcriptEpoch = 0;
  SessionIndexSnapshot? lastIndex;
  String? createSessionErrorKey;
  SettingsResource<AssistantSnapshotView> assistantSnapshot = const SettingsResource();
  SettingsResource<List<ScheduledTaskRecord>> scheduledTasks = const SettingsResource();
  SettingsResource<List<ScheduledRunRecord>> scheduledRuns = const SettingsResource();
  List<String> scheduledFailedProjectIds = const [];
  String? scheduledFilterProjectId;
  String? scheduledFilterTaskId;

  List<SavedInstance> get instances => List.unmodifiable(_instances);
  SavedInstance? get activeInstance {
    if (_activeId == null) return null;
    for (final instance in _instances) {
      if (instance.id == _activeId) return instance;
    }
    return null;
  }

  bool get isConnected => phase == AppPhase.shell && activeInstance != null;

  Uri? get activeBase {
    if (_api.transport is RelayTunnelTransport) {
      return RelayTunnelTransport.dummyBase;
    }
    final instance = activeInstance;
    if (instance == null) return null;
    return normalizeServerBase(instance.url);
  }

  String? get activeBearer => activeInstance?.clientToken;

  Future<void> bootstrap({bool skipDelay = false}) async {
    locale = _localeFromCode(await _store.read(localeStorageKey));
    themeMode = _themeFromCode(await _store.read(themeStorageKey));
    final snapshot = await _repository.load();
    _instances = await _hydrateTokens(snapshot.instances);
    _activeId = snapshot.activeId;
    if (_useNativeLinks) {
      _deepLinks.listen(handleIncomingLink);
    }
    if (!skipDelay) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (_useNativeLinks) {
      final initial = await _deepLinks.takeInitial();
      if (initial != null && initial.isNotEmpty) {
        await handleIncomingLink(initial);
        return;
      }
    }
    final last = _mostRecentInstance();
    if (last != null) {
      final ok = await _probeAndActivate(last, existing: true);
      if (ok) return;
    }
    phase = AppPhase.connect;
    connectForm = ConnectForm.welcome;
    notifyListeners();
  }

  Future<void> handleIncomingLink(String raw) async {
    final link = classifyDeepLink(raw);
    if (link.kind == DeepLinkKind.pairing) {
      await connect(pairingLink: raw);
      return;
    }
    if (link.kind == DeepLinkKind.oauth) {
      pendingOAuthCallback = parseOAuthCallbackUri(raw);
      notifyListeners();
      return;
    }
    pendingDeepLink = link;
    notifyListeners();
  }

  IncomingDeepLink? pendingDeepLink;
  final LiveActivityController liveActivity = LiveActivityController();

  OAuthCallback? takeOAuthCallback() {
    final value = pendingOAuthCallback;
    pendingOAuthCallback = null;
    return value;
  }

  Future<ProviderOAuthStart> startProviderOAuth(String providerId, {int method = 0}) async {
    final payload = await remoteSettings.startProviderOAuth(providerId, method: method);
    final start = parseProviderOAuthStart(payload);
    if (start.canOpenBrowser) {
      await browser.open(start.url!);
    }
    if (start.isAuto) {
      await remoteSettings.completeProviderOAuth(providerId, method: method);
    }
    return start;
  }

  Future<void> completeProviderOAuth(String providerId, {int method = 0, String? code}) {
    return remoteSettings.completeProviderOAuth(providerId, method: method, code: code);
  }

  Future<String> startMcpOAuth(String name, {String? directory}) async {
    final payload = await remoteSettings.startMcpOAuth(name);
    final url = parseMcpAuthorizationUrl(payload);
    if (url == null || url.isEmpty) {
      throw const OpenChamberHttpException(500, '/api/mcp/auth');
    }
    final state = mcpOAuthStateKey(url);
    if (state != null) {
      await remoteSettings.queueMcpAuthPending(state: state, name: name, directory: directory);
    }
    await browser.open(url);
    return url;
  }

  Future<void> completeMcpOAuth({required String name, required String code, String? state}) async {
    await remoteSettings.completeMcpOAuth(name: name, code: code);
    if (state != null && state.isNotEmpty) {
      await remoteSettings.clearMcpAuthPending(state);
    }
  }

  Future<void> replyToPermission({
    required HomeSessionRow session,
    required String requestId,
    required String reply,
  }) async {
    final base = activeBase;
    if (base == null) throw const OpenChamberHttpException(0, OpenChamberPaths.permissions, code: 'no_server');
    await _api.replyToPermission(
      base: base,
      bearer: activeBearer,
      requestId: requestId,
      reply: reply,
      directory: session.directory,
    );
  }

  Future<bool> scanAndConnect() async {
    try {
      final raw = await _qrScanner.scan();
      if (raw == null || raw.isEmpty) return false;
      return connect(pairingLink: raw);
    } catch (_) {
      connectErrorKey = 'connect.qr.unavailable';
      notifyListeners();
      return false;
    }
  }

  Future<void> setLocale(Locale next) async {
    locale = next;
    await _store.write(localeStorageKey, next.languageCode == 'zh' ? 'zh-CN' : 'en');
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode next) async {
    themeMode = next;
    await _store.write(themeStorageKey, next.name);
    notifyListeners();
  }

  void setNotificationsEnabled(bool value) {
    notificationsEnabled = value;
    notifyListeners();
    unawaited(_patchNotificationField('nativeNotificationsEnabled', value));
  }

  void setNotifyOnCompletion(bool value) {
    notifyOnCompletion = value;
    notifyListeners();
    unawaited(_patchNotificationField('notifyOnCompletion', value));
  }

  void setNotifyOnError(bool value) {
    notifyOnError = value;
    notifyListeners();
    unawaited(_patchNotificationField('notifyOnError', value));
  }

  void setNotifyOnQuestion(bool value) {
    notifyOnQuestion = value;
    notifyListeners();
    unawaited(_patchNotificationField('notifyOnQuestion', value));
  }

  void setBackgroundPushEnabled(bool value) {
    backgroundPushEnabled = value;
    if (value) {
      unawaited(_registerPush());
    }
    notifyListeners();
  }

  Future<bool> connect({
    String url = '',
    String label = '',
    String clientToken = '',
    String pairingLink = '',
  }) async {
    connectErrorKey = null;
    final pairing = parsePairingLink(pairingLink);
    if (pairingLink.trim().isNotEmpty && pairing == null) {
      connectErrorKey = 'connect.link.invalid';
      notifyListeners();
      return false;
    }

    var resolvedUrl = url.trim();
    String? pairingId;
    var pairingSecret = '';
    var pairingLabel = label;
    PairingConnectionPayload? decoded;
    PairingRelayCandidate? relay;
    if (pairing != null) {
      if (!pairing.isV2) {
        connectErrorKey = 'connect.link.invalid';
        notifyListeners();
        return false;
      }
      decoded = pairing.decoded ?? parsePairingConnectionPayload(pairing.raw);
      if (decoded == null) {
        connectErrorKey = 'connect.link.invalid';
        notifyListeners();
        return false;
      }
      pairingId = decoded.pairingId;
      pairingSecret = decoded.secret;
      relay = decoded.firstRelay;
      pairingLabel = pairingLabel.trim().isEmpty ? (decoded.label ?? pairingLabel) : pairingLabel;
      final direct = decoded.firstDirectUrl;
      if (direct != null) {
        resolvedUrl = direct;
      }
    }

    if (decoded == null && validateServerUrl(resolvedUrl) != null) {
      connectErrorKey = validateServerUrl(resolvedUrl);
      notifyListeners();
      return false;
    }

    connecting = true;
    notifyListeners();
    try {
      final chosen = await _establishLiveTransport(
        directUrl: resolvedUrl.isEmpty ? null : resolvedUrl,
        relay: relay,
      );
      if (chosen == null) {
        connectErrorKey = relay != null && (resolvedUrl.isEmpty || validateServerUrl(resolvedUrl) != null)
            ? 'connect.error.relayTunnelMissing'
            : 'connect.error.unreachable';
        return false;
      }
      _bindTransport(chosen.transport);
      final base = chosen.base;
      final serverId = chosen.serverId ?? relay?.serverId;
      instanceVersion = chosen.openchamberVersion;

      if (decoded != null) {
        final redeem = await _api.redeemPairing(
          base: base,
          pairingId: decoded.pairingId,
          secret: decoded.secret,
          deviceId: await _deviceId(),
          devicePlatform: _devicePlatform,
        );
        if (!redeem.ok || redeem.clientToken == null || redeem.clientToken!.isEmpty) {
          connectErrorKey = 'connect.error.redeemFailed';
          return false;
        }
        return await _activate(
          SavedInstance(
            id: _newId(),
            url: _persistedUrl(redeemUrl: redeem.serverUrl, directUrl: resolvedUrl, relay: relay),
            label: pairingLabel.trim().isEmpty ? (redeem.serverLabel ?? '') : pairingLabel,
            clientToken: redeem.clientToken!,
            relayUrl: relay?.relayUrl,
            pairingId: pairingId,
            serverId: serverId,
            hostEncPubJwk: relay?.hostEncPubJwk,
            grant: relay?.grant,
            lastUsedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }

      final providedToken = clientToken.trim();
      if (providedToken.isNotEmpty) {
        final session = await _api.getAuthSession(base, bearer: providedToken);
        if (!session.authenticated) {
          connectErrorKey = 'connect.error.authRequired';
          return false;
        }
        return await _activate(
          SavedInstance(
            id: _newId(),
            url: _persistedUrl(directUrl: resolvedUrl, relay: relay),
            label: pairingLabel,
            clientToken: providedToken,
            relayUrl: relay?.relayUrl,
            serverId: serverId,
            hostEncPubJwk: relay?.hostEncPubJwk,
            grant: relay?.grant,
            lastUsedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }

      final session = await _api.getAuthSession(base);
      if (session.disabled || session.authenticated) {
        return await _activate(
          SavedInstance(
            id: _newId(),
            url: _persistedUrl(directUrl: resolvedUrl, relay: relay),
            label: pairingLabel,
            relayUrl: relay?.relayUrl,
            serverId: serverId,
            hostEncPubJwk: relay?.hostEncPubJwk,
            grant: relay?.grant,
            lastUsedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }

      pendingUnlock = SavedInstance(
        id: _newId(),
        url: _persistedUrl(directUrl: resolvedUrl, relay: relay),
        label: pairingLabel,
        relayUrl: relay?.relayUrl,
        pairingId: pairingId,
        pairingSecret: pairingSecret,
        needsPassword: true,
        serverId: serverId,
        hostEncPubJwk: relay?.hostEncPubJwk,
        grant: relay?.grant,
      );
      connectForm = ConnectForm.password;
      phase = AppPhase.connect;
      return false;
    } on OpenChamberHttpException catch (error) {
      connectErrorKey = error.code == 'redeem' ? 'connect.error.redeemFailed' : 'connect.error.unreachable';
      return false;
    } catch (_) {
      connectErrorKey = 'connect.error.unreachable';
      return false;
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<bool> unlockWithPassword(String password) async {
    final pending = pendingUnlock;
    if (pending == null) return false;
    if (password.trim().isEmpty) {
      connectErrorKey = 'connect.error.authRequired';
      notifyListeners();
      return false;
    }
    connecting = true;
    notifyListeners();
    try {
      final chosen = await _establishLiveTransport(
        directUrl: isRelayDisplayUrl(pending.url) ? null : pending.url,
        relay: pending.relayCandidate,
      );
      if (chosen == null) {
        connectErrorKey = pending.relayCandidate != null
            ? 'connect.error.relayTunnelMissing'
            : 'connect.error.unreachable';
        return false;
      }
      _bindTransport(chosen.transport);
      final unlocked = await _api.unlockWithPassword(
        base: chosen.base,
        password: password.trim(),
        deviceId: await _deviceId(),
        devicePlatform: _devicePlatform,
      );
      if (!unlocked.authenticated || unlocked.clientToken == null || unlocked.clientToken!.isEmpty) {
        connectErrorKey = 'connect.error.passwordFailed';
        return false;
      }
      return await _activate(pending.copyWith(clientToken: unlocked.clientToken, needsPassword: false));
    } on OpenChamberHttpException {
      connectErrorKey = 'connect.error.passwordFailed';
      return false;
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  void cancelPassword() {
    pendingUnlock = null;
    connectForm = ConnectForm.welcome;
    connectErrorKey = null;
    notifyListeners();
  }

  Future<void> activateExisting(String id) async {
    SavedInstance? match;
    for (final instance in _instances) {
      if (instance.id == id) match = instance;
    }
    if (match == null) return;
    final ok = await _probeAndActivate(match, existing: true);
    if (!ok && match.needsPassword) {
      pendingUnlock = match;
      phase = AppPhase.connect;
      connectForm = ConnectForm.password;
      notifyListeners();
    }
  }

  Future<void> deleteInstance(String id) async {
    SavedInstance? removed;
    for (final item in _instances) {
      if (item.id == id) removed = item;
    }
    final wasActive = _activeId == id;
    _instances = _instances.where((item) => item.id != id).toList();
    if (removed != null) {
      await _store.delete(
        tokenStorageKey(connectionKeyFor(url: removed.url, relayUrl: removed.relayUrl, serverId: removed.serverId)),
      );
    }
    if (wasActive) {
      _activeId = null;
      sessions = const [];
      sessionStatusById = const {};
      _stopLiveEvents();
      _statusPoll?.cancel();
      _visibilityHeartbeat?.cancel();
      _pushBindKey = null;
      lastBoundRelayUrl = null;
      remoteSettings.clear();
      await _dropTunnel();
      phase = AppPhase.connect;
      connectForm = ConnectForm.welcome;
    }
    await _repository.persist(InstanceSnapshot(instances: _instances, activeId: _activeId));
    notifyListeners();
  }

  Future<void> switchToConnect() async {
    phase = AppPhase.connect;
    connectForm = ConnectForm.welcome;
    notifyListeners();
  }

  Future<List<ChatMessage>> loadTranscript(HomeSessionRow session) async {
    final base = activeBase;
    final bearer = activeBearer;
    final directory = session.directory ?? '';
    if (base == null || directory.isEmpty) {
      throw OpenChamberHttpException(0, OpenChamberPaths.sessionMessages(session.id), code: 'not_connected');
    }
    return _api.loadTranscript(base: base, bearer: bearer ?? '', sessionId: session.id, directory: directory);
  }

  Future<void> sendPrompt({
    required HomeSessionRow session,
    required String messageId,
    String text = '',
    List<AttachmentDraft> attachments = const [],
  }) async {
    final base = activeBase;
    final bearer = activeBearer;
    final directory = session.directory ?? '';
    if (base == null) {
      throw OpenChamberHttpException(0, OpenChamberPaths.sessionPromptAsync(session.id), code: 'not_connected');
    }
    final files = <PromptFilePart>[];
    for (final draft in attachments) {
      final uploaded = await uploadPromptAttachmentBytes(
        api: _api,
        base: base,
        bearer: bearer,
        bytes: draft.bytes,
        mime: draft.mime,
        filename: draft.name,
      );
      files.add(PromptFilePart(mime: uploaded.mime, filename: draft.name, url: uploaded.url));
    }
    await _api.promptAsync(
      base: base,
      bearer: bearer ?? '',
      sessionId: session.id,
      directory: directory,
      messageId: messageId,
      text: text,
      files: files,
    );
    liveActivity.selectSession(session.id);
    liveActivity.markWorkStarted();
    _armLiveActivity();
    await refreshSessionStatus(directory: directory);
  }

  Future<void> abortPrompt(HomeSessionRow session) async {
    final base = activeBase;
    final bearer = activeBearer;
    if (base == null) return;
    await _api.abortSession(
      base: base,
      bearer: bearer ?? '',
      sessionId: session.id,
      directory: session.directory ?? '',
    );
    _liveActivityTimer?.cancel();
    _liveActivityTimer = null;
    await liveActivity.complete(error: false);
    await refreshSessionStatus(directory: session.directory);
  }

  Future<void> refreshSessions() async {
    final base = activeBase;
    final bearer = activeBearer;
    if (base == null) return;
    sessionsLoading = true;
    sessionsErrorKey = null;
    notifyListeners();
    try {
      final snapshot = await _api.loadSessionIndex(base, bearer: bearer ?? '');
      if (snapshot == null) {
        sessions = const [];
        lastIndex = null;
        sessionsErrorKey = 'projects.error.indexUnavailable';
        return;
      }
      lastIndex = snapshot;
      await refreshSessionStatus();
      sessions = rowsFromSessionIndex(snapshot, statusById: sessionStatusById);
      await _writeWidgetSnapshot();
    } on OpenChamberHttpException {
      sessionsErrorKey = 'projects.error.indexFailed';
    } finally {
      sessionsLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSessionStatus({String? directory}) async {
    final base = activeBase;
    final bearer = activeBearer;
    if (base == null) return;
    try {
      sessionStatusById = await _api.sessionStatus(base: base, bearer: bearer ?? '', directory: directory);
      sessions = rowsFromSessionIndex(
        SessionIndexSnapshot(
          revision: 0,
          directories: [
            SessionIndexDirectory(
              directory: directory ?? '',
              sessions: sessions
                  .map(
                    (row) => SessionIndexSession(
                      id: row.id,
                      title: row.title,
                      directory: row.directory ?? '',
                      projectLabel: row.projectLabel,
                      branch: row.branch,
                      pinned: row.kind == HomeSessionKind.pinned,
                      unread: row.unread,
                    ),
                  )
                  .toList(),
            ),
          ],
          pinnedSessionIds: sessions.where((row) => row.kind == HomeSessionKind.pinned).map((row) => row.id).toList(),
        ),
        statusById: sessionStatusById,
      );
      _driveLiveActivityFromStatus();
    } on OpenChamberHttpException {
      // Preserve prior status; failure is not empty.
    }
    notifyListeners();
  }

  Future<bool> _probeAndActivate(SavedInstance instance, {required bool existing}) async {
    connecting = true;
    notifyListeners();
    try {
      final chosen = await _establishLiveTransport(
        directUrl: isRelayDisplayUrl(instance.url) ? null : instance.url,
        relay: instance.relayCandidate,
      );
      if (chosen == null) {
        connectErrorKey = instance.relayCandidate != null
            ? 'connect.error.relayTunnelMissing'
            : (normalizeServerBase(instance.url) == null
                ? 'connect.error.invalidUrl'
                : 'connect.error.unreachable');
        return false;
      }
      _bindTransport(chosen.transport);
      final base = chosen.base;
      if (instance.clientToken.isNotEmpty) {
        final session = await _api.getAuthSession(base, bearer: instance.clientToken);
        if (!session.authenticated) {
          connectErrorKey = 'connect.error.authRequired';
          return false;
        }
      } else {
        final session = await _api.getAuthSession(base);
        if (session.needsPassword) {
          pendingUnlock = instance.copyWith(needsPassword: true);
          connectForm = ConnectForm.password;
          phase = AppPhase.connect;
          return false;
        }
        if (!session.disabled && !session.authenticated) {
          connectErrorKey = 'connect.error.authRequired';
          return false;
        }
      }
      return await _activate(instance, existing: existing);
    } on OpenChamberHttpException {
      connectErrorKey = 'connect.error.unreachable';
      return false;
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<bool> _activate(SavedInstance instance, {bool existing = false}) async {
    final stamped = instance.copyWith(lastUsedAt: DateTime.now().millisecondsSinceEpoch);
    if (!existing) {
      _instances = [..._instances.where((item) => item.id != stamped.id), stamped];
    } else {
      _instances = _instances.map((item) => item.id == stamped.id ? stamped : item).toList();
    }
    _activeId = stamped.id;
    pendingUnlock = null;
    await _writeToken(stamped);
    await _repository.persist(InstanceSnapshot(instances: _instances, activeId: _activeId));
    connectForm = ConnectForm.welcome;
    phase = AppPhase.shell;
    if (_useNativeLinks) {
      await _publishShareCatalog();
    }
    await refreshSessions();
    unawaited(_refreshRemoteSettings());
    unawaited(_registerPush());
    _startLiveEvents();
    _startVisibilityHeartbeat();
    notifyListeners();
    return true;
  }

  Future<void> _refreshRemoteSettings() async {
    await remoteSettings.loadBlob();
    final loaded = remoteSettings.blob.value;
    if (loaded == null) return;
    notificationsEnabled = loaded.boolField('nativeNotificationsEnabled') ?? notificationsEnabled;
    notifyOnCompletion = loaded.boolField('notifyOnCompletion') ?? notifyOnCompletion;
    notifyOnError = loaded.boolField('notifyOnError') ?? notifyOnError;
    notifyOnQuestion = loaded.boolField('notifyOnQuestion') ?? notifyOnQuestion;
    notifyListeners();
  }

  Future<void> _patchNotificationField(String key, bool value) async {
    if (!isConnected) return;
    try {
      await remoteSettings.patchBlob({key: value});
    } on OpenChamberHttpException {
      // Keep the local toggle. The settings page shows saveFailed separately.
    }
  }

  Future<void> patchChatSetting(String key, Object? value) async {
    if (!isConnected) return;
    try {
      await remoteSettings.patchBlob({key: value});
    } on OpenChamberHttpException {
      // Preserve the previous blob snapshot; errorKey is set on the resource.
    }
  }

  Future<HomeSessionRow?> createSession({String? title}) async {
    createSessionErrorKey = null;
    final base = activeBase;
    final directory = _preferredCreateDirectory();
    if (base == null || directory == null || directory.isEmpty) {
      createSessionErrorKey = 'projects.newChat.needsServer';
      notifyListeners();
      return null;
    }
    try {
      final created = await _api.createSession(
        base: base,
        bearer: activeBearer ?? '',
        directory: directory,
        title: title,
      );
      await refreshSessions();
      for (final row in sessions) {
        if (row.id == created.id) return row;
      }
      return HomeSessionRow(
        id: created.id,
        title: created.title ?? 'New Session',
        projectLabel: '',
        kind: HomeSessionKind.catalog,
        directory: created.directory ?? directory,
      );
    } on OpenChamberHttpException {
      createSessionErrorKey = 'projects.newChat.failed';
      notifyListeners();
      return null;
    }
  }

  String? _preferredCreateDirectory() {
    final index = lastIndex;
    if (index != null) {
      for (final directory in index.directories) {
        if (directory.directory.isNotEmpty) return directory.directory;
      }
    }
    for (final row in sessions) {
      final directory = row.directory;
      if (directory != null && directory.isNotEmpty) return directory;
    }
    return null;
  }

  void _startStatusPoll() {
    _statusPoll?.cancel();
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    if (liveEventsConnected) return;
    _statusPoll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!isConnected || liveEventsConnected) return;
      unawaited(refreshSessionStatus());
    });
  }

  void _startLiveEvents() {
    _eventSub?.cancel();
    _eventReconnect?.cancel();
    liveEventsConnected = false;
    liveEventTransport = 'none';
    unawaited(_listenEvents());
  }

  void _stopLiveEvents() {
    _eventSub?.cancel();
    _eventSub = null;
    _eventReconnect?.cancel();
    _eventReconnect = null;
    unawaited(_eventSocket?.close());
    _eventSocket = null;
    unawaited(_eventTunnel?.close());
    _eventTunnel = null;
    liveEventsConnected = false;
    liveEventTransport = 'none';
  }

  bool get _preferEventWs {
    if (_api.transport is MemoryOpenChamberTransport) return false;
    final until = _wsFallbackUntil;
    return until == null || !DateTime.now().isBefore(until);
  }

  Future<void> _listenEvents() async {
    final base = activeBase;
    if (base == null) return;
    _eventSub?.cancel();
    unawaited(_eventSocket?.close());
    _eventSocket = null;
    unawaited(_eventTunnel?.close());
    _eventTunnel = null;
    try {
      if (_preferEventWs && await _listenEventWs(base)) return;
      await _listenEventSse(base);
    } catch (_) {
      _onEventStreamLost();
    }
  }

  Future<bool> _listenEventWs(Uri base) async {
    String? token;
    try {
      token = await _api.mintUrlToken(base: base, bearer: activeBearer);
    } on OpenChamberHttpException {
      _wsFallbackUntil = DateTime.now().add(eventWsFallbackWindow);
      return false;
    }
    if (token == null || token.isEmpty) {
      _wsFallbackUntil = DateTime.now().add(eventWsFallbackWindow);
      return false;
    }
    final ready = Completer<void>();
    final transport = _api.transport;
    if (transport is RelayTunnelTransport) {
      final socket = await transport
          .openWebSocket(
            path: OpenChamberPaths.globalEventWs,
            query: encodeTunnelQuery({
              'oc_url_token': token,
              if (_lastEventId != null && _lastEventId!.isNotEmpty) 'lastEventId': _lastEventId!,
            }),
          )
          .timeout(eventWsReadyTimeoutRelay);
      _eventTunnel = socket;
      _eventSub = socket.messages.listen(
        (text) => _onEventWsText(text, ready),
        onError: (_) => _onEventStreamLost(),
        onDone: _onEventStreamLost,
      );
    } else {
      final uri = globalEventWebSocketUri(base, urlToken: token, lastEventId: _lastEventId);
      final socket = await WebSocket.connect(uri.toString()).timeout(eventWsReadyTimeoutLan);
      _eventSocket = socket;
      _eventSub = socket.listen(
        (data) {
          if (data is String) _onEventWsText(data, ready);
        },
        onError: (_) => _onEventStreamLost(),
        onDone: _onEventStreamLost,
      );
    }
    try {
      await ready.future.timeout(
        transport is RelayTunnelTransport ? eventWsReadyTimeoutRelay : eventWsReadyTimeoutLan,
      );
    } catch (_) {
      _wsFallbackUntil = DateTime.now().add(eventWsFallbackWindow);
      await _eventSocket?.close();
      _eventSocket = null;
      await _eventTunnel?.close();
      _eventTunnel = null;
      await _eventSub?.cancel();
      _eventSub = null;
      return false;
    }
    liveEventsConnected = true;
    liveEventTransport = 'ws';
    _eventFailures = 0;
    _statusPoll?.cancel();
    notifyListeners();
    return true;
  }

  void _onEventWsText(String raw, Completer<void> ready) {
    final frame = parseEventWsFrame(raw);
    switch (frame.kind) {
      case EventWsFrameKind.ready:
        if (!ready.isCompleted) ready.complete();
      case EventWsFrameKind.event:
        if (frame.eventId != null && frame.eventId!.isNotEmpty) _lastEventId = frame.eventId;
        _handleLiveEvent(sseEventFromWsFrame(frame));
      case EventWsFrameKind.backpressure:
        break;
      case EventWsFrameKind.error:
      case EventWsFrameKind.invalid:
        if (!ready.isCompleted) {
          ready.completeError(StateError(frame.message ?? 'event-ws-invalid'));
        } else {
          _onEventStreamLost();
        }
    }
  }

  Future<void> _listenEventSse(Uri base) async {
    liveEventsConnected = true;
    liveEventTransport = 'sse';
    _eventFailures = 0;
    _statusPoll?.cancel();
    notifyListeners();
    _eventSub = parseSse(
      _api.openGlobalEventStream(base: base, bearer: activeBearer ?? '', lastEventId: _lastEventId),
    ).listen(
      (event) {
        if (event.id != null && event.id!.isNotEmpty) _lastEventId = event.id;
        _handleLiveEvent(event);
      },
      onError: (_) => _onEventStreamLost(),
      onDone: _onEventStreamLost,
    );
  }

  void _onEventStreamLost() {
    liveEventsConnected = false;
    notifyListeners();
    _startStatusPoll();
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    _scheduleEventReconnect();
  }

  void _handleLiveEvent(SseEvent event) {
    final payload = decodeSseJson(event.data);
    final type = event.event ?? eventTypeOf(payload);
    if (type == null) return;
    if (type == 'session.status' || type == 'session.idle' || type == 'session.error') {
      unawaited(refreshSessionStatus());
    } else if (type == 'session.created' || type == 'session.updated' || type == 'session.deleted') {
      unawaited(refreshSessions());
    } else if (type.startsWith('message.')) {
      transcriptEpoch += 1;
      notifyListeners();
    }
  }

  void _scheduleEventReconnect() {
    if (!isConnected) return;
    _eventFailures += 1;
    final exponent = _eventFailures > 8 ? 8 : _eventFailures;
    var delay = Duration(milliseconds: 250 * (1 << (exponent - 1)));
    if (delay > const Duration(seconds: 5)) delay = const Duration(seconds: 5);
    _eventReconnect = Timer(delay, () {
      if (isConnected) unawaited(_listenEvents());
    });
  }

  Future<_LiveTransport?> _establishLiveTransport({
    String? directUrl,
    PairingRelayCandidate? relay,
  }) async {
    final trimmed = directUrl?.trim();
    if (trimmed != null && trimmed.isNotEmpty && validateServerUrl(trimmed) == null) {
      final base = normalizeServerBase(trimmed);
      if (base != null) {
        try {
          final health = await OpenChamberApi(transport: _directTransport).health(base);
          if (relay == null || health.serverId == null || health.serverId == relay.serverId) {
            return _LiveTransport(
              transport: _directTransport,
              base: base,
              serverId: health.serverId,
              openchamberVersion: health.openchamberVersion,
            );
          }
        } on OpenChamberHttpException {
          // Fall through to relay.
        }
      }
    }
    if (relay != null) {
      try {
        final tunnel = await _openRelayTunnel(relay);
        final dummy = RelayTunnelTransport.dummyBase;
        final health = await OpenChamberApi(transport: tunnel).health(dummy);
        return _LiveTransport(
          transport: tunnel,
          base: dummy,
          serverId: health.serverId ?? relay.serverId,
          openchamberVersion: health.openchamberVersion,
        );
      } catch (_) {
        try {
          // Leave an honest failure — do not keep a half-open tunnel.
        } catch (_) {}
      }
    }
    return null;
  }

  void _bindTransport(OpenChamberTransport next) {
    if (!identical(next, _api.transport) && _api.transport is RelayTunnelTransport) {
      unawaited(_api.transport.close());
    }
    _api.transport = next;
  }

  Future<void> _dropTunnel() async {
    if (_api.transport is RelayTunnelTransport) {
      await _api.transport.close();
    }
    _api.transport = _directTransport;
  }

  String _persistedUrl({String? redeemUrl, required String directUrl, PairingRelayCandidate? relay}) {
    final redeem = redeemUrl?.trim() ?? '';
    if (redeem.isNotEmpty && validateServerUrl(redeem) == null) return redeem;
    if (directUrl.isNotEmpty && validateServerUrl(directUrl) == null) return directUrl;
    if (relay != null) return relayDisplayUrl(relay.serverId);
    return directUrl;
  }

  void _armLiveActivity() {
    if (_liveActivityTimer?.isActive == true) return;
    _liveActivityTimer = Timer(liveActivityBusyDelay, () async {
      await liveActivity.startIfDue();
    });
  }

  void _driveLiveActivityFromStatus() {
    final selected = liveActivity.selectedSessionId;
    if (selected == null) return;
    final status = sessionStatusById[selected];
    if (status == 'busy' || status == 'retry') {
      final already = liveActivity.hasWorkStarted;
      liveActivity.markWorkStarted();
      if (!already) _armLiveActivity();
    } else if (status == 'idle') {
      _liveActivityTimer?.cancel();
      _liveActivityTimer = null;
      unawaited(liveActivity.complete(error: false));
    }
  }

  void setAppVisible(bool visible) {
    _appVisible = visible;
    unawaited(_sendVisibility(visible));
  }

  void _startVisibilityHeartbeat() {
    _visibilityHeartbeat?.cancel();
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    _visibilityHeartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_appVisible && isConnected) unawaited(_sendVisibility(true));
    });
  }

  Future<void> _sendVisibility(bool visible) async {
    final base = activeBase;
    final bearer = activeBearer;
    if (base == null || bearer == null || bearer.isEmpty) return;
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    try {
      await _api.setVisibility(
        base: base,
        bearer: bearer,
        visible: visible,
        platform: _devicePlatform,
      );
    } on OpenChamberHttpException {
      // Host presence TTL is best-effort.
    }
  }

  Future<void> _registerPush() async {
    if (!notificationsEnabled && !backgroundPushEnabled) return;
    final base = activeBase;
    final bearer = activeBearer;
    if (base == null || bearer == null || bearer.isEmpty) return;
    final bindKey = '${activeInstance?.id}|${activeInstance?.relayUrl ?? ''}';
    final device = await _push.requestToken();
    try {
      if (device != null && _pushBindKey != bindKey) {
        await _api.registerPushToken(
          base: base,
          bearer: bearer,
          token: device.token,
          platform: device.platform,
          locale: locale.languageCode,
        );
        _pushBindKey = bindKey;
        lastBoundRelayUrl = activeInstance?.relayUrl;
      }
      await _sendVisibility(_appVisible);
    } on OpenChamberHttpException {
      // Presence/token bind is best-effort; do not drop the session.
    }
  }

  Future<void> loadAssistantSnapshot() async {
    final previous = assistantSnapshot;
    assistantSnapshot = SettingsResource(value: previous.value, loading: true);
    notifyListeners();
    final base = activeBase;
    if (base == null) {
      assistantSnapshot = SettingsResource(value: previous.value, errorKey: 'settings.error.needsServer');
      notifyListeners();
      return;
    }
    try {
      final payload = await _api.getAssistantsSnapshot(base: base, bearer: activeBearer);
      assistantSnapshot = SettingsResource(value: parseAssistantSnapshotView(payload));
    } on OpenChamberHttpException {
      assistantSnapshot = SettingsResource(value: previous.value, errorKey: 'settings.error.loadFailed');
    }
    notifyListeners();
  }

  Future<void> setAssistantsFeatureEnabled(bool enabled) async {
    final current = assistantSnapshot.value;
    final base = activeBase;
    if (base == null || current == null) {
      throw const OpenChamberHttpException(0, OpenChamberPaths.assistantsSettings, code: 'not_connected');
    }
    await _api.putAssistantsSettings(
      base: base,
      bearer: activeBearer,
      enabled: enabled,
      expectedRevision: current.revision,
    );
    await loadAssistantSnapshot();
  }

  Future<HomeSessionRow?> openAssistant(AssistantRecord assistant) async {
    final bound = assistant.boundSession;
    if (bound != null) return bound;
    final base = activeBase;
    if (base == null) {
      throw const OpenChamberHttpException(0, OpenChamberPaths.assistants, code: 'not_connected');
    }
    final binding = parseSessionBinding(
      await _api.newAssistantSession(base: base, bearer: activeBearer, assistantId: assistant.id),
    );
    if (binding == null) return null;
    return HomeSessionRow(
      id: binding.id,
      title: assistant.name,
      projectLabel: assistant.name,
      kind: HomeSessionKind.catalog,
      directory: binding.directory ?? assistant.workspacePath,
    );
  }

  Future<void> loadScheduledTasks() async {
    final previous = scheduledTasks;
    scheduledTasks = SettingsResource(value: previous.value, loading: true);
    notifyListeners();
    final base = activeBase;
    if (base == null) {
      scheduledTasks = SettingsResource(value: previous.value, errorKey: 'settings.error.needsServer');
      notifyListeners();
      return;
    }
    try {
      final payload = await _api.getScheduledTasks(base: base, bearer: activeBearer);
      scheduledTasks = SettingsResource(value: parseScheduledTasks(payload));
      scheduledFailedProjectIds = parseFailedScheduledProjectIds(payload);
    } on OpenChamberHttpException {
      scheduledTasks = SettingsResource(value: previous.value, errorKey: 'settings.error.loadFailed');
    }
    notifyListeners();
  }

  Future<void> runScheduledTaskNow({required String projectId, required String taskId}) async {
    final previous = scheduledTasks.value;
    if (previous != null) {
      scheduledTasks = SettingsResource(
        value: previous
            .map((task) => task.projectId == projectId && task.id == taskId ? task.copyWith(lastStatus: 'running') : task)
            .toList(),
      );
      notifyListeners();
    }
    final base = activeBase;
    if (base == null) {
      scheduledTasks = SettingsResource(value: previous, errorKey: 'settings.error.needsServer');
      notifyListeners();
      return;
    }
    try {
      await _api.runScheduledTaskNow(
        base: base,
        bearer: activeBearer,
        projectId: projectId,
        taskId: taskId,
      );
      await loadScheduledTasks();
      await loadScheduledRuns(projectId: projectId, taskId: taskId);
    } on OpenChamberHttpException {
      scheduledTasks = SettingsResource(value: previous, errorKey: 'settings.error.saveFailed');
      notifyListeners();
    }
  }

  Future<void> loadScheduledRuns({required String projectId, required String taskId}) async {
    scheduledFilterProjectId = projectId;
    scheduledFilterTaskId = taskId;
    final previous = scheduledRuns;
    scheduledRuns = SettingsResource(value: previous.value, loading: true);
    notifyListeners();
    final base = activeBase;
    if (base == null) {
      scheduledRuns = SettingsResource(value: previous.value, errorKey: 'settings.error.needsServer');
      notifyListeners();
      return;
    }
    try {
      final payload = await _api.getScheduledTaskRuns(
        base: base,
        bearer: activeBearer,
        projectId: projectId,
        taskId: taskId,
      );
      scheduledRuns = SettingsResource(value: parseScheduledRuns(payload));
    } on OpenChamberHttpException {
      scheduledRuns = SettingsResource(value: previous.value, errorKey: 'settings.error.loadFailed');
    }
    notifyListeners();
  }

  Future<void> _writeWidgetSnapshot() async {
    final snapshot = buildWidgetSnapshot(sessions);
    if (!_useNativeLinks) return;
    try {
      const channel = MethodChannel(OpenChamberChannels.widgetSnapshot);
      await channel.invokeMethod<void>('write', snapshot.encode()).timeout(const Duration(milliseconds: 80));
      await channel.invokeMethod<void>('setBadge', {'count': snapshot.attentionCount}).timeout(const Duration(milliseconds: 80));
    } catch (_) {}
  }

  Future<void> _publishShareCatalog() async {
    final targets = _instances
        .where((item) => item.id.isNotEmpty)
        .map(
          (item) => ShareTarget(
            serverInstanceId: item.id,
            assistantId: item.id,
            name: item.displayLabel,
          ),
        )
        .toList();
    try {
      const channel = MethodChannel(OpenChamberChannels.share);
      await channel
          .invokeMethod<void>(
            'updateCatalog',
            targets
                .map(
                  (target) => {
                    'serverInstanceID': target.serverInstanceId,
                    'assistantID': target.assistantId,
                    'name': target.name,
                    'enabled': true,
                  },
                )
                .toList(),
          )
          .timeout(const Duration(milliseconds: 80));
    } catch (_) {}
  }

  Future<void> speakMessage(String text) async {
    final base = activeBase;
    if (base == null || text.trim().isEmpty) {
      throw const OpenChamberHttpException(0, OpenChamberPaths.ttsSpeak, code: 'no_text');
    }
    final bytes = await _api.speakTts(base: base, bearer: activeBearer, text: text);
    if (bytes.isEmpty) {
      throw const OpenChamberHttpException(0, OpenChamberPaths.ttsSpeak);
    }
    try {
      await TtsPlayback().play(bytes);
    } on MissingPluginException {
      // Widget tests and Linux have no audio device. The HTTP speak still happened.
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await TtsPlayback().stop();
    } on MissingPluginException {
      // Widget tests and Linux have no audio plugin.
    }
  }

  SavedInstance? _mostRecentInstance() {
    if (_instances.isEmpty) return null;
    if (_activeId != null) {
      for (final item in _instances) {
        if (item.id == _activeId) return item;
      }
    }
    final sorted = [..._instances]..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return sorted.first;
  }

  Future<List<SavedInstance>> _hydrateTokens(List<SavedInstance> items) async {
    final out = <SavedInstance>[];
    for (final item in items) {
      if (item.clientToken.isNotEmpty) {
        await _writeToken(item);
        out.add(item);
        continue;
      }
      final token = await _store.read(
        tokenStorageKey(connectionKeyFor(url: item.url, relayUrl: item.relayUrl, serverId: item.serverId)),
      );
      out.add(item.copyWith(clientToken: token ?? ''));
    }
    return out;
  }

  Future<void> _writeToken(SavedInstance instance) async {
    final key = tokenStorageKey(connectionKeyFor(url: instance.url, relayUrl: instance.relayUrl, serverId: instance.serverId));
    if (instance.clientToken.isEmpty) {
      await _store.delete(key);
      return;
    }
    await _store.write(key, instance.clientToken);
  }

  Future<String> _deviceId() async {
    final existing = await _store.read(deviceIdStorageKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = 'dev-${DateTime.now().microsecondsSinceEpoch}';
    await _store.write(deviceIdStorageKey, id);
    return id;
  }

  static OpenChamberTransport _defaultTransport() {
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      return MemoryOpenChamberTransport();
    }
    return LiveOpenChamberTransport();
  }

  static Future<OpenChamberTransport> _defaultOpenRelay(PairingRelayCandidate relay) {
    return openRelayTunnel(relay);
  }

  static String get _devicePlatform {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return 'ios';
  }

  static bool get _useNativeLinks => Platform.environment['FLUTTER_TEST'] != 'true';

  String _newId() => 'inst-${DateTime.now().microsecondsSinceEpoch}';

  static Locale _localeFromCode(String? code) {
    if (code == 'zh-CN' || code == 'zh') return AppStrings.zhCN;
    return AppStrings.en;
  }

  static ThemeMode _themeFromCode(String? code) {
    switch (code) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  void dispose() {
    _stopLiveEvents();
    _statusPoll?.cancel();
    _liveActivityTimer?.cancel();
    _visibilityHeartbeat?.cancel();
    unawaited(_dropTunnel());
    super.dispose();
  }
}

class _LiveTransport {
  const _LiveTransport({
    required this.transport,
    required this.base,
    this.serverId,
    this.openchamberVersion,
  });

  final OpenChamberTransport transport;
  final Uri base;
  final String? serverId;
  final String? openchamberVersion;
}
