import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/openchamber_http.dart';
import '../../data/settings_remote.dart';
import '../../l10n/app_strings.dart';
import '../../theme/ios_hero.dart';
import '../../theme/oc_glyphs.dart';
import '../../theme/oc_tokens.dart';
import 'settings_primitives.dart';

enum SettingsEditorKind { providers, agents, assistants, commands, mcp, plugins, skills }

class EntityEditorSettingsPage extends StatefulWidget {
  const EntityEditorSettingsPage({
    super.key,
    required this.controller,
    required this.kind,
    required this.titleKey,
    required this.emptyKey,
  });

  final AppController controller;
  final SettingsEditorKind kind;
  final String titleKey;
  final String emptyKey;

  @override
  State<EntityEditorSettingsPage> createState() => _EntityEditorSettingsPageState();
}

class _EntityEditorSettingsPageState extends State<EntityEditorSettingsPage> {
  String? _actionError;

  SettingsResource<List<SettingsNamedItem>> get _resource {
    final store = widget.controller.remoteSettings;
    switch (widget.kind) {
      case SettingsEditorKind.providers:
        return store.providers;
      case SettingsEditorKind.agents:
        return store.agents;
      case SettingsEditorKind.assistants:
        return store.assistants;
      case SettingsEditorKind.commands:
        return store.commands;
      case SettingsEditorKind.mcp:
        return store.mcp;
      case SettingsEditorKind.plugins:
        return store.plugins;
      case SettingsEditorKind.skills:
        return store.skills;
    }
  }

  Future<void> _load() {
    final store = widget.controller.remoteSettings;
    switch (widget.kind) {
      case SettingsEditorKind.providers:
        return store.loadProviders();
      case SettingsEditorKind.agents:
        return store.loadAgents();
      case SettingsEditorKind.assistants:
        return store.loadAssistants();
      case SettingsEditorKind.commands:
        return store.loadCommands();
      case SettingsEditorKind.mcp:
        return store.loadMcp();
      case SettingsEditorKind.plugins:
        return store.loadPlugins();
      case SettingsEditorKind.skills:
        return store.loadSkills();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _actionError = null);
    try {
      await action();
    } on OpenChamberHttpException {
      if (mounted) setState(() => _actionError = 'settings.error.saveFailed');
    }
  }

