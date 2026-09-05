import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/app_version.dart';
import '../../data/diagnostics_export.dart';
import '../../data/settings_catalog.dart';
import '../../data/settings_remote.dart';
import '../../l10n/app_strings.dart';
import '../../native/media_channel.dart';
import '../../navigation/platform_route.dart';
import '../../theme/ios_hero.dart';
import '../../theme/oc_glyphs.dart';
import '../../theme/oc_tokens.dart';
import 'settings_editors.dart';
import 'settings_primitives.dart';

/// Official `RESPONSE_STYLE_PRESETS` plus Cap `custom` from `packages/ui/src/lib/responseStyle.ts`.
const List<String> _responseStylePresetIds = [
  'concise',
  'detailed',
  'mentor',
  'pushback',
  'noFiller',
  'matchEnergy',
  'warmPeer',
  'custom',
];

class SettingsDetailPage extends StatelessWidget {
  const SettingsDetailPage({
    super.key,
    required this.controller,
    required this.page,
  });

  final AppController controller;
  final SettingsPageMeta page;

  @override
  Widget build(BuildContext context) {
    switch (page.slug) {
      case 'instances':
        return InstancesSettingsPage(controller: controller);
      case 'appearance':
        return AppearanceSettingsPage(controller: controller);
      case 'notifications':
        return NotificationsSettingsPage(controller: controller);
      case 'about':
        return AboutSettingsPage(controller: controller);
      case 'chat':
        return ChatSettingsPage(controller: controller);
      case 'sessions':
        return SessionsSettingsPage(controller: controller);
      case 'summary-ai':
        return SummaryAiSettingsPage(controller: controller);
      case 'projects':
        return ProjectsSettingsPage(controller: controller);
      case 'git':
        return GitSettingsPage(controller: controller);
      case 'providers':
        return EntityEditorSettingsPage(
          controller: controller,
          kind: SettingsEditorKind.providers,
          titleKey: 'settings.providers.title',
          emptyKey: 'settings.providers.empty',
        );
      case 'agents':
        return EntityEditorSettingsPage(
          controller: controller,
          kind: SettingsEditorKind.agents,
          titleKey: 'settings.agents.title',
          emptyKey: 'settings.agents.empty',
        );
      case 'assistants':
        return EntityEditorSettingsPage(
          controller: controller,
          kind: SettingsEditorKind.assistants,
          titleKey: 'settings.assistants.title',
          emptyKey: 'settings.assistants.empty',
        );
      case 'behavior':
        return BehaviorSettingsPage(controller: controller);
      case 'commands':
        return EntityEditorSettingsPage(
          controller: controller,
          kind: SettingsEditorKind.commands,
          titleKey: 'settings.commands.title',
          emptyKey: 'settings.commands.empty',
        );
      case 'mcp':
        return EntityEditorSettingsPage(
          controller: controller,
          kind: SettingsEditorKind.mcp,
          titleKey: 'settings.mcp.title',
          emptyKey: 'settings.mcp.empty',
        );
      case 'plugins':
        return EntityEditorSettingsPage(
          controller: controller,
          kind: SettingsEditorKind.plugins,
          titleKey: 'settings.plugins.title',
          emptyKey: 'settings.plugins.empty',
        );
      case 'magic-prompts':
        return EntityEditorSettingsPage(
          controller: controller,
          kind: SettingsEditorKind.magicPrompts,
          titleKey: 'settings.magicPrompts.title',
          emptyKey: 'settings.magicPrompts.empty',
        );
      case 'snippets':
        return EntityEditorSettingsPage(
          controller: controller,
          kind: SettingsEditorKind.snippets,
          titleKey: 'settings.snippets.title',
          emptyKey: 'settings.snippets.empty',
        );
      case 'skills.installed':
        return EntityEditorSettingsPage(
          controller: controller,
          kind: SettingsEditorKind.skills,
          titleKey: 'settings.skills.title',
          emptyKey: 'settings.skills.empty',
        );
      case 'usage':
        return RemoteListSettingsPage(
          controller: controller,
          titleKey: 'settings.usage.title',
          emptyKey: 'settings.usage.empty',
          resource: () => controller.remoteSettings.usage,
          load: controller.remoteSettings.loadUsage,
        );
      default:
        return SettingsPageScaffold(
          title: t(context, page.titleKey),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SettingsGroup(
                label: t(context, page.titleKey),
                children: [
                  ListTile(
                    title: Text(t(context, 'settings.placeholder.body')),
                    subtitle: Text(page.slug),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}

class InstancesSettingsPage extends StatelessWidget {
  const InstancesSettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: t(context, 'settings.instances.title'),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGroup(
            label: t(context, 'settings.instances.title'),
            children: [
              if (controller.instances.isEmpty)
                ListTile(title: Text(t(context, 'settings.instances.empty')))
              else
                ...controller.instances.map((instance) {
                  final active = controller.activeInstance?.id == instance.id;
                  return ListTile(
                    title: Text(instance.displayLabel),
                    subtitle: Text(
                      active
                          ? t(context, controller.activeConnectionStatusKey ?? 'mobile.instances.status.connectedDirect')
                          : instance.url,
                    ),
                    trailing: active
                        ? OcGlyph(
                            OcGlyphKind.check,
                            size: OcOptical.settingsNavIcon,
                            strokeWidth: OcOptical.settingsGlyphStrokeVisual,
                            color: context.oc.foreground,
                          )
                        : null,
                    onTap: () => controller.activateExisting(instance.id),
                  );
                }),
              ListTile(
                key: const Key('instances-add'),
                leading: OcGlyph(
                  OcGlyphKind.plus,
                  size: OcOptical.settingsNavIcon,
                  strokeWidth: OcOptical.settingsGlyphStrokeVisual,
                  color: context.oc.foreground,
                ),
                title: Text(t(context, 'settings.instances.add')),
                onTap: controller.switchToConnect,
              ),
              ListTile(
                key: const Key('instances-scan-qr'),
                leading: OcGlyph(
                  OcGlyphKind.qr,
                  size: OcOptical.settingsNavIcon,
                  strokeWidth: OcOptical.settingsGlyphStrokeVisual,
                  color: context.oc.foreground,
                ),
                title: Text(t(context, 'connect.scanQr')),
                subtitle: Text(t(context, 'settings.instances.qrTodo')),
                onTap: controller.scanAndConnect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: t(context, 'settings.appearance.title'),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGroup(
            label: t(context, 'settings.appearance.language'),
            children: [
              RadioListTile<Locale>(
                key: const Key('appearance-lang-en'),
                title: Text(t(context, 'language.en')),
                value: AppStrings.en,
                groupValue: controller.locale.languageCode == 'zh' ? AppStrings.zhCN : AppStrings.en,
                onChanged: (value) {
                  if (value != null) controller.setLocale(value);
                },
              ),
              RadioListTile<Locale>(
                key: const Key('appearance-lang-zh'),
                title: Text(t(context, 'language.zhCN')),
                value: AppStrings.zhCN,
                groupValue: controller.locale.languageCode == 'zh' ? AppStrings.zhCN : AppStrings.en,
                onChanged: (value) {
                  if (value != null) controller.setLocale(value);
                },
              ),
            ],
          ),
          SettingsGroup(
            label: t(context, 'settings.appearance.theme'),
            children: [
              for (final mode in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  key: Key('appearance-theme-${mode.name}'),
                  title: Text(t(context, 'settings.appearance.theme.${mode.name}')),
                  value: mode,
                  groupValue: controller.themeMode,
                  onChanged: (value) {
                    if (value != null) controller.setThemeMode(value);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final blobError = controller.remoteSettings.blob.errorKey;
    return SettingsPageScaffold(
      title: t(context, 'settings.notifications.title'),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (blobError != null)
            SettingsGroup(
              label: t(context, 'settings.notifications.title'),
              children: [
                ListTile(
                  key: const Key('settings-resource-error'),
                  title: Text(t(context, blobError)),
                ),
              ],
            ),
          SettingsGroup(
            label: t(context, 'settings.notifications.title'),
            children: [
              SettingsToggleRow(
                label: t(context, 'settings.notifications.enable'),
                value: controller.notificationsEnabled,
                onChanged: controller.setNotificationsEnabled,
              ),
              SettingsToggleRow(
                label: t(context, 'settings.notifications.completion'),
                value: controller.notifyOnCompletion,
                onChanged: controller.setNotifyOnCompletion,
              ),
              SettingsToggleRow(
                label: t(context, 'settings.notifications.error'),
                value: controller.notifyOnError,
                onChanged: controller.setNotifyOnError,
              ),
              SettingsToggleRow(
                label: t(context, 'settings.notifications.question'),
                value: controller.notifyOnQuestion,
                onChanged: controller.setNotifyOnQuestion,
              ),
              SettingsToggleRow(
                label: t(context, 'settings.notifications.push'),
                subtitle: t(context, 'settings.notifications.push.hint'),
                value: controller.backgroundPushEnabled,
                onChanged: controller.setBackgroundPushEnabled,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AboutSettingsPage extends StatefulWidget {
  const AboutSettingsPage({super.key, required this.controller, this.media});

  final AppController controller;
  final MediaChannel? media;

  @override
  State<AboutSettingsPage> createState() => _AboutSettingsPageState();
}

class _AboutSettingsPageState extends State<AboutSettingsPage> {
  bool _exporting = false;

  Future<void> _exportDiagnostics() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final content = exportClientDiagnosticsReport();
    final result = await (widget.media ?? MediaChannel()).saveFile(
      dataBase64: base64Encode(utf8.encode(content)),
      filename: diagnosticsExportFileName(),
    );
    if (!mounted) return;
    setState(() => _exporting = false);
    if (result.cancelled) return;
    final key = result.failed
        ? 'settings.openchamber.about.diagnostics.toast.failed'
        : diagnosticsExportEventCount(content) == 0
            ? 'settings.openchamber.about.diagnostics.toast.empty'
            : 'settings.openchamber.about.diagnostics.toast.exported';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, key))));
  }

  @override
  Widget build(BuildContext context) {
    final instance = widget.controller.activeInstance;
    return SettingsPageScaffold(
      title: t(context, 'settings.about.title'),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGroup(
            label: t(context, 'settings.about.app'),
            children: [
              ListTile(
                title: Text(t(context, 'app.name')),
                subtitle: const Text(AppVersion.applicationId),
              ),
              ListTile(
                title: Text(t(context, 'settings.about.nativeVersion')),
                subtitle: const Text(AppVersion.display),
              ),
              ListTile(
                title: Text(t(context, 'settings.about.baseline')),
                subtitle: Text('${AppVersion.display} · ${AppVersion.baselineCommit}'),
              ),
              ListTile(
                title: Text(t(context, 'settings.about.instanceVersion')),
                subtitle: Text(
                  widget.controller.instanceVersion ??
                      (instance == null ? t(context, 'settings.about.instanceUnknown') : instance.displayLabel),
                ),
              ),
            ],
          ),
          SettingsGroup(
            label: t(context, 'settings.openchamber.about.diagnostics.label'),
            children: [
              SettingsToggleRow(
                key: const Key('about-diagnostics-enable'),
                label: t(context, 'settings.openchamber.about.diagnostics.enable'),
                subtitle: t(context, 'settings.openchamber.about.diagnostics.enableHint'),
                value: widget.controller.diagnosticsEnabled,
                onChanged: (enabled) async {
                  await widget.controller.setDiagnosticsEnabled(enabled);
                  if (mounted) setState(() {});
                },
              ),
              if (widget.controller.diagnosticsEnabled)
                ListTile(
                  key: const Key('about-diagnostics-export'),
                  title: Text(
                    t(
                      context,
                      _exporting
                          ? 'settings.openchamber.about.diagnostics.exporting'
                          : 'settings.openchamber.about.diagnostics.export',
                    ),
                  ),
                  onTap: _exporting ? null : _exportDiagnostics,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatSettingsPage extends StatelessWidget {
  const ChatSettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: t(context, 'settings.chat.title'),
      child: _BlobSettingsBody(
        controller: controller,
        builder: (context, blob) {
          final render = blob.stringField('chatRenderMode') ?? 'sorted';
          final transport = blob.stringField('messageStreamTransport') ?? 'auto';
          final followUp = blob.stringField('followUpBehavior') ?? 'steer';
          return [
            SettingsGroup(
              label: t(context, 'settings.chat.renderMode'),
              children: [
                RadioListTile<String>(
                  key: const Key('settings-chat-render-sorted'),
                  title: Text(t(context, 'settings.chat.renderMode.sorted')),
                  value: 'sorted',
                  groupValue: render,
                  onChanged: (value) {
                    if (value != null) controller.patchChatSetting('chatRenderMode', value);
                  },
                ),
                RadioListTile<String>(
                  key: const Key('settings-chat-render-live'),
                  title: Text(t(context, 'settings.chat.renderMode.live')),
                  value: 'live',
                  groupValue: render,
                  onChanged: (value) {
                    if (value != null) controller.patchChatSetting('chatRenderMode', value);
                  },
                ),
              ],
            ),
            SettingsGroup(
              label: t(context, 'settings.chat.transport'),
              children: [
                for (final option in const ['auto', 'ws', 'sse'])
                  RadioListTile<String>(
                    key: Key('settings-chat-transport-$option'),
                    title: Text(t(context, 'settings.chat.transport.$option')),
                    value: option,
                    groupValue: transport,
                    onChanged: (value) {
                      if (value != null) controller.patchChatSetting('messageStreamTransport', value);
                    },
                  ),
              ],
            ),
            SettingsGroup(
              label: t(context, 'settings.chat.followUp'),
              children: [
                RadioListTile<String>(
                  title: Text(t(context, 'settings.chat.followUp.steer')),
                  value: 'steer',
                  groupValue: followUp,
                  onChanged: (value) {
                    if (value != null) controller.patchChatSetting('followUpBehavior', value);
                  },
                ),
                RadioListTile<String>(
                  title: Text(t(context, 'settings.chat.followUp.queue')),
                  value: 'queue',
                  groupValue: followUp,
                  onChanged: (value) {
                    if (value != null) controller.patchChatSetting('followUpBehavior', value);
                  },
                ),
              ],
            ),
            SettingsGroup(
              label: t(context, 'settings.chat.display'),
              children: [
                SettingsToggleRow(
                  label: t(context, 'settings.chat.reasoning'),
                  value: blob.boolField('showReasoningTraces') ?? false,
                  onChanged: (value) => controller.patchChatSetting('showReasoningTraces', value),
                ),
                SettingsToggleRow(
                  label: t(context, 'settings.chat.wrap'),
                  value: blob.boolField('codeBlockLineWrap') ?? false,
                  onChanged: (value) => controller.patchChatSetting('codeBlockLineWrap', value),
                ),
                SettingsToggleRow(
                  label: t(context, 'settings.chat.spellcheck'),
                  value: blob.boolField('inputSpellcheckEnabled') ?? false,
                  onChanged: (value) => controller.patchChatSetting('inputSpellcheckEnabled', value),
                ),
              ],
            ),
          ];
        },
      ),
    );
  }
}

class SessionsSettingsPage extends StatelessWidget {
  const SessionsSettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: t(context, 'settings.sessions.title'),
      child: _BlobSettingsBody(
        controller: controller,
        extra: () => controller.remoteSettings.loadAgents(),
        builder: (context, blob) {
          final agents = controller.remoteSettings.agents.value ?? const <SettingsNamedItem>[];
          return [
            SettingsGroup(
              label: t(context, 'settings.sessions.defaults'),
              children: [
                SettingsValueRow(
                  key: const Key('settings-sessions-default-model'),
                  label: t(context, 'settings.sessions.defaultModel'),
                  subtitle: blob.stringField('defaultModel') ?? t(context, 'settings.value.unset'),
                  onTap: () => showSettingsFieldsDialog(
                    context: context,
                    titleKey: 'settings.sessions.defaultModel',
                    fields: [
                      SettingsFieldSpec(
                        id: 'defaultModel',
                        labelKey: 'settings.sessions.defaultModel',
                        initial: blob.stringField('defaultModel'),
                      ),
                    ],
                    onSave: (values) => controller.patchChatSetting('defaultModel', values['defaultModel'] ?? ''),
                  ),
                ),
                SettingsValueRow(
                  key: const Key('settings-sessions-default-thinking'),
                  label: t(context, 'settings.sessions.defaultThinking'),
                  subtitle: blob.stringField('defaultVariant') ?? t(context, 'settings.value.unset'),
                  onTap: () => showSettingsFieldsDialog(
                    context: context,
                    titleKey: 'settings.sessions.defaultThinking',
                    fields: [
                      SettingsFieldSpec(
                        id: 'defaultVariant',
                        labelKey: 'settings.sessions.defaultThinking',
                        initial: blob.stringField('defaultVariant'),
                      ),
                    ],
                    onSave: (values) => controller.patchChatSetting('defaultVariant', values['defaultVariant'] ?? ''),
                  ),
                ),
                SettingsValueRow(
                  key: const Key('settings-sessions-default-agent'),
                  label: t(context, 'settings.sessions.defaultAgent'),
                  subtitle: blob.stringField('defaultAgent') ?? t(context, 'settings.value.unset'),
                  onTap: () => showSettingsFieldsDialog(
                    context: context,
                    titleKey: 'settings.sessions.defaultAgent',
                    fields: [
                      SettingsFieldSpec(
                        id: 'defaultAgent',
                        labelKey: 'settings.sessions.defaultAgent',
                        initial: blob.stringField('defaultAgent') ?? (agents.isEmpty ? '' : agents.first.id),
                      ),
                    ],
                    onSave: (values) => controller.patchChatSetting('defaultAgent', values['defaultAgent'] ?? ''),
                  ),
                ),
              ],
            ),
            SettingsGroup(
              label: t(context, 'settings.sessions.retention'),
              children: [
                SettingsToggleRow(
                  label: t(context, 'settings.sessions.autoDelete'),
                  value: blob.boolField('autoDeleteEnabled') ?? false,
                  onChanged: (value) => controller.patchChatSetting('autoDeleteEnabled', value),
                ),
                SettingsValueRow(
                  key: const Key('settings-sessions-days'),
                  label: t(context, 'settings.sessions.autoDeleteDays'),
                  subtitle: '${blob.numField('autoDeleteAfterDays') ?? 30}',
                  onTap: () => showSettingsFieldsDialog(
                    context: context,
                    titleKey: 'settings.sessions.autoDeleteDays',
                    fields: [
                      SettingsFieldSpec(
                        id: 'days',
                        labelKey: 'settings.sessions.autoDeleteDays',
                        initial: '${blob.numField('autoDeleteAfterDays') ?? 30}',
                      ),
                    ],
                    onSave: (values) {
                      final days = int.tryParse(values['days'] ?? '') ?? 30;
                      final clamped = days < 1 ? 1 : (days > 365 ? 365 : days);
                      return controller.patchChatSetting('autoDeleteAfterDays', clamped);
                    },
                  ),
                ),
                RadioListTile<String>(
                  key: const Key('settings-sessions-retention-archive'),
                  title: Text(t(context, 'settings.sessions.retentionAction.archive')),
                  value: 'archive',
                  groupValue: blob.stringField('sessionRetentionAction') ?? 'archive',
                  onChanged: (value) {
                    if (value != null) controller.patchChatSetting('sessionRetentionAction', value);
                  },
                ),
                RadioListTile<String>(
                  key: const Key('settings-sessions-retention-delete'),
                  title: Text(t(context, 'settings.sessions.retentionAction.delete')),
                  value: 'delete',
                  groupValue: blob.stringField('sessionRetentionAction') ?? 'archive',
                  onChanged: (value) {
                    if (value != null) controller.patchChatSetting('sessionRetentionAction', value);
                  },
                ),
              ],
            ),
          ];
        },
      ),
    );
  }
}

class SummaryAiSettingsPage extends StatelessWidget {
  const SummaryAiSettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: t(context, 'settings.summaryAi.title'),
      child: _BlobSettingsBody(
        controller: controller,
        extra: () => controller.remoteSettings.loadSummaryModels(),
        builder: (context, blob) {
          final models = controller.remoteSettings.summaryModels;
          final mode = blob.stringField('summaryModelMode') ?? 'provider';
          return [
            SettingsGroup(
              label: t(context, 'settings.summaryAi.model'),
              children: [
                RadioListTile<String>(
                  key: const Key('settings-summary-mode-provider'),
                  title: Text(t(context, 'settings.summaryAi.mode.provider')),
                  value: 'provider',
                  groupValue: mode,
                  onChanged: (value) {
                    if (value != null) controller.patchChatSetting('summaryModelMode', value);
                  },
                ),
                RadioListTile<String>(
                  key: const Key('settings-summary-mode-custom'),
                  title: Text(t(context, 'settings.summaryAi.mode.custom')),
                  value: 'custom',
                  groupValue: mode,
                  onChanged: (value) {
                    if (value != null) controller.patchChatSetting('summaryModelMode', value);
                  },
                ),
                if (mode == 'custom') ...[
                  SettingsValueRow(
                    key: const Key('settings-summary-custom-url'),
                    label: t(context, 'settings.summaryAi.customUrl'),
                    subtitle: blob.stringField('summaryCustomBaseURL') ?? t(context, 'settings.value.unset'),
                    onTap: () => showSettingsFieldsDialog(
                      context: context,
                      titleKey: 'settings.summaryAi.customUrl',
                      fields: [
                        SettingsFieldSpec(
                          id: 'url',
                          labelKey: 'settings.summaryAi.customUrl',
                          initial: blob.stringField('summaryCustomBaseURL'),
                        ),
                      ],
                      onSave: (values) => controller.patchChatSetting('summaryCustomBaseURL', values['url'] ?? ''),
                    ),
                  ),
                  SettingsValueRow(
                    key: const Key('settings-summary-custom-model'),
                    label: t(context, 'settings.summaryAi.modelId'),
                    subtitle: blob.stringField('summaryModelID') ?? t(context, 'settings.value.unset'),
                    onTap: () => showSettingsFieldsDialog(
                      context: context,
                      titleKey: 'settings.summaryAi.modelId',
                      fields: [
                        SettingsFieldSpec(
                          id: 'model',
                          labelKey: 'settings.summaryAi.modelId',
                          initial: blob.stringField('summaryModelID'),
                        ),
                      ],
                      onSave: (values) => controller.patchChatSetting('summaryModelID', values['model'] ?? ''),
                    ),
                  ),
                  SettingsValueRow(
                    key: const Key('settings-summary-custom-token'),
                    label: t(context, 'settings.summaryAi.customToken'),
                    subtitle: (blob.boolField('hasSummaryCustomAPIToken') ?? false)
                        ? t(context, 'settings.summaryAi.customTokenStored')
                        : t(context, 'settings.value.unset'),
                    onTap: () => showSettingsFieldsDialog(
                      context: context,
                      titleKey: 'settings.summaryAi.customToken',
                      fields: [
                        const SettingsFieldSpec(
                          id: 'token',
                          labelKey: 'settings.summaryAi.customToken',
                          obscure: true,
                        ),
                      ],
                      onSave: (values) => controller.patchChatSetting('summaryCustomAPIToken', values['token'] ?? ''),
                    ),
                  ),
                ],
              ],
            ),
            SettingsGroup(
              label: t(context, 'settings.summaryAi.callable'),
              children: [
                if (models.errorKey != null)
                  ListTile(
                    key: const Key('settings-resource-error'),
                    title: Text(t(context, models.errorKey!)),
                  )
                else if (models.loading && !models.hasValue)
                  const ListTile(title: LinearProgressIndicator())
                else if (models.value == null || models.value!.isEmpty)
                  ListTile(
                    key: const Key('settings-resource-empty'),
                    title: Text(t(context, 'settings.summaryAi.empty')),
                  )
                else
                  ...models.value!.map(
                    (item) => ListTile(
                      key: Key('settings-summary-model-${item.id}'),
                      title: Text(item.title),
                      subtitle: Text(item.subtitle ?? ''),
                      selected: blob.stringField('summaryProviderID') == item.subtitle &&
                          blob.stringField('summaryModelID') == item.title,
                      onTap: mode == 'provider'
                          ? () => controller.patchChatSetting('summaryProviderID', item.subtitle ?? '').then(
                                (_) => controller.patchChatSetting('summaryModelID', item.title),
                              )
                          : null,
                    ),
                  ),
              ],
            ),
            SettingsGroup(
              label: t(context, 'settings.summaryAi.prompts'),
              children: [
                SettingsValueRow(
                  key: const Key('settings-summary-commit-prompt'),
                  label: t(context, 'settings.summaryAi.commitPrompt'),
                  subtitle: blob.stringField('summaryCommitPrompt') ?? t(context, 'settings.value.unset'),
                  onTap: () => showSettingsFieldsDialog(
                    context: context,
                    titleKey: 'settings.summaryAi.commitPrompt',
                    fields: [
                      SettingsFieldSpec(
                        id: 'prompt',
                        labelKey: 'settings.summaryAi.commitPrompt',
                        initial: blob.stringField('summaryCommitPrompt'),
                        maxLines: 6,
                      ),
                    ],
                    onSave: (values) => controller.patchChatSetting('summaryCommitPrompt', values['prompt'] ?? ''),
                  ),
                ),
                SettingsValueRow(
                  key: const Key('settings-summary-title-prompt'),
                  label: t(context, 'settings.summaryAi.sessionTitlePrompt'),
                  subtitle: blob.stringField('summarySessionTitlePrompt') ?? t(context, 'settings.value.unset'),
                  onTap: () => showSettingsFieldsDialog(
                    context: context,
                    titleKey: 'settings.summaryAi.sessionTitlePrompt',
                    fields: [
                      SettingsFieldSpec(
                        id: 'prompt',
                        labelKey: 'settings.summaryAi.sessionTitlePrompt',
                        initial: blob.stringField('summarySessionTitlePrompt'),
                        maxLines: 6,
                      ),
                    ],
                    onSave: (values) => controller.patchChatSetting('summarySessionTitlePrompt', values['prompt'] ?? ''),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );
  }
}

class ProjectsSettingsPage extends StatelessWidget {
  const ProjectsSettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: t(context, 'settings.projects.title'),
      child: _BlobSettingsBody(
        controller: controller,
        builder: (context, blob) {
          final projects = blob.projects;
          return [
            SettingsGroup(
              label: t(context, 'settings.projects.title'),
              children: [
                if (projects.isEmpty)
                  ListTile(
                    key: const Key('settings-resource-empty'),
                    title: Text(t(context, 'settings.projects.empty')),
                  )
                else
                  ...projects.map(
                    (item) => SettingsValueRow(
                      key: Key('settings-item-${item.id}'),
                      label: item.title,
                      subtitle: item.subtitle,
                    ),
                  ),
              ],
            ),
          ];
        },
      ),
    );
  }
}

class GitSettingsPage extends StatelessWidget {
  const GitSettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: t(context, 'settings.git.title'),
      child: _BlobSettingsBody(
        controller: controller,
        extra: () => controller.remoteSettings.loadGitIdentities(),
        builder: (context, blob) {
          return [
            SettingsGroup(
              label: t(context, 'settings.git.prefs'),
              children: [
                SettingsToggleRow(
                  label: t(context, 'settings.git.gitmoji'),
                  value: blob.boolField('gitmojiEnabled') ?? false,
                  onChanged: (value) => controller.patchChatSetting('gitmojiEnabled', value),
                ),
                RadioListTile<String>(
                  key: const Key('settings-git-view-tree'),
                  title: Text(t(context, 'settings.git.changesView.tree')),
                  value: 'tree',
                  groupValue: blob.stringField('gitChangesViewMode') ?? 'tree',
                  onChanged: (value) {
                    if (value != null) controller.patchChatSetting('gitChangesViewMode', value);
                  },
                ),
                RadioListTile<String>(
                  key: const Key('settings-git-view-list'),
                  title: Text(t(context, 'settings.git.changesView.list')),
                  value: 'list',
                  groupValue: blob.stringField('gitChangesViewMode') ?? 'tree',
                  onChanged: (value) {
                    if (value != null) controller.patchChatSetting('gitChangesViewMode', value);
                  },
                ),
              ],
            ),
            SettingsGroup(
              label: t(context, 'settings.git.identities'),
              children: [
                SettingsNavRow(
                  key: const Key('settings-git-identities-open'),
                  label: t(context, 'settings.git.identities'),
                  subtitle: controller.remoteSettings.gitIdentities.value == null ||
                          controller.remoteSettings.gitIdentities.value!.isEmpty
                      ? t(context, 'settings.git.empty')
                      : '${controller.remoteSettings.gitIdentities.value!.length}',
                  onTap: () {
                    Navigator.of(context).push(
                      platformPageRoute<void>(
                        builder: (_) => AnimatedBuilder(
                          animation: controller,
                          builder: (context, _) => EntityEditorSettingsPage(
                            controller: controller,
                            kind: SettingsEditorKind.gitIdentities,
                            titleKey: 'settings.git.identities',
                            emptyKey: 'settings.git.empty',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ];
        },
      ),
    );
  }
}

class BehaviorSettingsPage extends StatelessWidget {
  const BehaviorSettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: t(context, 'settings.behavior.title'),
      child: _BlobSettingsBody(
        controller: controller,
        extra: () => controller.remoteSettings.loadAgentsMd(),
        builder: (context, blob) {
          final agentsMd = controller.remoteSettings.agentsMd;
          return [
            SettingsGroup(
              label: t(context, 'settings.behavior.style'),
              children: [
                SettingsToggleRow(
                  label: t(context, 'settings.behavior.styleEnabled'),
                  value: blob.boolField('responseStyleEnabled') ?? false,
                  onChanged: (value) => controller.patchChatSetting('responseStyleEnabled', value),
                ),
                ..._responseStylePresetIds.map(
                  (preset) => RadioListTile<String>(
                    key: Key('settings-behavior-preset-$preset'),
                    title: Text(t(context, 'settings.behavior.preset.$preset')),
                    value: preset,
                    groupValue: blob.stringField('responseStylePreset') ?? 'concise',
                    onChanged: (value) {
                      if (value != null) controller.patchChatSetting('responseStylePreset', value);
                    },
                  ),
                ),
                if ((blob.stringField('responseStylePreset') ?? 'concise') == 'custom')
                  SettingsValueRow(
                    key: const Key('settings-behavior-custom-instructions'),
                    label: t(context, 'settings.behavior.customInstructions'),
                    subtitle: blob.stringField('responseStyleCustomInstructions') ??
                        t(context, 'settings.value.unset'),
                    onTap: () => showSettingsFieldsDialog(
                      context: context,
                      titleKey: 'settings.behavior.customInstructions',
                      fields: [
                        SettingsFieldSpec(
                          id: 'custom',
                          labelKey: 'settings.behavior.customInstructions',
                          initial: blob.stringField('responseStyleCustomInstructions'),
                          maxLines: 6,
                        ),
                      ],
                      onSave: (values) => controller.patchChatSetting(
                        'responseStyleCustomInstructions',
                        values['custom'] ?? '',
                      ),
                    ),
                  ),
              ],
            ),
            SettingsGroup(
              label: t(context, 'settings.behavior.agentsMd'),
              children: [
                SettingsValueRow(
                  key: const Key('settings-behavior-agents-md'),
                  label: t(context, 'settings.behavior.agentsMd'),
                  subtitle: agentsMd.errorKey != null
                      ? t(context, agentsMd.errorKey!)
                      : (agentsMd.value == null || agentsMd.value!.trim().isEmpty)
                          ? t(context, 'settings.behavior.agentsMdEmpty')
                          : agentsMd.value,
                  onTap: agentsMd.errorKey != null
                      ? null
                      : () => showSettingsFieldsDialog(
                            context: context,
                            titleKey: 'settings.behavior.agentsMd',
                            fields: [
                              SettingsFieldSpec(
                                id: 'content',
                                labelKey: 'settings.behavior.agentsMd',
                                initial: agentsMd.value ?? '',
                                maxLines: 10,
                              ),
                            ],
                            onSave: (values) => controller.remoteSettings.saveAgentsMd(values['content'] ?? ''),
                          ),
                ),
              ],
            ),
          ];
        },
      ),
    );
  }
}

class RemoteListSettingsPage extends StatefulWidget {
  const RemoteListSettingsPage({
    super.key,
    required this.controller,
    required this.titleKey,
    required this.emptyKey,
    required this.resource,
    required this.load,
  });

  final AppController controller;
  final String titleKey;
  final String emptyKey;
  final SettingsResource<List<SettingsNamedItem>> Function() resource;
  final Future<void> Function() load;

  @override
  State<RemoteListSettingsPage> createState() => _RemoteListSettingsPageState();
}

class _RemoteListSettingsPageState extends State<RemoteListSettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: t(context, widget.titleKey),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _resourceGroup(
            context,
            label: t(context, widget.titleKey),
            resource: widget.resource(),
            emptyKey: widget.emptyKey,
          ),
        ],
      ),
    );
  }
}

class _BlobSettingsBody extends StatefulWidget {
  const _BlobSettingsBody({
    required this.controller,
    required this.builder,
    this.extra,
  });

  final AppController controller;
  final List<Widget> Function(BuildContext context, SettingsBlob blob) builder;
  final Future<void> Function()? extra;

  @override
  State<_BlobSettingsBody> createState() => _BlobSettingsBodyState();
}

class _BlobSettingsBodyState extends State<_BlobSettingsBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.controller.remoteSettings.blob.hasValue) {
        widget.controller.remoteSettings.loadBlob();
      }
      widget.extra?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final resource = widget.controller.remoteSettings.blob;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (resource.errorKey != null)
          SettingsGroup(
            label: t(context, 'settings.home.title'),
            children: [
              ListTile(
                key: const Key('settings-resource-error'),
                title: Text(t(context, resource.errorKey!)),
              ),
            ],
          ),
        if (resource.loading && !resource.hasValue)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (resource.value != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.builder(context, resource.value!),
          ),
      ],
    );
  }
}

Widget _resourceGroup(
  BuildContext context, {
  required String label,
  required SettingsResource<List<SettingsNamedItem>> resource,
  required String emptyKey,
}) {
  return SettingsGroup(
    label: label,
    children: [
      if (resource.errorKey != null)
        ListTile(
          key: const Key('settings-resource-error'),
          title: Text(t(context, resource.errorKey!)),
        )
      else if (resource.loading && !resource.hasValue)
        const ListTile(title: LinearProgressIndicator())
      else if (resource.value == null || resource.value!.isEmpty)
        ListTile(
          key: const Key('settings-resource-empty'),
          title: Text(t(context, emptyKey)),
        )
      else
        ...resource.value!.map(
          (item) => SettingsValueRow(
            key: Key('settings-item-${item.id}'),
            label: item.title,
            subtitle: item.subtitle,
          ),
        ),
    ],
  );
}
