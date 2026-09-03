import 'package:flutter/foundation.dart';

import 'openchamber_api.dart';
import 'openchamber_http.dart';

/// Official quota provider ids from `packages/ui/src/types/quota.ts`.
const List<String> officialQuotaProviderIds = [
  'openai',
  'codex',
  'cursor',
  'claude',
  'github-copilot',
  'github-copilot-addon',
  'google',
  'kimi-for-coding',
  'nano-gpt',
  'openrouter',
  'zai-coding-plan',
  'zhipuai-coding-plan',
  'minimax-coding-plan',
  'minimax-cn-coding-plan',
  'ollama-cloud',
  'wafer',
  'opencode-go',
  'xai',
];

class SettingsNamedItem {
  const SettingsNamedItem({required this.id, required this.title, this.subtitle});

  final String id;
  final String title;
  final String? subtitle;
}

/// Failure is never treated as an authoritative empty list.
class SettingsResource<T> {
  const SettingsResource({this.value, this.errorKey, this.loading = false});

  final T? value;
  final String? errorKey;
  final bool loading;

  bool get hasValue => value != null;
}

class SettingsBlob {
  const SettingsBlob(this.raw);

  final Map<String, Object?> raw;

  bool? boolField(String key) {
    final value = raw[key];
    return value is bool ? value : null;
  }