  Future<void> _openEditor({SettingsNamedItem? item}) async {
    switch (widget.kind) {
      case SettingsEditorKind.providers:
        if (item == null) return;
        await _showFields(
          titleKey: 'settings.providers.apiKey',
          fields: [
            _FieldSpec(id: 'key', labelKey: 'settings.providers.apiKey', obscure: true),
          ],
          extra: [
            _OAuthActions(
              kind: SettingsEditorKind.providers,
              itemId: item.id,
              controller: widget.controller,
            ),
          ],
          onSave: (values) => _run(() => widget.controller.remoteSettings.saveProviderApiKey(item.id, values['key'] ?? '')),
        );
      case SettingsEditorKind.agents:
        await _showFields(
          titleKey: item == null ? 'settings.editor.create' : 'settings.editor.edit',
          fields: [
            _FieldSpec(id: 'name', labelKey: 'settings.editor.name', initial: item?.id, readOnly: item != null),
            _FieldSpec(id: 'mode', labelKey: 'settings.editor.mode', initial: item?.meta['mode'] ?? 'subagent'),
            _FieldSpec(id: 'description', labelKey: 'settings.editor.description', initial: item?.meta['description']),
            _FieldSpec(id: 'prompt', labelKey: 'settings.editor.prompt', initial: item?.meta['prompt'], maxLines: 4),
          ],
          onSave: (values) => _run(() {
            if (item == null) {
              return widget.controller.remoteSettings.createAgent(
                name: values['name'] ?? '',
                mode: values['mode'] ?? 'subagent',
                description: values['description'],
                prompt: values['prompt'],
              );
            }
            return widget.controller.remoteSettings.updateAgent(
              name: item.id,
              mode: values['mode'],
              description: values['description'],
              prompt: values['prompt'],
            );
          }),
          onDelete: item == null ? null : () => _run(() => widget.controller.remoteSettings.deleteAgent(item.id)),
        );
      case SettingsEditorKind.assistants:
        await _showFields(
          titleKey: item == null ? 'settings.editor.create' : 'settings.editor.edit',
          fields: [
            _FieldSpec(id: 'name', labelKey: 'settings.editor.name', initial: item?.title),
            _FieldSpec(id: 'providerID', labelKey: 'settings.editor.provider', initial: item?.meta['providerID']),
            _FieldSpec(id: 'modelID', labelKey: 'settings.editor.model', initial: item?.meta['modelID']),
            _FieldSpec(id: 'mode', labelKey: 'settings.editor.mode', initial: item?.meta['mode'] ?? 'chat'),
            _FieldSpec(id: 'defaultPrompt', labelKey: 'settings.editor.prompt', initial: item?.meta['defaultPrompt'], maxLines: 4),
          ],
          onSave: (values) => _run(() {
            if (item == null) {
              return widget.controller.remoteSettings.createAssistant(
                name: values['name'] ?? '',
                providerId: values['providerID'] ?? '',
                modelId: values['modelID'] ?? '',
                mode: values['mode'] ?? 'chat',
                defaultPrompt: values['defaultPrompt'] ?? '',
              );
            }
            return widget.controller.remoteSettings.updateAssistant(
              id: item.id,
              expectedRevision: int.tryParse(item.meta['revision'] ?? '') ?? 0,
              name: values['name'] ?? item.title,
              providerId: values['providerID'] ?? '',
              modelId: values['modelID'] ?? '',
              mode: values['mode'] ?? 'chat',
              defaultPrompt: values['defaultPrompt'] ?? '',
            );
          }),
          onDelete: item == null
              ? null
              : () => _run(() => widget.controller.remoteSettings.deleteAssistant(
                    id: item.id,
                    expectedRevision: int.tryParse(item.meta['revision'] ?? '') ?? 0,
                  )),
        );
      case SettingsEditorKind.commands:
        if (item?.meta['builtIn'] == 'true') return;
        await _showFields(
          titleKey: item == null ? 'settings.editor.create' : 'settings.editor.edit',
          fields: [
            _FieldSpec(id: 'name', labelKey: 'settings.editor.name', initial: item?.id, readOnly: item != null),
            _FieldSpec(id: 'description', labelKey: 'settings.editor.description', initial: item?.meta['description']),
            _FieldSpec(id: 'template', labelKey: 'settings.editor.template', initial: item?.meta['template'], maxLines: 4),
          ],
          onSave: (values) => _run(() {
            if (item == null) {
              return widget.controller.remoteSettings.createCommand(
                name: values['name'] ?? '',
                template: values['template'] ?? '',
                description: values['description'],
              );
            }
            return widget.controller.remoteSettings.updateCommand(
              name: item.id,
              template: values['template'] ?? '',
              description: values['description'],
            );
          }),
          onDelete: item == null ? null : () => _run(() => widget.controller.remoteSettings.deleteCommand(item.id)),
        );
      case SettingsEditorKind.mcp:
        await _showFields(
          titleKey: item == null ? 'settings.editor.create' : 'settings.editor.edit',
          fields: [
            _FieldSpec(id: 'name', labelKey: 'settings.editor.name', initial: item?.id, readOnly: item != null),
            _FieldSpec(id: 'type', labelKey: 'settings.editor.type', initial: item?.meta['type'] ?? 'local'),
            _FieldSpec(id: 'command', labelKey: 'settings.editor.command', initial: item?.meta['command']),
            _FieldSpec(id: 'url', labelKey: 'settings.editor.url', initial: item?.meta['url']),
          ],
          extra: [
            _OAuthActions(
              kind: SettingsEditorKind.mcp,
              itemId: item?.id ?? '',
              controller: widget.controller,
            ),
          ],
          onSave: (values) => _run(() {
            final type = values['type'] ?? 'local';
            if (item == null) {
              return widget.controller.remoteSettings.createMcp(
                name: values['name'] ?? '',
                type: type,
                command: values['command'],
                url: values['url'],
              );
            }
            return widget.controller.remoteSettings.updateMcp(
              name: item.id,
              type: type,
              command: values['command'],
              url: values['url'],
            );
          }),
          onDelete: item == null ? null : () => _run(() => widget.controller.remoteSettings.deleteMcp(item.id)),
        );
      case SettingsEditorKind.plugins:
        final isFile = item?.meta['kind'] == 'file';
        Map<String, String> file = const {};
        if (isFile && item != null) {
          try {
            file = await widget.controller.remoteSettings.readPluginFile(item.id);
          } on OpenChamberHttpException {
            if (mounted) setState(() => _actionError = 'settings.error.loadFailed');
            return;
          }
        }
        await _showFields(
          titleKey: item == null ? 'settings.editor.create' : 'settings.editor.edit',
          fields: [
            if (!isFile) _FieldSpec(id: 'spec', labelKey: 'settings.editor.spec', initial: item?.meta['spec'] ?? item?.title),
            _FieldSpec(id: 'scope', labelKey: 'settings.editor.scope', initial: file['scope'] ?? item?.meta['scope'] ?? 'user'),
            _FieldSpec(id: 'fileName', labelKey: 'settings.plugins.fileName', initial: file['fileName'] ?? item?.meta['fileName']),
            _FieldSpec(id: 'content', labelKey: 'settings.plugins.fileContent', initial: file['content'], maxLines: 8),
          ],
          onSave: (values) => _run(() {
            final fileName = values['fileName']?.trim() ?? '';
            if (isFile && item != null) {
              return widget.controller.remoteSettings.updatePluginFile(id: item.id, content: values['content'] ?? '');
            }
            if (fileName.isNotEmpty) {
              return widget.controller.remoteSettings.createPluginFile(
                fileName: fileName,
                content: values['content'] ?? '',
                scope: values['scope'] ?? 'user',
              );
            }
            if (item == null) {
              return widget.controller.remoteSettings.createPlugin(spec: values['spec'] ?? '', scope: values['scope'] ?? 'user');
            }
            return widget.controller.remoteSettings.updatePlugin(id: item.id, spec: values['spec'] ?? '', scope: values['scope']);
          }),
          onDelete: item == null
              ? null
              : () => _run(() => isFile
                  ? widget.controller.remoteSettings.deletePluginFile(item.id)
                  : widget.controller.remoteSettings.deletePlugin(item.id)),
        );
      case SettingsEditorKind.skills:
        await _showFields(
          titleKey: item == null ? 'settings.editor.create' : 'settings.editor.edit',
          fields: [
            _FieldSpec(id: 'name', labelKey: 'settings.editor.name', initial: item?.id, readOnly: item != null),
            _FieldSpec(id: 'description', labelKey: 'settings.editor.description', initial: item?.meta['description']),
            _FieldSpec(id: 'source', labelKey: 'settings.skills.source', initial: ''),
            _FieldSpec(id: 'skillDir', labelKey: 'settings.skills.skillDir', initial: item?.id),
          ],
          extra: [
            ListTile(title: Text(t(context, 'settings.skills.installHint'))),
          ],
          onSave: (values) => _run(() async {
            final source = values['source']?.trim() ?? '';
            if (source.isNotEmpty) {
              await widget.controller.remoteSettings.installSkill(
                source: source,
                skillDir: values['skillDir'] ?? values['name'] ?? '',
              );
              return;
            }
            if (item == null) {
              await widget.controller.remoteSettings.createSkill(
                name: values['name'] ?? '',
                description: values['description'] ?? '',
              );
              return;
            }
            await widget.controller.remoteSettings.updateSkill(
              name: item.id,
              description: values['description'] ?? '',
            );
          }),
          onDelete: item == null ? null : () => _run(() => widget.controller.remoteSettings.deleteSkill(item.id)),
        );
    }
  }

