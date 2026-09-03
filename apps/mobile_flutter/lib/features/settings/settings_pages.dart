import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/app_version.dart';
import '../../data/settings_catalog.dart';
import '../../data/settings_remote.dart';
import '../../l10n/app_strings.dart';
import 'settings_primitives.dart';

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
        return RemoteListSettingsPage(
          controller: controller,
          titleKey: 'settings.providers.title',
          emptyKey: 'settings.providers.empty',
          resource: () => controller.remoteSettings.providers,
          load: controller.remoteSettings.loadProviders,
        );
      case 'agents':
        return RemoteListSettingsPage(
          controller: controller,
          titleKey: 'settings.agents.title',
          emptyKey: 'settings.agents.empty',
          resource: () => controller.remoteSettings.agents,
          load: controller.remoteSettings.loadAgents,
        );
      case 'assistants':
        return RemoteListSettingsPage(
          controller: controller,
          titleKey: 'settings.assistants.title',
          emptyKey: 'settings.assistants.empty',
          resource: () => controller.remoteSettings.assistants,
          load: controller.remoteSettings.loadAssistants,
        );
      case 'behavior':
        return BehaviorSettingsPage(controller: controller);
      case 'commands':
        return RemoteListSettingsPage(
          controller: controller,
          titleKey: 'settings.commands.title',
          emptyKey: 'settings.commands.empty',
          resource: () => controller.remoteSettings.commands,
          load: controller.remoteSettings.loadCommands,
        );
      case 'mcp':
        return RemoteListSettingsPage(
          controller: controller,
          titleKey: 'settings.mcp.title',
          emptyKey: 'settings.mcp.empty',
          resource: () => controller.remoteSettings.mcp,
          load: controller.remoteSettings.loadMcp,
        );
      case 'plugins':
        return RemoteListSettingsPage(
          controller: controller,
          titleKey: 'settings.plugins.title',
          emptyKey: 'settings.plugins.empty',
          resource: () => controller.remoteSettings.plugins,
          load: controller.remoteSettings.loadPlugins,
        );
      case 'magic-prompts':
        return RemoteListSettingsPage(
          controller: controller,
          titleKey: 'settings.magicPrompts.title',
          emptyKey: 'settings.magicPrompts.empty',
          resource: () => controller.remoteSettings.magicPrompts,
          load: controller.remoteSettings.loadMagicPrompts,
        );
      case 'snippets':
        return RemoteListSettingsPage(
          controller: controller,
          titleKey: 'settings.snippets.title',
          emptyKey: 'settings.snippets.empty',
          resource: () => controller.remoteSettings.snippets,
          load: controller.remoteSettings.loadSnippets,
        );
      case 'skills.installed':
        return RemoteListSettingsPage(
          controller: controller,
          titleKey: 'settings.skills.title',
          emptyKey: 'settings.skills.empty',
          resource: () => controller.remoteSettings.skills,
          load: controller.remoteSettings.loadSkills,
        );
      case 'usage':
        return RemoteListSettingsPage(
          controller: controller,
          titleKey: 'settings.usage.title',
          emptyKey: 'settings.usage.empty',
          resource: () => controller.remoteSettings.usage,
          load: controller.remoteSettings.loadUsage,
        );
      case 'voice':
        return VoiceSettingsPage(controller: controller);
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
                    subtitle: Text(instance.url),
                    trailing: active ? const Icon(Icons.check) : null,
                    onTap: () => controller.activateExisting(instance.id),
                  );
                }),
              ListTile(
                key: const Key('instances-add'),
                leading: const Icon(Icons.add),
                title: Text(t(context, 'settings.instances.add')),
                onTap: controller.switchToConnect,
              ),
              ListTile(
                key: const Key('instances-scan-qr'),
                leading: const Icon(Icons.qr_code_scanner),
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

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final instance = controller.activeInstance;
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
                  controller.instanceVersion ??
                      (instance == null ? t(context, 'settings.about.instanceUnknown') : instance.displayLabel),
                ),
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
        builder: (context, blob) {
          return [
            SettingsGroup(
              label: t(context, 'settings.sessions.defaults'),
              children: [
                SettingsValueRow(
                  label: t(context, 'settings.sessions.defaultModel'),
                  subtitle: blob.stringField('defaultModel') ?? t(context, 'settings.value.unset'),
                ),
                SettingsValueRow(
                  label: t(context, 'settings.sessions.defaultAgent'),
                  subtitle: blob.stringField('defaultAgent') ?? t(context, 'settings.value.unset'),
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
                  label: t(context, 'settings.sessions.autoDeleteDays'),
                  subtitle: '${blob.numField('autoDeleteAfterDays') ?? 30}',
                ),
                SettingsValueRow(
                  label: t(context, 'settings.sessions.retentionAction'),
                  subtitle: blob.stringField('sessionRetentionAction') ?? 'archive',
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
          return [
            SettingsGroup(
              label: t(context, 'settings.summaryAi.model'),
              children: [
                SettingsValueRow(
                  label: t(context, 'settings.summaryAi.mode'),
                  subtitle: blob.stringField('summaryModelMode') ?? 'provider',
                ),
                SettingsValueRow(
                  label: t(context, 'settings.summaryAi.provider'),
                  subtitle: blob.stringField('summaryProviderID') ?? t(context, 'settings.value.unset'),
                ),
                SettingsValueRow(
                  label: t(context, 'settings.summaryAi.modelId'),
                  subtitle: blob.stringField('summaryModelID') ?? t(context, 'settings.value.unset'),
                ),
              ],
            ),
            _resourceGroup(
              context,
              label: t(context, 'settings.summaryAi.callable'),
              resource: models,
              emptyKey: 'settings.summaryAi.empty',
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
                SettingsValueRow(
                  label: t(context, 'settings.git.changesView'),
                  subtitle: blob.stringField('gitChangesViewMode') ?? 'tree',
                ),
              ],
            ),
            _resourceGroup(
              context,
              label: t(context, 'settings.git.identities'),
              resource: controller.remoteSettings.gitIdentities,
              emptyKey: 'settings.git.empty',
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
                SettingsValueRow(
                  label: t(context, 'settings.behavior.preset'),
                  subtitle: blob.stringField('responseStylePreset') ?? t(context, 'settings.value.unset'),
                ),
              ],
            ),
            SettingsGroup(
              label: t(context, 'settings.behavior.agentsMd'),
              children: [
                if (agentsMd.errorKey != null)
                  ListTile(
                    key: const Key('settings-resource-error'),
                    title: Text(t(context, agentsMd.errorKey!)),
                  )
                else if (agentsMd.loading && !agentsMd.hasValue)
                  const ListTile(title: LinearProgressIndicator())
                else
                  ListTile(
                    key: const Key('settings-behavior-agents-md'),
                    title: Text(
                      (agentsMd.value == null || agentsMd.value!.trim().isEmpty)
                          ? t(context, 'settings.behavior.agentsMdEmpty')
                          : agentsMd.value!,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
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

class VoiceSettingsPage extends StatelessWidget {
  const VoiceSettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: t(context, 'settings.voice.title'),
      child: _BlobSettingsBody(
        controller: controller,
        extra: () => controller.remoteSettings.loadVoice(),
        builder: (context, blob) {
          return [
            SettingsGroup(
              label: t(context, 'settings.voice.provider'),
              children: [
                SettingsValueRow(
                  label: t(context, 'settings.voice.stt'),
                  subtitle: blob.stringField('sttProvider') ?? t(context, 'settings.value.unset'),
                ),
              ],
            ),
            _resourceGroup(
              context,
              label: t(context, 'settings.voice.models'),
              resource: controller.remoteSettings.voice,
              emptyKey: 'settings.voice.empty',
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
          ...widget.builder(context, resource.value!),
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
