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
import '../native/share_inbox.dart';
import '../native/share_targeting.dart';
import 'share_delivery.dart';
import 'event_pipeline.dart';
import 'oauth.dart';
import 'assistant_scheduled.dart';
import 'chat_timeline.dart';
import 'connection_candidates.dart';
import 'context_usage.dart';
import 'composer_autocomplete.dart';
import 'github_worktree.dart';
import 'home_session.dart';
import 'project_id.dart';
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

enum ActiveTransportKind { direct, relay }

enum ReprobeOutcome { switched, unchanged, unreachable, noConnection }

class AppController extends ChangeNotifier {
  AppController({
    required SecureStore store,
    InstanceSnapshot? seed,
    QrScanner? qrScanner,
    DeepLinkListener? deepLinks,
    OpenChamberApi? api,
    NativePush? push,
    ShareInbox? shareInbox,
    OpenRelayTunnel? openRelayTunnel,
    ExternalBrowser? browser,
    Duration? relayRaceHeadstart,
    this.relayRaceWait,
  })  : _store = store,
        _qrScanner = qrScanner ?? QrScanner(),
        _deepLinks = deepLinks ?? DeepLinkListener(),
        _api = api ?? OpenChamberApi(transport: _defaultTransport()),
        _push = push ?? NativePush(),
        _shareInbox = shareInbox ?? (_inFlutterTest ? MemoryShareInbox() : ShareInbox()),
        browser = browser ?? ExternalBrowser(),
        _instances = seed?.instances ?? const [],
        _activeId = seed?.activeId,
        relayRaceHeadstart = relayRaceHeadstart ?? const Duration(milliseconds: 1500) {
    _directTransport = _api.transport;
    _openRelayTunnel = openRelayTunnel ?? _defaultOpenRelay;
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
  final ShareInbox _shareInbox;
  final ExternalBrowser browser;
  OAuthCallback? pendingOAuthCallback;
  late final OpenChamberTransport _directTransport;
  late final OpenRelayTunnel _openRelayTunnel;
  late final InstanceRepository _repository = InstanceRepository(_store);
  final Duration relayRaceHeadstart;
  final Future<void> Function(Duration duration)? relayRaceWait;
  bool _candidateRefreshInFlight = false;

  AppPhase phase = AppPhase.splash;
  ConnectForm connectForm = ConnectForm.welcome;
  Locale locale = AppStrings.en;
  ThemeMode themeMode = ThemeMode.system;
  List<SavedInstance> _instances;
  String? _activeId;
  SavedInstance? pendingUnlock;
  String? connectErrorKey;
  bool connecting = false;
  ActiveTransportKind? activeTransportKind;
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
  String? lastMutationErrorKey;
  Map<String, List<String>> worktreeOrderByDirectory = {};
  Map<String, int> worktreeOrderRevisionByDirectory = {};
  Map<String, num> contextLimits = const {};
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

  /// Official `mobile.instances.status.connectedDirect` / `connectedRelay`.
  String? get activeConnectionStatusKey {
    if (!isConnected) return null;
    return activeTransportKind == ActiveTransportKind.relay
        ? 'mobile.instances.status.connectedRelay'
        : 'mobile.instances.status.connectedDirect';
  }

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
      _push.listenOpened(handleIncomingLink);
    }
    _shareInbox.listen(() {
      unawaited(drainShares());
    });
    if (!skipDelay) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    String? initial;
    String? openedPush;
    if (_useNativeLinks) {
      initial = await _deepLinks.takeInitial();
      openedPush = await _push.takeInitialOpen();
    }
    if (initial != null && initial.isNotEmpty) {
      await handleIncomingLink(initial);
      if (phase == AppPhase.shell) {
        notifyListeners();
        return;
      }
    }
    if (openedPush != null && openedPush.isNotEmpty && openedPush != initial) {
      await handleIncomingLink(openedPush);
      if (phase == AppPhase.shell) {
        notifyListeners();
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
    if (link.kind == DeepLinkKind.shareInbox) {
      await drainShares();
      return;
    }
    pendingDeepLink = link;
    notifyListeners();
  }

  IncomingDeepLink? pendingDeepLink;
  NativeShareDraft? pendingShareDraft;
  List<ShareTarget> shareCatalog = const [];
  bool shareRecipientBusy = false;
  bool _shareDrainInFlight = false;
  final LiveActivityController liveActivity = LiveActivityController();
  late final ShareDelivery _shareDelivery = ShareDelivery(
    connect: _connectForShare,
    loadCapability: _loadAssistantCapability,
    loadSnapshot: ({bool force = false}) async {
      if (force || assistantSnapshot.value == null) {
        await loadAssistantSnapshot();
      }
      return assistantSnapshot.value;
    },
    sendShare: ({
      required String assistantID,
      required String operationID,
      required String messageID,
      required List<AssistantSharePart> parts,
      required String source,
    }) async {
      final base = activeBase;
      if (base == null) throw const OpenChamberHttpException(0, OpenChamberPaths.assistants, code: 'not_connected');
      return parseShareOperation(
        await _api.sendAssistantShare(
          base: base,
          bearer: activeBearer,
          assistantId: assistantID,
          operationID: operationID,
          messageID: messageID,
          parts: parts.map((part) => part.toJson()).toList(),
          source: source,
        ),
      );
    },
    fetchShareOperation: (operationID) async {
      final base = activeBase;
      if (base == null) throw const OpenChamberHttpException(0, OpenChamberPaths.assistants, code: 'not_connected');
      return parseShareOperation(
        await _api.getAssistantShareOperation(base: base, bearer: activeBearer, operationID: operationID),
      );
    },
    ack: _shareInbox.ack,
    releaseFiles: _shareInbox.releaseFiles,
  );

  String? pendingSettingsSlug;

  void requestSettingsSlug(String slug) {
    pendingSettingsSlug = slug;
    notifyListeners();
  }

  String? takePendingSettingsSlug() {
    final slug = pendingSettingsSlug;
    pendingSettingsSlug = null;
    return slug;
  }

  IncomingDeepLink? takePendingSessionDeepLink() {
    final link = pendingDeepLink;
    if (link == null || link.kind != DeepLinkKind.session) return null;
    pendingDeepLink = null;
    return link;
  }

  HomeSessionRow sessionRowForId(String sessionId) {
    for (final row in sessions) {
      if (row.id == sessionId) return row;
    }
    return HomeSessionRow(
      id: sessionId,
      title: '',
      projectLabel: '',
      kind: HomeSessionKind.catalog,
    );
  }

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

    final resolvedUrl = url.trim();
    String? pairingId;
    var pairingSecret = '';
    var pairingLabel = label;
    PairingConnectionPayload? decoded;
    var candidates = <TransportCandidate>[];
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
      pairingLabel = pairingLabel.trim().isEmpty ? (decoded.label ?? pairingLabel) : pairingLabel;
      candidates = pairingCandidatesToMobile(decoded.candidates);
    } else {
      final error = validateServerUrl(resolvedUrl);
      if (error != null) {
        connectErrorKey = error;
        notifyListeners();
        return false;
      }
      final normalized = normalizeConnectionUrl(resolvedUrl) ?? resolvedUrl;
      candidates = [DirectTransportCandidate(url: normalized)];
    }