  String? stringField(String key) {
    final value = raw[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  num? numField(String key) {
    final value = raw[key];
    return value is num ? value : null;
  }

  List<SettingsNamedItem> get projects => parseProjectEntries(raw['projects']);
}

class SettingsRemoteStore {
  SettingsRemoteStore({
    required OpenChamberApi api,
    required Uri? Function() base,
    required String? Function() bearer,
    this.onChanged,
  })  : _api = api,
        _base = base,
        _bearer = bearer;

  final OpenChamberApi _api;
  final Uri? Function() _base;
  final String? Function() _bearer;
  VoidCallback? onChanged;

  SettingsResource<SettingsBlob> blob = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> providers = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> agents = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> assistants = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> commands = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> mcp = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> plugins = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> skills = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> snippets = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> magicPrompts = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> gitIdentities = const SettingsResource();
  SettingsResource<String> agentsMd = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> voice = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> summaryModels = const SettingsResource();
  SettingsResource<List<SettingsNamedItem>> usage = const SettingsResource();

  void clear() {
    blob = const SettingsResource();
    providers = const SettingsResource();
    agents = const SettingsResource();
    assistants = const SettingsResource();
    commands = const SettingsResource();
    mcp = const SettingsResource();
    plugins = const SettingsResource();
    skills = const SettingsResource();
    snippets = const SettingsResource();
    magicPrompts = const SettingsResource();
    gitIdentities = const SettingsResource();
    agentsMd = const SettingsResource();
    voice = const SettingsResource();
    summaryModels = const SettingsResource();
    usage = const SettingsResource();
    onChanged?.call();
  }

  Future<void> loadBlob() => _load(
        current: () => blob,
        assign: (next) => blob = next,
        fetch: () async => SettingsBlob(await _api.getConfigSettings(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> patchBlob(Map<String, Object?> changes) async {
    final previous = blob;
    blob = SettingsResource(value: previous.value, loading: true);
    try {
      final updated = await _api.putConfigSettings(
        base: _requireBase(),
        bearer: _bearer(),
        changes: changes,
      );
      blob = SettingsResource(value: SettingsBlob(updated));
    } on OpenChamberHttpException {
      blob = SettingsResource(value: previous.value, errorKey: 'settings.error.saveFailed');
      onChanged?.call();
      rethrow;
    }
    onChanged?.call();
  }

  Future<void> loadProviders() => _load(
        current: () => providers,
        assign: (next) => providers = next,
        fetch: () async => parseProviderCatalog(await _api.getProviderCatalog(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadAgents() => _load(
        current: () => agents,
        assign: (next) => agents = next,
        fetch: () async => parseAgentList(await _api.getAgents(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadAssistants() => _load(
        current: () => assistants,
        assign: (next) => assistants = next,
        fetch: () async => parseAssistantSnapshot(await _api.getAssistantsSnapshot(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadCommands() => _load(
        current: () => commands,
        assign: (next) => commands = next,
        fetch: () async => parseCommandCatalog(await _api.getCommandCatalog(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadMcp() => _load(
        current: () => mcp,
        assign: (next) => mcp = next,
        fetch: () async => parseMcpServers(await _api.getMcpConfigs(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadPlugins() => _load(
        current: () => plugins,
        assign: (next) => plugins = next,
        fetch: () async => parsePluginEntries(await _api.getPlugins(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadSkills() => _load(
        current: () => skills,
        assign: (next) => skills = next,
        fetch: () async => parseSkills(await _api.getInstalledSkills(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadSnippets() => _load(
        current: () => snippets,
        assign: (next) => snippets = next,
        fetch: () async => parseSnippets(await _api.getSnippets(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadMagicPrompts() => _load(
        current: () => magicPrompts,
        assign: (next) => magicPrompts = next,
        fetch: () async => parseMagicPromptOverrides(await _api.getMagicPrompts(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadGitIdentities() => _load(
        current: () => gitIdentities,
        assign: (next) => gitIdentities = next,
        fetch: () async => parseGitIdentities(await _api.getGitIdentities(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadAgentsMd() => _load(
        current: () => agentsMd,
        assign: (next) => agentsMd = next,
        fetch: () async => parseAgentsMd(await _api.getBehaviorAgentsMd(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadVoice() => _load(
        current: () => voice,
        assign: (next) => voice = next,
        fetch: () async {
          final dictation = await _api.getDictationStatus(base: _requireBase(), bearer: _bearer());
          final tts = await _api.getTtsStatus(base: _requireBase(), bearer: _bearer());
          return parseVoiceStatus(dictation: dictation, tts: tts);
        },
      );

  Future<void> loadSummaryModels() => _load(
        current: () => summaryModels,
        assign: (next) => summaryModels = next,
        fetch: () async => parseSmallModels(await _api.getSmallModel(base: _requireBase(), bearer: _bearer())),
      );

  Future<void> loadUsage() => _load(
        current: () => usage,
        assign: (next) => usage = next,
        fetch: () async {
          final ids = usageProviderIds(blob.value);
          final rows = <SettingsNamedItem>[];
          for (final id in ids) {
            try {
              final payload = await _api.getQuota(base: _requireBase(), bearer: _bearer(), providerId: id);
              rows.add(parseQuotaRow(id, payload));
            } on OpenChamberHttpException catch (error) {
              rows.add(SettingsNamedItem(id: id, title: id, subtitle: 'HTTP ${error.status}'));
            }
          }
          return rows;
        },
      );

  Uri _requireBase() {
    final base = _base();
    if (base == null) {
      throw const OpenChamberHttpException(0, OpenChamberPaths.configSettings, code: 'not_connected');
    }
    return base;
  }

  Future<void> _load<T>({
    required SettingsResource<T> Function() current,
    required void Function(SettingsResource<T> next) assign,
    required Future<T> Function() fetch,
  }) async {
    final previous = current();
    assign(SettingsResource(value: previous.value, loading: true));
    onChanged?.call();
    try {
      final value = await fetch();
      assign(SettingsResource(value: value));
    } on OpenChamberHttpException catch (error) {
      assign(SettingsResource(
        value: previous.value,
        errorKey: error.code == 'not_connected' ? 'settings.error.needsServer' : 'settings.error.loadFailed',
      ));
    }
    onChanged?.call();
  }
}

List<String> usageProviderIds(SettingsBlob? blob) {
  final raw = blob?.raw['usageDropdownProviders'];
  if (raw is List) {
    final ids = raw.map((item) => item.toString()).where(officialQuotaProviderIds.contains).toList();
    if (ids.isNotEmpty) return ids;
  }
  return officialQuotaProviderIds;
}

Map<String, Object?> asObjectMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Map<String, Object?>> asObjectList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(asObjectMap).toList();
}

List<SettingsNamedItem> parseProviderCatalog(Object? payload) {
  final root = asObjectMap(payload);
  return asObjectList(root['providers']).map((item) {
    final id = item['id']?.toString() ?? '';
    final name = item['name']?.toString() ?? id;
    final models = item['models'];
    final count = models is Map ? models.length : (models is List ? models.length : 0);
    return SettingsNamedItem(id: id, title: name.isEmpty ? id : name, subtitle: count > 0 ? '$count' : null);
  }).where((item) => item.id.isNotEmpty).toList();
}

List<SettingsNamedItem> parseAgentList(Object? payload) {
  final items = payload is List ? asObjectList(payload) : asObjectList(asObjectMap(payload)['agents']);
  return items.map((item) {
    final name = item['name']?.toString() ?? item['id']?.toString() ?? '';
    final mode = item['mode']?.toString() ?? item['scope']?.toString();
    return SettingsNamedItem(id: name, title: name, subtitle: mode);
  }).where((item) => item.id.isNotEmpty).toList();
}

List<SettingsNamedItem> parseAssistantSnapshot(Object? payload) {
  final root = asObjectMap(payload);
  return asObjectList(root['assistants']).map((item) {
    final id = item['id']?.toString() ?? '';
    final name = item['name']?.toString() ?? id;
    final model = [item['providerID'], item['modelID']].whereType<String>().where((part) => part.isNotEmpty).join('/');
    return SettingsNamedItem(id: id, title: name, subtitle: model.isEmpty ? item['mode']?.toString() : model);
  }).where((item) => item.id.isNotEmpty).toList();
}

List<SettingsNamedItem> parseCommandCatalog(Object? payload) {
  final root = asObjectMap(payload);
  return asObjectList(root['commands']).map((item) {
    final name = item['name']?.toString() ?? '';
    final scope = item['scope']?.toString();
    final builtIn = item['isBuiltIn'] == true ? 'built-in' : scope;
    return SettingsNamedItem(id: name, title: name, subtitle: item['description']?.toString() ?? builtIn);
  }).where((item) => item.id.isNotEmpty).toList();
}

List<SettingsNamedItem> parseMcpServers(Object? payload) {
  return asObjectList(payload).map((item) {
    final name = item['name']?.toString() ?? item['id']?.toString() ?? '';
    final type = item['type']?.toString();
    final enabled = item['enabled'] == false ? 'disabled' : type;
    return SettingsNamedItem(id: name, title: name, subtitle: enabled);
  }).where((item) => item.id.isNotEmpty).toList();
}

List<SettingsNamedItem> parsePluginEntries(Object? payload) {
  final root = asObjectMap(payload);
  return asObjectList(root['entries']).map((item) {
    final id = item['id']?.toString() ?? item['spec']?.toString() ?? '';
    final spec = item['spec']?.toString() ?? id;
    return SettingsNamedItem(id: id, title: spec, subtitle: item['scope']?.toString());
  }).where((item) => item.id.isNotEmpty).toList();
}

List<SettingsNamedItem> parseSkills(Object? payload) {
  final root = asObjectMap(payload);
  return asObjectList(root['skills']).map((item) {
    final name = item['name']?.toString() ?? '';
    return SettingsNamedItem(
      id: name,
      title: name,
      subtitle: item['description']?.toString() ?? item['scope']?.toString(),
    );
  }).where((item) => item.id.isNotEmpty).toList();
}

List<SettingsNamedItem> parseSnippets(Object? payload) {
  return asObjectList(payload).map((item) {
    final name = item['name']?.toString() ?? '';
    return SettingsNamedItem(
      id: name,
      title: name,
      subtitle: item['description']?.toString() ?? item['source']?.toString(),
    );
  }).where((item) => item.id.isNotEmpty).toList();
}

List<SettingsNamedItem> parseMagicPromptOverrides(Object? payload) {
  final root = asObjectMap(payload);
  final overrides = asObjectMap(root['overrides']);
  return overrides.entries
      .map((entry) => SettingsNamedItem(id: entry.key, title: entry.key, subtitle: entry.value?.toString()))
      .toList();
}

List<SettingsNamedItem> parseGitIdentities(Object? payload) {
  return asObjectList(payload).map((item) {
    final id = item['id']?.toString() ?? '';
    final name = item['name']?.toString() ?? id;
    final email = item['userEmail']?.toString() ?? item['userName']?.toString();
    return SettingsNamedItem(id: id, title: name, subtitle: email);
  }).where((item) => item.id.isNotEmpty).toList();
}

List<SettingsNamedItem> parseProjectEntries(Object? payload) {
  return asObjectList(payload).map((item) {
    final id = item['id']?.toString() ?? '';
    final label = item['label']?.toString() ?? item['path']?.toString() ?? id;
    return SettingsNamedItem(id: id, title: label, subtitle: item['path']?.toString());
  }).where((item) => item.id.isNotEmpty).toList();
}

String parseAgentsMd(Object? payload) {
  final root = asObjectMap(payload);
  return root['content']?.toString() ?? '';
}

List<SettingsNamedItem> parseVoiceStatus({required Object? dictation, required Object? tts}) {
  final rows = <SettingsNamedItem>[];
  final dictationMap = asObjectMap(dictation);
  for (final model in asObjectList(dictationMap['models'])) {
    final id = model['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final installed = model['installed'] == true ? 'installed' : 'not installed';
    rows.add(SettingsNamedItem(id: 'stt:$id', title: id, subtitle: installed));
  }
  final ttsMap = asObjectMap(tts);
  rows.add(SettingsNamedItem(
    id: 'tts',
    title: 'TTS',
    subtitle: ttsMap['available'] == true ? 'available' : 'unavailable',
  ));
  return rows;
}

List<SettingsNamedItem> parseSmallModels(Object? payload) {
  final root = asObjectMap(payload);
  final callable = asObjectMap(root['callableModels']);
  final rows = <SettingsNamedItem>[];
  callable.forEach((provider, models) {
    if (models is List) {
      for (final model in models) {
        final id = model.toString();
        if (id.isEmpty) continue;
        rows.add(SettingsNamedItem(id: '$provider/$id', title: id, subtitle: provider));
      }
    }
  });
  return rows;
}

SettingsNamedItem parseQuotaRow(String providerId, Object? payload) {
  final root = asObjectMap(payload);
  final name = root['providerName']?.toString() ?? providerId;
  if (root['ok'] != true) {
    return SettingsNamedItem(
      id: providerId,
      title: name,
      subtitle: root['error']?.toString() ?? (root['configured'] == false ? 'not configured' : 'unavailable'),
    );
  }
  final usage = asObjectMap(root['usage']);
  final windows = asObjectList(usage['windows']);
  String? percent;
  if (windows.isNotEmpty) {
    final used = windows.first['usedPercent'];
    if (used is num) percent = '${used.toStringAsFixed(0)}%';
  }
  return SettingsNamedItem(id: providerId, title: name, subtitle: percent ?? 'ok');
}
