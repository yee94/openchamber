import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../native/deep_link.dart';
import '../native/live_activity_controller.dart';
import '../native/platform_channels.dart';
import '../native/push_registration.dart';
import '../native/qr_scanner.dart';
import '../native/share_targeting.dart';
import 'chat_timeline.dart';
import 'home_session.dart';
import 'instance_store.dart';
import 'openchamber_api.dart';
import 'openchamber_http.dart';
import 'pairing_payload.dart';
import 'secure_store.dart';
import 'session_index.dart';
import 'widget_snapshot.dart';

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
  })  : _store = store,
        _qrScanner = qrScanner ?? QrScanner(),
        _deepLinks = deepLinks ?? DeepLinkListener(),
        _api = api ?? OpenChamberApi(transport: _defaultTransport()),
        _push = push ?? NativePush(),
        _instances = seed?.instances ?? const [],
        _activeId = seed?.activeId;

  final SecureStore _store;
  final QrScanner _qrScanner;
  final DeepLinkListener _deepLinks;
  final OpenChamberApi _api;
  final NativePush _push;
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
    pendingDeepLink = link;
    notifyListeners();
  }

  IncomingDeepLink? pendingDeepLink;
  final LiveActivityController liveActivity = LiveActivityController();

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
  }

  void setNotifyOnCompletion(bool value) {
    notifyOnCompletion = value;
    notifyListeners();
  }

  void setNotifyOnError(bool value) {
    notifyOnError = value;
    notifyListeners();
  }

  void setNotifyOnQuestion(bool value) {
    notifyOnQuestion = value;
    notifyListeners();
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
    String? relayUrl;
    String? pairingId;
    var pairingSecret = '';
    var pairingLabel = label;
    String? serverId;
    PairingConnectionPayload? decoded;
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
      relayUrl = decoded.firstRelayUrl;
      pairingLabel = pairingLabel.trim().isEmpty ? (decoded.label ?? pairingLabel) : pairingLabel;
      final direct = decoded.firstDirectUrl;
      if (direct != null) {
        resolvedUrl = direct;
      }
    }

    final urlError = validateServerUrl(resolvedUrl);
    if (urlError != null) {
      connectErrorKey = pairing != null && decoded?.firstDirectUrl == null
          ? 'connect.error.relayTunnelMissing'
          : urlError;
      notifyListeners();
      return false;
    }

    final base = normalizeServerBase(resolvedUrl);
    if (base == null) {
      connectErrorKey = 'connect.error.invalidUrl';
      notifyListeners();
      return false;
    }

    connecting = true;
    notifyListeners();
    try {
      final health = await _api.health(base);
      serverId = health.serverId ?? serverId;
      instanceVersion = health.openchamberVersion;

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
        return _activate(
          SavedInstance(
            id: _newId(),
            url: redeem.serverUrl ?? resolvedUrl,
            label: pairingLabel.trim().isEmpty ? (redeem.serverLabel ?? '') : pairingLabel,
            clientToken: redeem.clientToken!,
            relayUrl: relayUrl,
            pairingId: pairingId,
            serverId: serverId,
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
        return _activate(
          SavedInstance(
            id: _newId(),
            url: resolvedUrl,
            label: pairingLabel,
            clientToken: providedToken,
            relayUrl: relayUrl,
            serverId: serverId,
            lastUsedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }

      final session = await _api.getAuthSession(base);
      if (session.disabled || session.authenticated) {
        return _activate(
          SavedInstance(
            id: _newId(),
            url: resolvedUrl,
            label: pairingLabel,
            relayUrl: relayUrl,
            serverId: serverId,
            lastUsedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }

      pendingUnlock = SavedInstance(
        id: _newId(),
        url: resolvedUrl,
        label: pairingLabel,
        relayUrl: relayUrl,
        pairingId: pairingId,
        pairingSecret: pairingSecret,
        needsPassword: true,
        serverId: serverId,
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
    final base = normalizeServerBase(pending.url);
    if (base == null) {
      connectErrorKey = 'connect.error.invalidUrl';
      notifyListeners();
      return false;
    }
    connecting = true;
    notifyListeners();
    try {
      final unlocked = await _api.unlockWithPassword(
        base: base,
        password: password.trim(),
        deviceId: await _deviceId(),
        devicePlatform: _devicePlatform,
      );
      if (!unlocked.authenticated || unlocked.clientToken == null || unlocked.clientToken!.isEmpty) {
        connectErrorKey = 'connect.error.passwordFailed';
        return false;
      }
      return _activate(pending.copyWith(clientToken: unlocked.clientToken, needsPassword: false));
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
      _statusPoll?.cancel();
      _visibilityHeartbeat?.cancel();
      _pushBindKey = null;
      lastBoundRelayUrl = null;
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
    required String text,
  }) async {
    final base = activeBase;
    final bearer = activeBearer;
    final directory = session.directory ?? '';
    if (base == null) {
      throw OpenChamberHttpException(0, OpenChamberPaths.sessionPromptAsync(session.id), code: 'not_connected');
    }
    await _api.promptAsync(
      base: base,
      bearer: bearer ?? '',
      sessionId: session.id,
      directory: directory,
      messageId: messageId,
      text: text,
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
        sessionsErrorKey = 'projects.error.indexUnavailable';
        return;
      }
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
    final base = normalizeServerBase(instance.url);
    if (base == null) {
      connectErrorKey = 'connect.error.invalidUrl';
      return false;
    }
    connecting = true;
    notifyListeners();
    try {
      await _api.health(base);
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
      return _activate(instance, existing: existing);
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
    unawaited(_registerPush());
    _startStatusPoll();
    _startVisibilityHeartbeat();
    notifyListeners();
    return true;
  }

  void _startStatusPoll() {
    _statusPoll?.cancel();
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    _statusPoll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!isConnected) return;
      unawaited(refreshSessionStatus());
    });
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

  Future<void> _writeWidgetSnapshot() async {
    if (!_useNativeLinks) return;
    try {
      const channel = MethodChannel(OpenChamberChannels.widgetSnapshot);
      await channel.invokeMethod<void>('write', buildWidgetSnapshot(sessions).encode()).timeout(const Duration(milliseconds: 80));
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
    _statusPoll?.cancel();
    _liveActivityTimer?.cancel();
    _visibilityHeartbeat?.cancel();
    super.dispose();
  }
}