  Future<void> _showFields({
    required String titleKey,
    required List<_FieldSpec> fields,
    required Future<void> Function(Map<String, String> values) onSave,
    Future<void> Function()? onDelete,
    List<Widget> extra = const [],
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return _EditorDialog(
          titleKey: titleKey,
          fields: fields,
          extra: extra,
          onSave: onSave,
          onDelete: onDelete,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final resource = _resource;
    return SettingsPageScaffold(
      title: t(context, widget.titleKey),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_actionError != null)
            SettingsGroup(
              label: t(context, widget.titleKey),
              children: [
                ListTile(key: const Key('settings-editor-error'), title: Text(t(context, _actionError!))),
              ],
            ),
          SettingsGroup(
            label: t(context, widget.titleKey),
            children: [
              if (resource.errorKey != null)
                ListTile(key: const Key('settings-resource-error'), title: Text(t(context, resource.errorKey!)))
              else if (resource.loading && !resource.hasValue)
                const ListTile(title: LinearProgressIndicator())
              else if (resource.value == null || resource.value!.isEmpty)
                ListTile(key: const Key('settings-resource-empty'), title: Text(t(context, widget.emptyKey)))
              else
                ...resource.value!.map(
                  (item) => SettingsNavRow(
                    key: Key('settings-item-${item.id}'),
                    label: item.title,
                    subtitle: item.subtitle,
                    onTap: () => _openEditor(item: item),
                  ),
                ),
              if (widget.kind != SettingsEditorKind.providers)
                ListTile(
                  key: const Key('settings-editor-add'),
                  leading: OcGlyph(
                    OcGlyphKind.plus,
                    size: OcOptical.settingsNavIcon,
                    strokeWidth: OcOptical.settingsGlyphStrokeVisual,
                    color: context.oc.foreground,
                  ),
                  title: Text(t(context, 'settings.editor.create')),
                  onTap: () => _openEditor(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorDialog extends StatefulWidget {
  const _EditorDialog({
    required this.titleKey,
    required this.fields,
    required this.onSave,
    this.onDelete,
    this.extra = const [],
  });

  final String titleKey;
  final List<_FieldSpec> fields;
  final Future<void> Function(Map<String, String> values) onSave;
  final Future<void> Function()? onDelete;
  final List<Widget> extra;

  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.fields) field.id: TextEditingController(text: field.initial ?? ''),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t(context, widget.titleKey)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in widget.fields)
              TextField(
                key: Key('settings-editor-field-${field.id}'),
                controller: _controllers[field.id],
                obscureText: field.obscure,
                readOnly: field.readOnly,
                maxLines: field.maxLines,
                decoration: InputDecoration(labelText: t(context, field.labelKey)),
              ),
            ...widget.extra,
          ],
        ),
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            key: const Key('settings-editor-delete'),
            onPressed: () async {
              Navigator.of(context).pop();
              await widget.onDelete!();
            },
            child: Text(t(context, 'settings.editor.delete')),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t(context, 'settings.view.actions.back')),
        ),
        TextButton(
          key: const Key('settings-editor-save'),
          onPressed: () async {
            final values = {
              for (final entry in _controllers.entries) entry.key: entry.value.text,
            };
            Navigator.of(context).pop();
            await widget.onSave(values);
          },
          child: Text(t(context, 'settings.editor.save')),
        ),
      ],
    );
  }
}