    if (candidates.isEmpty) {
      connectErrorKey = 'connect.error.invalidUrl';
      notifyListeners();
      return false;
    }

    connecting = true;
    notifyListeners();
    try {
      if (decoded != null) {
        final chosen = await _establishLiveTransport(candidates);
        if (chosen == null) {
          connectErrorKey = relayCandidateOf(candidates) != null && directCandidatesOf(candidates).isEmpty
              ? 'connect.error.relayTunnelMissing'
              : 'connect.error.unreachable';
          return false;
        }
        _bindTransport(chosen.transport);
        instanceVersion = chosen.openchamberVersion;
        final redeem = await _api.redeemPairing(
          base: chosen.base,
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
          _instanceFromCandidates(
            id: _newId(),
            candidates: candidates,
            label: pairingLabel.trim().isEmpty ? (redeem.serverLabel ?? '') : pairingLabel,
            clientToken: redeem.clientToken!,
            pairingId: pairingId,
            serverId: chosen.serverId,
          ),
          kind: chosen.kind,
        );
      }

      final providedToken = clientToken.trim();
      final probed = await _probeCandidates(
        candidates,
        token: providedToken.isEmpty ? null : providedToken,
      );
      if (probed.status == ProbeStatus.needsLogin) {
        pendingUnlock = _instanceFromCandidates(
          id: _newId(),
          candidates: candidates,
          label: pairingLabel,
          pairingId: pairingId,
          pairingSecret: pairingSecret,
          needsPassword: true,
        );
        connectForm = ConnectForm.password;
        phase = AppPhase.connect;
        return false;
      }
      if (probed.status != ProbeStatus.ok || probed.value == null) {
        connectErrorKey = relayCandidateOf(candidates) != null && directCandidatesOf(candidates).isEmpty
            ? 'connect.error.relayTunnelMissing'
            : 'connect.error.unreachable';
        return false;
      }
      _bindTransport(probed.value!.transport);
      instanceVersion = probed.value!.openchamberVersion;
      return await _activate(
        _instanceFromCandidates(
          id: _newId(),
          candidates: candidates,
          label: pairingLabel,
          clientToken: providedToken,
          serverId: probed.value!.serverId,
        ),
        kind: probed.value!.kind,
      );
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
      final chosen = await _establishLiveTransport(pending.transportCandidates);
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
      return await _activate(
        pending.copyWith(clientToken: unlocked.clientToken, needsPassword: false),
        kind: chosen.kind,
      );
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

  Future<String> readWorkspaceFile(String path) async {
    final base = activeBase;
    if (base == null) {
      throw const OpenChamberHttpException(0, OpenChamberPaths.fsRead, code: 'not_connected');
    }
    return _api.readFile(base: base, bearer: activeBearer ?? '', path: path);
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
      final previousShare = {
        for (final row in sessions)
          if (row.isShared) row.id: row.shareUrl!,
      };
      sessions = [
        for (final row in rowsFromSessionIndex(snapshot, statusById: sessionStatusById))
          row.copyWith(shareUrl: row.shareUrl ?? previousShare[row.id]),
      ];
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
                      shareUrl: row.shareUrl,
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
      final probed = await _probeCandidates(
        instance.transportCandidates,
        token: instance.clientToken.isEmpty ? null : instance.clientToken,
      );
      if (probed.status == ProbeStatus.needsLogin) {
        pendingUnlock = instance.copyWith(needsPassword: true);
        connectForm = ConnectForm.password;
        phase = AppPhase.connect;
        return false;
      }
      if (probed.status == ProbeStatus.unreachable || probed.value == null) {
        connectErrorKey = instance.relayCandidate != null
            ? 'connect.error.relayTunnelMissing'
            : (normalizeServerBase(instance.url) == null
                ? 'connect.error.invalidUrl'
                : 'connect.error.unreachable');
        return false;
      }
      _bindTransport(probed.value!.transport);
      instanceVersion = probed.value!.openchamberVersion;
      return await _activate(instance, existing: existing, kind: probed.value!.kind);
    } on OpenChamberHttpException {
      connectErrorKey = 'connect.error.unreachable';
      return false;
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<bool> _activate(SavedInstance instance, {bool existing = false, required ActiveTransportKind kind}) async {
    activeTransportKind = kind;
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
    await loadAssistantSnapshot();
    await publishShareCatalog();
    await drainShares();
    await refreshSessions();
    unawaited(_refreshRemoteSettings());
    unawaited(_registerPush());
    _startLiveEvents();
    _startVisibilityHeartbeat();
    if (!_inFlutterTest) _scheduleCandidateRefresh();
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

  Future<HomeSessionRow?> createSession({String? title, String? directory}) async {
    createSessionErrorKey = null;
    final base = activeBase;
    final target = (directory != null && directory.isNotEmpty) ? directory : _preferredCreateDirectory();
    if (base == null || target == null || target.isEmpty) {
      createSessionErrorKey = 'projects.newChat.needsServer';
      notifyListeners();
      return null;
    }
    try {
      final created = await _api.createSession(
        base: base,
        bearer: activeBearer ?? '',
        directory: target,
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
        directory: created.directory ?? target,
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

  HomeSessionRow? sessionById(String id) {
    for (final row in sessions) {
      if (row.id == id) return row;
    }
    return null;
  }

  Future<bool> renameSession(HomeSessionRow session, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      lastMutationErrorKey = 'sessions.sidebar.session.rename.error';
      notifyListeners();
      return false;
    }
    return _mutateSession(
      session,
      errorKey: 'sessions.sidebar.session.rename.error',
      optimistic: () {
        sessions = [
          for (final row in sessions)
            if (row.id == session.id) row.copyWith(title: trimmed) else row,
        ];
      },
      run: (base) => _api.updateSession(
        base: base,
        bearer: activeBearer ?? '',
        sessionId: session.id,
        directory: session.directory,
        title: trimmed,
      ),
    );
  }

  Future<bool> toggleSessionPin(HomeSessionRow session) async {
    final pinning = session.kind != HomeSessionKind.pinned;
    return _mutateSession(
      session,
      errorKey: 'sessions.sidebar.session.pin.error',
      optimistic: () {
        sessions = [
          for (final row in sessions)
            if (row.id == session.id)
              row.copyWith(kind: pinning ? HomeSessionKind.pinned : HomeSessionKind.catalog)
            else
              row,
        ];
      },
      run: (base) async {
        if (pinning) {
          await _api.pinSession(base: base, bearer: activeBearer ?? '', sessionId: session.id);
        } else {
          await _api.unpinSession(base: base, bearer: activeBearer ?? '', sessionId: session.id);
        }
      },
    );
  }

  Future<bool> archiveSession(HomeSessionRow session) {
    return _mutateSession(
      session,
      errorKey: 'sessions.sidebar.session.archive.error',
      optimistic: () {
        sessions = sessions.where((row) => row.id != session.id).toList();
      },
      run: (base) => _api.updateSession(
        base: base,
        bearer: activeBearer ?? '',
        sessionId: session.id,
        directory: session.directory,
        archivedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<bool> shareSession(HomeSessionRow session) async {
    return _mutateSession(
      session,
      errorKey: 'sessions.sidebar.session.share.error',
      optimistic: () {},
      run: (base) async {
        final body = await _api.shareSession(
          base: base,
          bearer: activeBearer ?? '',
          sessionId: session.id,
          directory: session.directory,
        );
        final url = parseSessionShareUrl(body);
        if (url == null || url.isEmpty) {
          throw OpenChamberHttpException(200, OpenChamberPaths.sessionShare(session.id), code: 'missing_share_url');
        }
        sessions = [
          for (final row in sessions)
            if (row.id == session.id) row.copyWith(shareUrl: url) else row,
        ];
      },
    );
  }

  Future<bool> unshareSession(HomeSessionRow session) {
    return _mutateSession(
      session,
      errorKey: 'sessions.sidebar.session.unshare.error',
      optimistic: () {
        sessions = [
          for (final row in sessions)
            if (row.id == session.id) row.copyWith(clearShareUrl: true) else row,
        ];
      },
      run: (base) => _api.unshareSession(
        base: base,
        bearer: activeBearer ?? '',
        sessionId: session.id,
        directory: session.directory,
      ),
    );
  }

  /// Hydrate official `share.url` from GET `/api/session/:id` when the index omitted it.
  Future<HomeSessionRow> hydrateSessionShare(HomeSessionRow session) async {
    if (session.isShared) return session;
    final base = activeBase;
    if (base == null) return session;
    try {
      final body = await _api.getSession(
        base: base,
        bearer: activeBearer ?? '',
        sessionId: session.id,
        directory: session.directory,
      );
      final url = parseSessionShareUrl(body);
      if (url == null) return session;
      final next = session.copyWith(shareUrl: url);
      sessions = [
        for (final row in sessions)
          if (row.id == session.id) next else row,
      ];
      notifyListeners();
      return next;
    } on OpenChamberHttpException {
      return session;
    }
  }

  Future<bool> deleteSession(HomeSessionRow session) {
    return _mutateSession(
      session,
      errorKey: 'sessions.sidebar.session.delete.error',
      optimistic: () {
        sessions = sessions.where((row) => row.id != session.id).toList();
      },
      run: (base) => _api.deleteSession(
        base: base,
        bearer: activeBearer ?? '',
        sessionId: session.id,
        directory: session.directory,
      ),
    );
  }

  Future<bool> _mutateSession(
    HomeSessionRow session, {
    required String errorKey,
    required VoidCallback optimistic,
    required Future<void> Function(Uri base) run,
  }) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'projects.newChat.needsServer';
      notifyListeners();
      return false;
    }
    final previous = sessions;
    optimistic();
    notifyListeners();
    try {
      await run(base);
    } on OpenChamberHttpException {
      sessions = previous;
      lastMutationErrorKey = errorKey;
      notifyListeners();
      return false;
    }
    try {
      await refreshSessions();
    } on OpenChamberHttpException {
      // Keep the optimistic list; refresh failure is not empty success.
    }
    return lastMutationErrorKey == null;
  }

  Future<bool> addProject({required String path, String? label}) async {
    lastMutationErrorKey = null;
    if (!isConnected) {
      lastMutationErrorKey = 'projects.newProject.needsServer';
      notifyListeners();
      return false;
    }
    final entry = buildProjectEntry(path: path, label: label);
    if ((entry['path']?.toString() ?? '').isEmpty || (entry['id']?.toString() ?? '').isEmpty) {
      lastMutationErrorKey = 'projects.newProject.invalidPath';
      notifyListeners();
      return false;
    }
    try {
      if (remoteSettings.blob.value == null) {
        await remoteSettings.loadBlob();
      }
      if (remoteSettings.blob.value == null && remoteSettings.blob.errorKey != null) {
        lastMutationErrorKey = remoteSettings.blob.errorKey;
        notifyListeners();
        return false;
      }
      final current = remoteSettings.blob.value?.projectRecords ?? const <Map<String, Object?>>[];
      await remoteSettings.patchBlob({'projects': mergeProjectEntry(current, entry)});
      lastMutationErrorKey = null;
      notifyListeners();
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'chat.mobileStatus.toast.addProjectFailed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> editProjectLabel({required String projectId, required String label}) {
    return editProjectMeta(projectId: projectId, label: label);
  }

  Future<bool> editProjectMeta({
    required String projectId,
    String? label,
    String? icon,
    String? color,
    bool clearIcon = false,
    bool clearColor = false,
  }) async {
    lastMutationErrorKey = null;
    if (!isConnected) {
      lastMutationErrorKey = 'projects.newProject.needsServer';
      notifyListeners();
      return false;
    }
    try {
      if (remoteSettings.blob.value == null) await remoteSettings.loadBlob();
      final current = remoteSettings.blob.value?.projectRecords ?? const <Map<String, Object?>>[];
      final next = current.map((item) {
        if (item['id']?.toString() != projectId) return item;
        final updated = Map<String, Object?>.from(item);
        if (label != null) updated['label'] = label.trim();
        if (clearIcon) {
          updated.remove('icon');
        } else if (icon != null) {
          updated['icon'] = icon;
        }
        if (clearColor) {
          updated.remove('color');
        } else if (color != null) {
          updated['color'] = color;
        }
        return updated;
      }).toList();
      await remoteSettings.patchBlob({'projects': next});
      notifyListeners();
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'sessions.sidebar.project.actions.editFailed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> discoverProjectIcon(String projectId) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'projects.newProject.needsServer';
      notifyListeners();
      return false;
    }
    try {
      await _api.discoverProjectIcon(base: base, bearer: activeBearer, projectId: projectId);
      await remoteSettings.loadBlob();
      notifyListeners();
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'projectEditDialog.toast.failedToDiscoverIcon';
      notifyListeners();
      return false;
    }
  }

  Future<bool> createAndAddProject({required String path, String? label}) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'projects.newProject.needsServer';
      notifyListeners();
      return false;
    }
    try {
      final created = await _api.createDirectory(base: base, bearer: activeBearer, path: path);
      return addProject(path: created, label: label);
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'directoryExplorerDialog.toast.failedToSelectDirectory';
      notifyListeners();
      return false;
    }
  }

  Future<bool> githubAuthConnected() async {
    final base = activeBase;
    if (base == null) return false;
    try {
      return await _api.githubAuthConnected(base: base, bearer: activeBearer);
    } on OpenChamberHttpException {
      return false;
    }
  }

  Future<List<GitHubWorktreeItem>> listGithubItems({
    required String directory,
    required String kind,
  }) async {
    final base = activeBase;
    if (base == null) return const [];
    try {
      final body = kind == 'pr'
          ? await _api.listGithubPulls(base: base, bearer: activeBearer, directory: directory)
          : await _api.listGithubIssues(base: base, bearer: activeBearer, directory: directory);
      if (body['connected'] == false) return const [];
      return kind == 'pr' ? parseGitHubPulls(body) : parseGitHubIssues(body);
    } on OpenChamberHttpException {
      return const [];
    }
  }

  Future<bool> setWorktreeOrder({
    required String projectDirectory,
    required List<String> orderedPaths,
  }) async {
    lastMutationErrorKey = null;
    final directory = normalizeProjectDirectory(projectDirectory);
    worktreeOrderByDirectory = {
      ...worktreeOrderByDirectory,
      directory: orderedPaths.map(normalizeProjectDirectory).toList(),
    };
    notifyListeners();
    final base = activeBase;
    if (base == null) return true;
    try {
      final result = await _api.putWorktreeOrder(
        base: base,
        bearer: activeBearer,
        requestId: 'wt-order-${DateTime.now().microsecondsSinceEpoch}',
        projectDirectory: directory,
        expectedRevision: worktreeOrderRevisionByDirectory[directory] ?? 0,
        orderedPaths: worktreeOrderByDirectory[directory] ?? orderedPaths,
      );
      final revision = result['revision'];
      if (revision is num) {
        worktreeOrderRevisionByDirectory = {
          ...worktreeOrderRevisionByDirectory,
          directory: revision.toInt(),
        };
      }
      return true;
    } on OpenChamberHttpException catch (error) {
      if (error.status == 501) return true;
      lastMutationErrorKey = 'mobile.projectEdit.worktreeOrderFailed';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadWorktreeOrder(String projectDirectory) async {
    final base = activeBase;
    if (base == null) return;
    final directory = normalizeProjectDirectory(projectDirectory);
    try {
      final body = await _api.fetchWorktreeOrder(
        base: base,
        bearer: activeBearer,
        projectDirectory: directory,
      );
      final raw = body['orderedPaths'];
      final paths = raw is List ? raw.map((item) => normalizeProjectDirectory(item.toString())).toList() : const <String>[];
      final revision = body['revision'];
      worktreeOrderByDirectory = {...worktreeOrderByDirectory, directory: paths};
      if (revision is num) {
        worktreeOrderRevisionByDirectory = {
          ...worktreeOrderRevisionByDirectory,
          directory: revision.toInt(),
        };
      }
      notifyListeners();
    } on OpenChamberHttpException {
      // 501 / missing queue is local-only order, not empty success wipe.
    }
  }

  Future<bool> createScheduledTask({
    required String projectId,
    required String name,
    required String prompt,
    String scheduleKind = 'daily',
    String scheduleTime = '09:00',
    String? taskId,
    bool enabled = true,
    List<int>? weekdays,
    String? cron,
  }) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'settings.error.needsServer';
      notifyListeners();
      return false;
    }
    final model = splitDefaultModel(remoteSettings.blob.value?.defaultModel);
    final schedule = <String, Object?>{'kind': scheduleKind};
    if (scheduleKind == 'cron') {
      schedule['cron'] = (cron ?? scheduleTime).trim();
    } else {
      schedule['time'] = scheduleTime;
      if (scheduleKind == 'weekly' && weekdays != null && weekdays.isNotEmpty) {
        schedule['weekdays'] = weekdays;
      }
    }
    try {
      await _api.upsertScheduledTask(
        base: base,
        bearer: activeBearer,
        projectId: projectId,
        task: {
          if (taskId != null && taskId.isNotEmpty) 'id': taskId,
          'name': name.trim(),
          'enabled': enabled,
          'schedule': schedule,
          'execution': {
            'prompt': prompt.trim(),
            'providerID': model.providerId,
            'modelID': model.modelId,
          },
        },
      );
      await loadScheduledTasks();
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'scheduled.create.failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleScheduledTask({
    required ScheduledTaskRecord task,
    required bool enabled,
  }) {
    return createScheduledTask(
      projectId: task.projectId,
      taskId: task.id,
      name: task.name,
      prompt: task.prompt ?? '',
      scheduleKind: task.scheduleKind ?? 'daily',
      scheduleTime: task.scheduleTime ?? '09:00',
      weekdays: task.weekdays,
      cron: task.scheduleKind == 'cron' ? task.scheduleTime : null,
      enabled: enabled,
    );
  }

  Future<bool> deleteScheduledTask({required String projectId, required String taskId}) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'settings.error.needsServer';
      notifyListeners();
      return false;
    }
    try {
      await _api.deleteScheduledTask(
        base: base,
        bearer: activeBearer,
        projectId: projectId,
        taskId: taskId,
      );
      await loadScheduledTasks();
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'scheduled.delete.failed';
      notifyListeners();
      return false;
    }
  }

  Future<HomeSessionRow?> forkSession({
    required HomeSessionRow session,
    String? messageId,
  }) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'projects.newChat.needsServer';
      notifyListeners();
      return null;
    }
    try {
      final body = await _api.forkSession(
        base: base,
        bearer: activeBearer,
        sessionId: session.id,
        messageId: messageId,
        directory: session.directory,
      );
      await refreshSessions();
      final id = body['id']?.toString() ?? '';
      if (id.isEmpty) return null;
      return sessionById(id) ??
          HomeSessionRow(
            id: id,
            title: body['title']?.toString() ?? session.title,
            projectLabel: session.projectLabel,
            kind: HomeSessionKind.catalog,
            directory: body['directory']?.toString() ?? session.directory,
          );
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'chat.messageBody.actions.forkFailed';
      notifyListeners();
      return null;
    }
  }

  Future<bool> revertSession({
    required HomeSessionRow session,
    required String messageId,
  }) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'projects.newChat.needsServer';
      notifyListeners();
      return false;
    }
    try {
      await _api.revertSession(
        base: base,
        bearer: activeBearer,
        sessionId: session.id,
        messageId: messageId,
        directory: session.directory,
      );
      await refreshSessions();
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'chat.messageBody.actions.revertFailed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAssistantRecord(AssistantRecord assistant) async {
    lastMutationErrorKey = null;
    try {
      await remoteSettings.deleteAssistant(id: assistant.id, expectedRevision: assistant.revision);
      await loadAssistantSnapshot();
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'assistants.settings.deleteFailed';
      notifyListeners();
      return false;
    }
  }

