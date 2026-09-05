import 'github_worktree.dart';
import 'settings_remote.dart';

/// Session-scoped composer model/agent last pick. Official Cap send body is
/// `model: { providerID, modelID }`, `agent`, `variant` on `prompt_async`.
class ComposerSessionPick {
  const ComposerSessionPick({
    required this.providerId,
    required this.modelId,
    this.agent,
    this.variant,
  });

  final String providerId;
  final String modelId;
  final String? agent;
  final String? variant;

  String get modelKey => '$providerId/$modelId';

  ComposerSessionPick copyWith({
    String? providerId,
    String? modelId,
    String? agent,
    String? variant,
    bool clearAgent = false,
    bool clearVariant = false,
  }) {
    return ComposerSessionPick(
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
      agent: clearAgent ? null : (agent ?? this.agent),
      variant: clearVariant ? null : (variant ?? this.variant),
    );
  }

  factory ComposerSessionPick.fromSettings(SettingsBlob? blob) {
    final model = splitDefaultModel(blob?.stringField('defaultModel'));
    final agent = blob?.stringField('defaultAgent');
    final variant = blob?.stringField('defaultVariant');
    return ComposerSessionPick(
      providerId: model.providerId,
      modelId: model.modelId,
      agent: agent,
      variant: variant,
    );
  }
}

class ComposerModelOption {
  const ComposerModelOption({
    required this.providerId,
    required this.providerName,
    required this.modelId,
    this.modelName,
  });

  final String providerId;
  final String providerName;
  final String modelId;
  final String? modelName;

  String get id => '$providerId/$modelId';
  String get title => (modelName != null && modelName!.isNotEmpty) ? modelName! : modelId;
}

List<ComposerModelOption> parseComposerModelOptions(Object? payload) {
  final root = asObjectMap(payload);
  final out = <ComposerModelOption>[];
  for (final provider in asObjectList(root['providers'])) {
    final providerId = provider['id']?.toString() ?? '';
    if (providerId.isEmpty) continue;
    final providerName = provider['name']?.toString() ?? providerId;
    final models = provider['models'];
    if (models is Map) {
      models.forEach((key, spec) {
        final modelId = key.toString();
        if (modelId.isEmpty) return;
        String? modelName;
        if (spec is Map) {
          modelName = spec['name']?.toString() ?? spec['id']?.toString();
        }
        out.add(ComposerModelOption(
          providerId: providerId,
          providerName: providerName,
          modelId: modelId,
          modelName: modelName,
        ));
      });
    } else if (models is List) {
      for (final spec in models) {
        if (spec is! Map) continue;
        final modelId = spec['id']?.toString() ?? '';
        if (modelId.isEmpty) continue;
        out.add(ComposerModelOption(
          providerId: providerId,
          providerName: providerName,
          modelId: modelId,
          modelName: spec['name']?.toString(),
        ));
      }
    }
  }
  return out;
}