class _OAuthActions extends StatefulWidget {
  const _OAuthActions({
    required this.kind,
    required this.itemId,
    required this.controller,
  });

  final SettingsEditorKind kind;
  final String itemId;
  final AppController controller;

  @override
  State<_OAuthActions> createState() => _OAuthActionsState();
}

class _OAuthActionsState extends State<_OAuthActions> {
  final _code = TextEditingController();
  String? _errorKey;
  String? _hint;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _code.dispose();
    super.dispose();
  }

  void _onController() {
    final callback = widget.controller.pendingOAuthCallback;
    if (callback == null || !mounted) return;
    if (callback.hasCode) {
      _code.text = callback.code!;
      widget.controller.takeOAuthCallback();
      unawaited(_complete());
    }
  }

  Future<void> _start() async {
    if (widget.itemId.isEmpty) return;
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      if (widget.kind == SettingsEditorKind.providers) {
        final start = await widget.controller.startProviderOAuth(widget.itemId);
        if (!mounted) return;
        setState(() {
          _hint = start.instructions ?? (start.canOpenBrowser ? 'settings.oauth.openedBrowser' : 'settings.oauth.missingUrl');
        });
      } else {
        await widget.controller.startMcpOAuth(widget.itemId);
        if (!mounted) return;
        setState(() => _hint = 'settings.oauth.openedBrowser');
      }
    } on OpenChamberHttpException {
      if (mounted) setState(() => _errorKey = 'settings.oauth.startFailed');
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'settings.oauth.browserFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    if (widget.itemId.isEmpty) return;
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      final callback = widget.controller.takeOAuthCallback();
      final code = _code.text.trim().isNotEmpty ? _code.text.trim() : callback?.code;
      if (widget.kind == SettingsEditorKind.providers) {
        await widget.controller.completeProviderOAuth(widget.itemId, code: code);
      } else {
        if (code == null || code.isEmpty) {
          setState(() => _errorKey = 'settings.oauth.codeRequired');
          return;
        }
        await widget.controller.completeMcpOAuth(name: widget.itemId, code: code, state: callback?.state);
      }
      if (mounted) setState(() => _hint = 'settings.oauth.completed');
    } on OpenChamberHttpException {
      if (mounted) setState(() => _errorKey = 'settings.oauth.completeFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          key: const Key('settings-oauth-start'),
          title: Text(t(context, 'settings.oauth.authorize')),
          subtitle: Text(t(context, _hint ?? 'settings.oauth.authorizeHint')),
          enabled: !_busy && widget.itemId.isNotEmpty,
          onTap: _start,
        ),
        TextField(
          key: const Key('settings-oauth-code'),
          controller: _code,
          decoration: InputDecoration(labelText: t(context, 'settings.oauth.code')),
        ),
        ListTile(
          key: const Key('settings-oauth-complete'),
          title: Text(t(context, 'settings.oauth.complete')),
          enabled: !_busy && widget.itemId.isNotEmpty,
          onTap: _complete,
        ),
        if (_errorKey != null)
          ListTile(
            key: const Key('settings-oauth-error'),
            title: Text(t(context, _errorKey!)),
          ),
      ],
    );
  }
}

class _FieldSpec {
  const _FieldSpec({
    required this.id,
    required this.labelKey,
    this.initial,
    this.obscure = false,
    this.readOnly = false,
    this.maxLines = 1,
  });

  final String id;
  final String labelKey;
  final String? initial;
  final bool obscure;
  final bool readOnly;
  final int maxLines;
}
