import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/app_version.dart';
import '../../data/settings_catalog.dart';
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
    return SettingsPageScaffold(
      title: t(context, 'settings.notifications.title'),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
