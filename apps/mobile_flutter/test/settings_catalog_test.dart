import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/settings_catalog.dart';
import 'package:openchamber/l10n/app_strings.dart';

void main() {
  test('covers every official MOBILE_SETTINGS_PAGE_SLUGS entry', () {
    expect(mobileSettingsPageSlugs, [
      'instances',
      'appearance',
      'chat',
      'notifications',
      'sessions',
      'summary-ai',
      'projects',
      'git',
      'providers',
      'agents',
      'assistants',
      'behavior',
      'commands',
      'mcp',
      'plugins',
      'magic-prompts',
      'snippets',
      'skills.installed',
      'usage',
      'voice',
      'about',
    ]);
    expect(mobileSettingsPages.map((page) => page.slug).toList(), mobileSettingsPageSlugs);
  });

  test('does not include the deleted iosNativeUi WebView-era setting', () {
    final haystack = mobileSettingsPages.expand((page) => page.keywords).join(' ');
    expect(haystack.contains('iosNativeUi'), isFalse);
    expect(mobileSettingsPageSlugs.contains('iosNativeUi'), isFalse);
  });

  test('search filters by title, slug, and keywords', () {
    final strings = AppStrings.of(AppStrings.en);
    final hits = mobileSettingsPages
        .where((page) => settingsPageMatchesQuery(page, 'switch', strings.t))
        .map((page) => page.slug)
        .toList();
    expect(hits, contains('instances'));
    expect(hits, isNot(contains('voice')));
  });

  test('groups follow official SETTINGS_PAGE_GROUP_ORDER', () {
    final groups = groupMobileSettingsPages();
    expect(groups.map((entry) => entry.group).toList(), [
      SettingsPageGroup.connection,
      SettingsPageGroup.personalization,
      SettingsPageGroup.workspace,
      SettingsPageGroup.opencode,
      SettingsPageGroup.content,
      SettingsPageGroup.system,
    ]);
    expect(groups.first.pages.single.slug, 'instances');
  });
}