  Future<List<ComposerAutocompleteItem>> composerSuggestions({
    required String text,
    String? directory,
  }) async {
    final trigger = resolveComposerTrigger(text);
    if (trigger == null) return const [];
    final base = activeBase;
    if (base == null) {
      return filterComposerSuggestions(text, commands: const [], files: const [], skills: const [], snippets: const []);
    }
    try {
      switch (trigger.kind) {
        case ComposerTriggerKind.command:
          final catalog = await _api.getCommandCatalog(base: base, bearer: activeBearer);
          return filterComposerSuggestions(
            text,
            commands: parseCommandNames(catalog),
            files: const [],
            skills: const [],
          );
        case ComposerTriggerKind.mention:
          final listed = await _api.listFilesystem(
            base: base,
            bearer: activeBearer,
            path: directory ?? '/',
          );
          final files = listed
              .where((entry) => entry.type != 'directory')
              .map((entry) => entry.name.isNotEmpty ? entry.name : entry.path)
              .toList();
          return filterComposerSuggestions(text, commands: const [], files: files, skills: const []);
        case ComposerTriggerKind.skill:
          final skills = await _api.getInstalledSkills(base: base, bearer: activeBearer);
          return filterComposerSuggestions(text, commands: const [], files: const [], skills: parseSkillNames(skills));
        case ComposerTriggerKind.snippet:
          final snippets = await _api.getSnippets(base: base, bearer: activeBearer);
          return filterComposerSuggestions(
            text,
            commands: const [],
            files: const [],
            skills: const [],
            snippets: parseSnippetNames(snippets),
          );
      }
    } on OpenChamberHttpException {
      return const [];
    }
  }

