import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../native/deep_link.dart';
import '../native/live_activity_controller.dart';
import '../native/qr_scanner.dart';
import '../native/share_targeting.dart';
import 'instance_store.dart';
import 'pairing_payload.dart';
import 'secure_store.dart';

enum AppPhase { splash, connect, shell }

enum ConnectForm { welcome, password }

class AppController extends ChangeNotifier {
  AppController({
    required SecureStore store,
    InstanceSnapshot? seed,
    QrScanner? qrScanner,
    DeepLinkListener? deepLinks,
  })  : _store = store,
        _qrScanner = qrScanner ?? QrScanner(),
        _deepLinks = deepLinks ?? DeepLinkListener(),
        _instances = seed?.instances ?? const [],
        _activeId = seed?.activeId;

  final SecureStore _store;
  final QrScanner _qrScanner;
  final DeepLinkListener _deepLinks;
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

  List<SavedInstance> get instances => List.unmodifiable(_instances);
  SavedInstance? get activeInstance {
    if (_activeId == null) return null;
    for (final instance in _instances) {
      if (instance.id == _activeId) return instance;
    }
    return null;
  }

  bool get isConnected => phase == AppPhase.shell && activeInstance != null;

  Future<void> bootstrap({bool skipDelay = false}) async {
    locale = _localeFromCode(await _store.read(localeStorageKey));
    themeMode = _themeFromCode(await _store.read(themeStorageKey));
    final snapshot = await _repository.load();
    _instances = snapshot.instances;
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
    if (activeInstance != null) {
      phase = AppPhase.shell;
    } else {
      phase = AppPhase.connect;
      connectForm = ConnectForm.welcome;
    }
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
    notifyListeners();
  }

  Future<bool> connect({
    String url = '',
    String label = '',
    String clientToken = '',
    String pairingLink = '',
    bool requiresPassword = false,
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
    if (pairing != null) {
      if (!pairing.isV2) {
        connectErrorKey = 'connect.link.invalid';
        notifyListeners();
        return false;
      }
      final decoded = pairing.decoded ?? parsePairingConnectionPayload(pairing.raw);
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
      } else if (resolvedUrl.isEmpty) {
        // Relay-only payload: persist pairing + relayUrl, no made-up HTTP origin.
        resolvedUrl = 'openchamber://pairing/${decoded.pairingId}';
      }
    }

    final urlError = validateServerUrl(resolvedUrl);
    if (urlError != null && pairing == null) {
      connectErrorKey = urlError;
      notifyListeners();
      return false;
    }

    if (requiresPassword && clientToken.trim().isEmpty) {
      pendingUnlock = SavedInstance(
        id: _newId(),
        url: resolvedUrl,
        label: pairingLabel,
        relayUrl: relayUrl,
        pairingId: pairingId,
        pairingSecret: pairingSecret,
        needsPassword: true,
      );
      connectForm = ConnectForm.password;
      notifyListeners();
      return false;
    }

    return _activate(
      SavedInstance(
        id: _newId(),
        url: resolvedUrl,
        label: pairingLabel,
        clientToken: clientToken.trim(),
        relayUrl: relayUrl,
        pairingId: pairingId,
        pairingSecret: pairingSecret,
      ),
    );
  }

  Future<bool> unlockWithPassword(String password) async {
    final pending = pendingUnlock;
    if (pending == null) return false;
    if (password.trim().isEmpty) {
      connectErrorKey = 'connect.error.authRequired';
      notifyListeners();
      return false;
    }
    // First slice does not call the instance UI-password endpoint. A
    // non-empty password stands in for issued client-token storage.
    return _activate(pending.copyWith(clientToken: password.trim(), needsPassword: false));
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
    if (match.needsPassword && match.clientToken.isEmpty) {
      pendingUnlock = match;
      phase = AppPhase.connect;
      connectForm = ConnectForm.password;
      notifyListeners();
      return;
    }
    await _activate(match, existing: true);
  }

  Future<void> deleteInstance(String id) async {
    final wasActive = _activeId == id;
    _instances = _instances.where((item) => item.id != id).toList();
    if (wasActive) {
      _activeId = null;
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

  Future<bool> _activate(SavedInstance instance, {bool existing = false}) async {
    connecting = true;
    notifyListeners();
    if (!existing) {
      _instances = [..._instances.where((item) => item.id != instance.id), instance];
    }
    _activeId = instance.id;
    pendingUnlock = null;
    await _repository.persist(InstanceSnapshot(instances: _instances, activeId: _activeId));
    connecting = false;
    connectForm = ConnectForm.welcome;
    phase = AppPhase.shell;
    if (_useNativeLinks) {
      await _publishShareCatalog();
    }
    notifyListeners();
    return true;
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
      const channel = MethodChannel('openchamber/share');
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
    } catch (_) {
      // Catalog publish is best-effort until native plugins register.
    }
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
}
