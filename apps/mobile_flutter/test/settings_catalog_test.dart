import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/settings_catalog.dart';
import 'package:openchamber/l10n/app_strings.dart';

void main() {
  test('covers Flutter settings slugs and omits voice', () {
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
      'about',
    ]);
    expect(mobileSettingsPages.map((page) => page.slug).toList(), mobileSettingsPageSlugs);
    expect(mobileSettingsPageSlugs, isNot(contains('voice')));
    expect(mobileSettingsPages.any((page) => page.slug == 'voice'), isFalse);
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

  test('voice query has no settings page to open', () {
    final strings = AppStrings.of(AppStrings.en);
    expect(
      mobileSettingsPages.where((page) => settingsPageMatchesQuery(page, 'voice', strings.t)),
      isEmpty,
    );
    expect(
      mobileSettingsPages.where((page) => settingsPageMatchesQuery(page, 'tts', strings.t)),
      isEmpty,
    );
  });

  test('required settings slugs are marked real-enough', () {
    const required = {
      'chat',
      'notifications',
      'sessions',
      'providers',
      'agents',
      'assistants',
      'mcp',
      'plugins',
      'skills.installed',
      'usage',
      'git',
      'projects',
      'behavior',
      'commands',
      'magic-prompts',
      'snippets',
      'summary-ai',
    };
    for (final slug in required) {
      expect(settingsPageBySlug(slug)?.realEnough, isTrue, reason: slug);
    }
    expect(settingsPageBySlug('voice'), isNull);
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
    expect(groups.last.pages.map((page) => page.slug), ['usage', 'about']);
  });
}