  Future<bool> cloneAndAddProject({
    required String remoteUrl,
    required String destinationPath,
    String? gitIdentityId,
    String? label,
  }) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'projects.newProject.needsServer';
      notifyListeners();
      return false;
    }
    final remote = remoteUrl.trim();
    if (remote.isEmpty) {
      lastMutationErrorKey = 'directoryExplorerDialog.toast.cloneUrlRequired';
      notifyListeners();
      return false;
    }
    try {
      final path = await _api.cloneRepository(
        base: base,
        bearer: activeBearer,
        remoteUrl: remote,
        destinationPath: destinationPath,
        gitIdentityId: gitIdentityId,
      );
      return addProject(path: path, label: label);
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'directoryExplorerDialog.toast.failedToAddProject';
      notifyListeners();
      return false;
    }
  }

  Future<List<SettingsNamedItem>> gitIdentities() async {
    if (remoteSettings.gitIdentities.value != null) {
      return remoteSettings.gitIdentities.value!;
    }
    try {
      await remoteSettings.loadGitIdentities();
    } on OpenChamberHttpException {
      return const [];
    }
    return remoteSettings.gitIdentities.value ?? const [];
  }

  Future<bool> closeProject(String projectId) async {
    lastMutationErrorKey = null;
    if (!isConnected) {
      lastMutationErrorKey = 'projects.newProject.needsServer';
      notifyListeners();
      return false;
    }
    try {
      if (remoteSettings.blob.value == null) await remoteSettings.loadBlob();
      final current = remoteSettings.blob.value?.projectRecords ?? const <Map<String, Object?>>[];
      await remoteSettings.patchBlob({'projects': removeProjectEntry(current, projectId)});
      notifyListeners();
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'sessions.sidebar.project.actions.closeFailed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> syncProjectSessions() async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'projects.newChat.needsServer';
      notifyListeners();
      return false;
    }
    try {
      final directories = lastIndex?.directories.map((item) => item.directory).where((item) => item.isNotEmpty).toList() ??
          [_preferredCreateDirectory()].whereType<String>().toList();
      await _api.startSessionIndexSync(base, bearer: activeBearer ?? '', directories: directories);
      await refreshSessions();
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'sessions.sidebar.project.actions.syncFailed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> isGitRepository(String directory) async {
    final base = activeBase;
    if (base == null || directory.isEmpty) return false;
    try {
      return await _api.checkIsGitRepository(base: base, bearer: activeBearer, directory: directory);
    } on OpenChamberHttpException {
      return false;
    }
  }

  Future<List<String>> listGitBranches(String directory) async {
    final base = activeBase;
    if (base == null) return const [];
    try {
      return await _api.listGitBranches(base: base, bearer: activeBearer, directory: directory);
    } on OpenChamberHttpException {
      return const [];
    }
  }

  Future<bool> createWorktree({
    required String directory,
    required String worktreeName,
    String? branchName,
    String? startRef,
    String mode = 'new',
    String? existingBranch,
  }) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'projects.newChat.needsServer';
      notifyListeners();
      return false;
    }
    try {
      await _api.createGitWorktree(
        base: base,
        bearer: activeBearer,
        directory: directory,
        worktreeName: worktreeName,
        branchName: branchName,
        startRef: startRef,
        mode: mode,
        existingBranch: existingBranch,
      );
      await refreshSessions();
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'sessions.sidebar.project.actions.worktreeCreateFailed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteWorktree({required String projectDirectory, required String worktreePath}) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'projects.newChat.needsServer';
      notifyListeners();
      return false;
    }
    final linked = sessions.where((row) => normalizeProjectDirectory(row.directory ?? '') == normalizeProjectDirectory(worktreePath)).toList();
    for (final session in linked) {
      final archived = await archiveSession(session);
      if (!archived) {
        lastMutationErrorKey ??= 'sessions.sidebar.session.archive.error';
        notifyListeners();
        return false;
      }
    }
    try {
      await _api.deleteGitWorktree(
        base: base,
        bearer: activeBearer,
        directory: projectDirectory,
        worktreePath: worktreePath,
      );
      await refreshSessions();
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'sessions.sidebar.project.actions.worktreeDeleteFailed';
      notifyListeners();
      return false;
    }
  }

  Future<void> ensureContextLimits() async {
    final base = activeBase;
    if (base == null) return;
    try {
      final catalog = await _api.getProviderCatalog(base: base, bearer: activeBearer);
      contextLimits = parseProviderContextLimits(catalog);
    } on OpenChamberHttpException {
      // Keep the previous map; unknown limits hide the percentage instead of inventing 0 as authoritative empty.
    }
    notifyListeners();
  }

  List<Map<String, Object?>> settingsProjectRecords() {
    return remoteSettings.blob.value?.projectRecords ?? const [];
  }

  Future<String> filesystemHome() {
    final base = activeBase;
    if (base == null) {
      throw const OpenChamberHttpException(0, OpenChamberPaths.fsHome, code: 'not_connected');
    }
    return _api.getFilesystemHome(base: base, bearer: activeBearer);
  }

  Future<List<FilesystemEntry>> listFilesystem(String path) {
    final base = activeBase;
    if (base == null) {
      throw const OpenChamberHttpException(0, OpenChamberPaths.fsList, code: 'not_connected');
    }
    return _api.listFilesystem(base: base, bearer: activeBearer, path: path);
  }

  Future<GitStatusSnapshot> loadGitStatus(String directory) {
    final base = activeBase;
    if (base == null) {
      throw const OpenChamberHttpException(0, OpenChamberPaths.gitStatus, code: 'not_connected');
    }
    return _api.getGitStatus(base: base, bearer: activeBearer, directory: directory);
  }

  Future<bool> stageGitPaths(String directory, List<String> paths) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'mobile.changes.error.stageFailed';
      notifyListeners();
      return false;
    }
    try {
      await _api.stageGitPaths(base: base, bearer: activeBearer, directory: directory, paths: paths);
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'mobile.changes.error.stageFailed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unstageGitPaths(String directory, List<String> paths) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'mobile.changes.error.unstageFailed';
      notifyListeners();
      return false;
    }
    try {
      await _api.unstageGitPaths(base: base, bearer: activeBearer, directory: directory, paths: paths);
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'mobile.changes.error.unstageFailed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> commitGitChanges(String directory, String message) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null || message.trim().isEmpty) {
      lastMutationErrorKey = 'mobile.changes.error.commitFailed';
      notifyListeners();
      return false;
    }
    try {
      await _api.createGitCommit(
        base: base,
        bearer: activeBearer,
        directory: directory,
        message: message.trim(),
      );
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = 'mobile.changes.error.commitFailed';
      notifyListeners();
      return false;
    }
  }

  Future<String> loadGitDiff({
    required String directory,
    required String path,
    bool staged = false,
  }) {
    final base = activeBase;
    if (base == null) {
      throw const OpenChamberHttpException(0, OpenChamberPaths.gitDiff, code: 'not_connected');
    }
    return _api.getGitDiff(
      base: base,
      bearer: activeBearer,
      directory: directory,
      path: path,
      staged: staged,
    );
  }

  Future<Map<String, McpRuntimeStatus>> loadMcpRuntimeStatus() {
    final base = activeBase;
    if (base == null) {
      throw const OpenChamberHttpException(0, OpenChamberPaths.mcpRuntime, code: 'not_connected');
    }
    return _api.getMcpRuntimeStatus(base: base, bearer: activeBearer);
  }

  Future<bool> setMcpRuntimeConnected({
    required String name,
    required bool connected,
    String? directory,
  }) async {
    lastMutationErrorKey = null;
    final base = activeBase;
    if (base == null) {
      lastMutationErrorKey = 'mcpDropdown.error.connectFailed';
      notifyListeners();
      return false;
    }
    try {
      if (connected) {
        await _api.connectMcpRuntime(
          base: base,
          bearer: activeBearer,
          name: name,
          directory: directory,
        );
      } else {
        await _api.disconnectMcpRuntime(
          base: base,
          bearer: activeBearer,
          name: name,
          directory: directory,
        );
      }
      return true;
    } on OpenChamberHttpException {
      lastMutationErrorKey = connected
          ? 'mcpDropdown.error.connectFailed'
          : 'mcpDropdown.error.disconnectFailed';
      notifyListeners();
      return false;
    }
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

  SavedInstance _instanceFromCandidates({
    required String id,
    required List<TransportCandidate> candidates,
    String label = '',
    String clientToken = '',
    String? pairingId,
    String pairingSecret = '',
    bool needsPassword = false,
    String? serverId,
  }) {
    final relay = relayCandidateOf(candidates)?.relay;
    return SavedInstance(
      id: id,
      url: connectionDisplayUrl(candidates),
      candidates: candidates,
      label: label,
      clientToken: clientToken,
      relayUrl: relay?.relayUrl,
      pairingId: pairingId,
      pairingSecret: pairingSecret,
      needsPassword: needsPassword,
      serverId: serverId ?? relay?.serverId,
      hostEncPubJwk: relay?.hostEncPubJwk,
      grant: relay?.grant,
      lastUsedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<_LiveTransport?> _establishLiveTransport(List<TransportCandidate> candidates) async {
    final result = await _raceCandidates(
      candidates,
      probeDirect: (direct) => _probeDirectHealth(direct, expectedServerId: relayCandidateOf(candidates)?.relay.serverId),
      probeRelay: _probeRelayHealth,
    );
    return result.status == ProbeStatus.ok ? result.value : null;
  }

  Future<CandidateProbeOutcome<_LiveTransport>> _probeCandidates(
    List<TransportCandidate> candidates, {
    String? token,
  }) {
    return _raceCandidates(
      candidates,
      probeDirect: (direct) => _probeDirectSession(
        direct,
        token: token,
        expectedServerId: relayCandidateOf(candidates)?.relay.serverId,
      ),
      probeRelay: (relay) => _probeRelaySession(relay, token: token),
    );
  }

  Future<CandidateProbeOutcome<_LiveTransport>> _raceCandidates(
    List<TransportCandidate> candidates, {
    required Future<CandidateProbeOutcome<_LiveTransport>> Function(DirectTransportCandidate) probeDirect,
    required Future<CandidateProbeOutcome<_LiveTransport>> Function(RelayTransportCandidate) probeRelay,
  }) {
    final directs = directCandidatesOf(candidates);
    final relay = relayCandidateOf(candidates);
    return probeConnectionCandidates<_LiveTransport>(
      hasDirect: directs.isNotEmpty,
      hasRelay: relay != null,
      probeDirects: () async {
        for (final direct in directs) {
          final result = await probeDirect(direct);
          if (result.status == ProbeStatus.ok || result.status == ProbeStatus.needsLogin) {
            return result;
          }
        }
        return CandidateProbeOutcome.unreachable<_LiveTransport>();
      },
      probeRelay: () async {
        if (relay == null) return CandidateProbeOutcome.unreachable<_LiveTransport>();
        return await probeRelay(relay);
      },
      headstart: relayRaceHeadstart,
      wait: relayRaceWait ?? Future<void>.delayed,
    );
  }

  Future<CandidateProbeOutcome<_LiveTransport>> _probeDirectHealth(
    DirectTransportCandidate direct, {
    String? expectedServerId,
  }) async {
    final live = await _healthDirect(direct, expectedServerId: expectedServerId);
    if (live == null) return CandidateProbeOutcome.unreachable();
    return CandidateProbeOutcome.ok(live);
  }

  Future<CandidateProbeOutcome<_LiveTransport>> _probeDirectSession(
    DirectTransportCandidate direct, {
    String? token,
    String? expectedServerId,
  }) async {
    final live = await _healthDirect(direct, expectedServerId: expectedServerId);
    if (live == null) return CandidateProbeOutcome.unreachable();
    try {
      final session = await OpenChamberApi(transport: _directTransport).getAuthSession(live.base, bearer: token);
      if (token != null && !session.authenticated) return CandidateProbeOutcome.needsLogin();
      if (session.needsPassword) return CandidateProbeOutcome.needsLogin();
      if (token == null && !session.disabled && !session.authenticated) {
        return CandidateProbeOutcome.needsLogin();
      }
      return CandidateProbeOutcome.ok(live);
    } on OpenChamberHttpException {
      return CandidateProbeOutcome.unreachable();
    }
  }

  Future<_LiveTransport?> _healthDirect(
    DirectTransportCandidate direct, {
    String? expectedServerId,
  }) async {
    final url = normalizeConnectionUrl(direct.url) ?? direct.url;
    if (validateServerUrl(url) != null) return null;
    final base = normalizeServerBase(url);
    if (base == null) return null;
    try {
      final health = await OpenChamberApi(transport: _directTransport).health(base);
      if (expectedServerId != null && health.serverId != null && health.serverId != expectedServerId) {
        return null;
      }
      return _LiveTransport(
        kind: ActiveTransportKind.direct,
        transport: _directTransport,
        base: base,
        serverId: health.serverId,
        openchamberVersion: health.openchamberVersion,
      );
    } on OpenChamberHttpException {
      return null;
    }
  }

  Future<CandidateProbeOutcome<_LiveTransport>> _probeRelayHealth(RelayTransportCandidate candidate) async {
    try {
      final tunnel = await _openRelayTunnel(candidate.relay);
      try {
        final health = await OpenChamberApi(transport: tunnel).health(RelayTunnelTransport.dummyBase);
        return CandidateProbeOutcome.ok(
          _LiveTransport(
            kind: ActiveTransportKind.relay,
            transport: tunnel,
            base: RelayTunnelTransport.dummyBase,
            serverId: health.serverId ?? candidate.relay.serverId,
            openchamberVersion: health.openchamberVersion,
          ),
          discard: () => unawaited(tunnel.close()),
        );
      } catch (_) {
        await tunnel.close();
        return CandidateProbeOutcome.unreachable();
      }
    } catch (_) {
      return CandidateProbeOutcome.unreachable();
    }
  }

  Future<CandidateProbeOutcome<_LiveTransport>> _probeRelaySession(
    RelayTransportCandidate candidate, {
    String? token,
  }) async {
    try {
      final tunnel = await _openRelayTunnel(candidate.relay);
      try {
        final api = OpenChamberApi(transport: tunnel);
        final health = await api.health(RelayTunnelTransport.dummyBase);
        final session = await api.getAuthSession(RelayTunnelTransport.dummyBase, bearer: token);
        if (token != null && !session.authenticated) {
          await tunnel.close();
          return CandidateProbeOutcome.needsLogin();
        }
        if (session.needsPassword || (token == null && !session.disabled && !session.authenticated)) {
          await tunnel.close();
          return CandidateProbeOutcome.needsLogin();
        }
        return CandidateProbeOutcome.ok(
          _LiveTransport(
            kind: ActiveTransportKind.relay,
            transport: tunnel,
            base: RelayTunnelTransport.dummyBase,
            serverId: health.serverId ?? candidate.relay.serverId,
            openchamberVersion: health.openchamberVersion,
          ),
          discard: () => unawaited(tunnel.close()),
        );
      } catch (_) {
        await tunnel.close();
        return CandidateProbeOutcome.unreachable();
      }
    } catch (_) {
      return CandidateProbeOutcome.unreachable();
    }
  }

  void _scheduleCandidateRefresh() {
    Timer(candidateRefreshDelay, () {
      unawaited((() async {
        final result = await refreshActiveConnectionCandidates();
        if (result == CandidateRefreshResult.updated && activeTransportKind == ActiveTransportKind.relay) {
          await reprobeActiveConnection();
        }
      })());
    });
  }

  /// Learn current LAN addresses over the live transport. Failure is skip —
  /// never an authoritative empty wipe. Empty LAN list is also skip.
  Future<CandidateRefreshResult> refreshActiveConnectionCandidates() async {
    if (_candidateRefreshInFlight) return CandidateRefreshResult.skipped;
    final active = activeInstance;
    if (active == null) return CandidateRefreshResult.skipped;
    final relay = relayCandidateOf(active.transportCandidates);
    if (relay == null) return CandidateRefreshResult.skipped;
    final base = activeBase;
    if (base == null) return CandidateRefreshResult.skipped;
    _candidateRefreshInFlight = true;
    try {
      final payload = await _api.loadConnectionCandidates(base, bearer: activeBearer);
      if (payload == null) return CandidateRefreshResult.skipped;
      if (payload['serverId'] != relay.relay.serverId) return CandidateRefreshResult.skipped;
      final lanUrls = lanUrlsFromCandidatesPayload(payload['candidates']);
      final next = mergeRefreshedLanCandidates(current: active.transportCandidates, lanUrls: lanUrls);
      if (next == null) return CandidateRefreshResult.skipped;
      if (candidatesEqual(active.transportCandidates, next)) return CandidateRefreshResult.unchanged;
      final updated = active.withCandidates(next);
      _instances = _instances.map((item) => item.id == updated.id ? updated : item).toList();
      await _repository.persist(InstanceSnapshot(instances: _instances, activeId: _activeId));
      notifyListeners();
      return CandidateRefreshResult.updated;
    } finally {
      _candidateRefreshInFlight = false;
    }
  }

  /// Home/away hot-switch. Higher-priority LAN winning means "came home";
  /// a dead current transport falls through to relay.
  Future<ReprobeOutcome> reprobeActiveConnection() async {
    final active = activeInstance;
    if (active == null) return ReprobeOutcome.noConnection;
    final token = active.clientToken.isEmpty ? null : active.clientToken;
    if (token == null) return ReprobeOutcome.unreachable;
    final candidates = active.transportCandidates;
    final currentIndex = candidates.indexWhere(_matchesCurrentRuntime);

    final higher = currentIndex >= 0 ? candidates.sublist(0, currentIndex) : candidates;
    if (higher.isNotEmpty) {
      final better = await _probeCandidates(higher, token: token);
      if (better.status == ProbeStatus.ok && better.value != null) {
        _bindTransport(better.value!.transport);
        await _activate(active, existing: true, kind: better.value!.kind);
        return ReprobeOutcome.switched;
      }
      if (better.status == ProbeStatus.needsLogin) return ReprobeOutcome.unreachable;
    }

    if (currentIndex >= 0) {
      final stillValid = await _validateActiveSession(token);
      if (stillValid) return ReprobeOutcome.unchanged;
    }

    final lower = currentIndex >= 0 ? candidates.sublist(currentIndex + 1) : const <TransportCandidate>[];
    if (lower.isNotEmpty) {
      final fallback = await _probeCandidates(lower, token: token);
      if (fallback.status == ProbeStatus.ok && fallback.value != null) {
        _bindTransport(fallback.value!.transport);
        await _activate(active, existing: true, kind: fallback.value!.kind);
        return ReprobeOutcome.switched;
      }
    }
    return ReprobeOutcome.unreachable;
  }

  bool _matchesCurrentRuntime(TransportCandidate candidate) {
    if (candidate is RelayTransportCandidate) return _api.transport is RelayTunnelTransport;
    if (candidate is DirectTransportCandidate) {
      if (_api.transport is RelayTunnelTransport) return false;
      final base = activeBase;
      if (base == null) return false;
      return isSameConnectionUrl(candidate.url, base.toString());
    }
    return false;
  }

  Future<bool> _validateActiveSession(String token) async {
    final base = activeBase;
    if (base == null) return false;
    try {
      final session = await _api.getAuthSession(base, bearer: token);
      return session.authenticated || session.disabled;
    } on OpenChamberHttpException {
      return _api.transport is RelayTunnelTransport;
    }
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

  void _armLiveActivity() {
    if (_liveActivityTimer?.isActive == true) return;
    _liveActivityTimer = Timer(liveActivityBusyDelay, () async {
      await liveActivity.startIfDue();
    });
  }

  void _driveLiveActivityFromStatus() {
    final catalog = buildLiveActivityCatalog(
      statusById: sessionStatusById,
      sessions: sessions,
      now: DateTime.now,
    );
    liveActivity.applyCatalog(catalog);
    if (catalog.isEmpty) {
      _liveActivityTimer?.cancel();
      _liveActivityTimer = null;
      if (liveActivity.started) {
        unawaited(liveActivity.complete(error: false));
      }
      return;
    }
    final already = liveActivity.hasWorkStarted;
    liveActivity.markWorkStarted();
    if (liveActivity.started) {
      unawaited(liveActivity.update(catalog.first.status));
    } else if (!already) {
      _armLiveActivity();
    }
  }

  void setAppVisible(bool visible) {
    final becameVisible = visible && !_appVisible;
    _appVisible = visible;
    unawaited(_sendVisibility(visible));
    if (becameVisible && isConnected) {
      unawaited(drainShares());
      if (!_inFlutterTest) unawaited(reprobeActiveConnection());
    }
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

  Future<AssistantCapability?> _loadAssistantCapability() async {
    final base = activeBase;
    if (base == null) return null;
    try {
      return parseAssistantCapability(await _api.getAssistantsCapability(base: base, bearer: activeBearer));
    } on OpenChamberHttpException {
      return null;
    }
  }

  Future<bool> _connectForShare(String serverInstanceID) async {
    if (serverInstanceID.isEmpty) return false;
    if (isConnected) {
      final capability = await _loadAssistantCapability();
      if (capability?.serverInstanceID == serverInstanceID) return true;
    }
    SavedInstance? match;
    for (final item in _instances) {
      if (item.serverId == serverInstanceID) {
        match = item;
        break;
      }
    }
    if (match == null) return false;
    if (activeInstance?.id == match.id && isConnected) return true;
    return _probeAndActivate(match, existing: true);
  }

  Future<void> publishShareCatalog() async {
    final instance = activeInstance;
    if (instance == null || !isConnected) {
      shareCatalog = const [];
      return;
    }
    final capability = await _loadAssistantCapability();
    final serverInstanceID = capability?.serverInstanceID?.trim() ?? '';
    if (capability == null || !capability.supported || serverInstanceID.isEmpty) {
      shareCatalog = const [];
      return;
    }
    if (instance.serverId == null || instance.serverId!.isEmpty) {
      _instances = [
        for (final item in _instances)
          if (item.id == instance.id) item.copyWith(serverId: serverInstanceID) else item,
      ];
      await _repository.persist(InstanceSnapshot(instances: _instances, activeId: _activeId));
    }
    var snapshot = assistantSnapshot.value;
    if (snapshot == null) {
      await loadAssistantSnapshot();
      snapshot = assistantSnapshot.value;
    }
    if (snapshot == null) {
      shareCatalog = const [];
      return;
    }
    final targets = shareCatalogFromSnapshot(
      serverInstanceID: serverInstanceID,
      connectionKey: connectionKeyFor(url: instance.url, relayUrl: instance.relayUrl, serverId: serverInstanceID),
      serverLabel: instance.displayLabel,
      featureEnabled: capability.enabled && snapshot.enabled,
      assistants: snapshot.assistants,
    );
    shareCatalog = targets;
    await _shareInbox.updateCatalog(targets);
  }

  Future<void> drainShares() async {
    if (_shareDrainInFlight) return;
    _shareDrainInFlight = true;
    try {
      await publishShareCatalog();
      final pending = await _shareInbox.listPending();
      final drafts = await _shareInbox.listDrafts();
      final assigned = [for (final draft in drafts) if (draft.isAssigned) draft];
      final unassigned = [for (final draft in drafts) if (!draft.isAssigned) draft];
      final envelopes = <String, NativeShareEnvelope>{
        for (final envelope in pending) envelope.operationID: envelope,
        for (final draft in assigned) draft.draftID: envelopeFromAssignedDraft(draft),
      };
      await drainShareItems(
        [
          for (final envelope in pending) ShareDrainItem(operationID: envelope.operationID),
          for (final draft in assigned) ShareDrainItem(operationID: draft.draftID),
        ],
        deliver: (operationID) async {
          final envelope = envelopes[operationID];
          if (envelope == null) return;
          final result = await _shareDelivery.deliverOne(envelope);
          if (assigned.any((draft) => draft.draftID == operationID)) {
            await _shareInbox.cancelDraft(operationID);
          }
          if (result.state == ShareDeliveryState.delivered && result.sessionID != null && result.sessionID!.isNotEmpty) {
            pendingDeepLink = classifyDeepLink(liveActivityRowUri(result.sessionID!).toString());
            notifyListeners();
          }
        },
        cleanup: (operationID) async {
          final item = _shareDelivery.outbox[operationID];
          if (item != null) await _shareDelivery.cleanupNativeDelivery(item);
        },
      );
      final nextDraft = unassigned.isEmpty ? null : unassigned.first;
      if (pendingShareDraft?.draftID != nextDraft?.draftID) {
        pendingShareDraft = nextDraft;
        notifyListeners();
      }
    } finally {
      _shareDrainInFlight = false;
    }
  }

  Future<void> assignShareRecipient({required NativeShareDraft draft, required ShareTarget target}) async {
    if (shareRecipientBusy) return;
    shareRecipientBusy = true;
    notifyListeners();
    try {
      final result = await _shareDelivery.deliverOne(
        NativeShareEnvelope(
          operationID: draft.draftID,
          serverInstanceID: target.serverInstanceId,
          assistantID: target.assistantId,
          text: draft.text,
          attachments: draft.attachments,
          source: draft.source,
          createdAt: draft.createdAt,
          expiresAt: draft.expiresAt,
        ),
      );
      await _shareInbox.cancelDraft(draft.draftID);
      if (pendingShareDraft?.draftID == draft.draftID) pendingShareDraft = null;
      if (result.state == ShareDeliveryState.delivered && result.sessionID != null && result.sessionID!.isNotEmpty) {
        pendingDeepLink = classifyDeepLink(liveActivityRowUri(result.sessionID!).toString());
      }
    } finally {
      shareRecipientBusy = false;
      notifyListeners();
    }
  }

  Future<void> cancelShareRecipient(NativeShareDraft draft) async {
    await _shareInbox.cancelDraft(draft.draftID);
    if (pendingShareDraft?.draftID == draft.draftID) pendingShareDraft = null;
    notifyListeners();
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

  static bool get _inFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';

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
    required this.kind,
    required this.transport,
    required this.base,
    this.serverId,
    this.openchamberVersion,
  });

  final ActiveTransportKind kind;
  final OpenChamberTransport transport;
  final Uri base;
  final String? serverId;
  final String? openchamberVersion;
}
