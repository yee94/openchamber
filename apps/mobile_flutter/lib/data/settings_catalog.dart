/// Canonical mobile Settings slugs from
/// `packages/ui/src/lib/settings/metadata.ts` `MOBILE_SETTINGS_PAGE_SLUGS`
/// on main (`3a164b6` / 1.19.3-beta.5). Keep this list identical.
const List<String> mobileSettingsPageSlugs = [
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
];

enum SettingsPageGroup {
  connection,
  personalization,
  workspace,
  opencode,
  content,
  system,
}

/// Group order from `SETTINGS_PAGE_GROUP_ORDER` on main.
const List<SettingsPageGroup> settingsPageGroupOrder = [
  SettingsPageGroup.connection,
  SettingsPageGroup.personalization,
  SettingsPageGroup.workspace,
  SettingsPageGroup.opencode,
  SettingsPageGroup.content,
  SettingsPageGroup.system,
];

class SettingsPageMeta {
  const SettingsPageMeta({
    required this.slug,
    required this.group,
    required this.titleKey,
    required this.keywords,
    this.descriptionKey,
    this.realEnough = false,
  });

  final String slug;
  final SettingsPageGroup group;
  final String titleKey;
  final String? descriptionKey;
  final List<String> keywords;

  /// Real-enough pages load official APIs (or local-only appearance).
  final bool realEnough;
}

/// Metadata aligned with `SETTINGS_PAGE_METADATA` + mobile titles.
const List<SettingsPageMeta> mobileSettingsPages = [
  SettingsPageMeta(
    slug: 'instances',
    group: SettingsPageGroup.connection,
    titleKey: 'settings.instances.title',
    descriptionKey: 'settings.instances.description',
    keywords: ['instance', 'instances', 'server', 'connection', 'switch', '实例', '服务器'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'appearance',
    group: SettingsPageGroup.personalization,
    titleKey: 'settings.appearance.title',
    descriptionKey: 'settings.appearance.description',
    keywords: ['theme', 'font', 'language', '外观', '主题', '语言'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'chat',
    group: SettingsPageGroup.personalization,
    titleKey: 'settings.chat.title',
    descriptionKey: 'settings.chat.description',
    keywords: ['tools', 'diff', 'reasoning', '聊天'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'notifications',
    group: SettingsPageGroup.personalization,
    titleKey: 'settings.notifications.title',
    descriptionKey: 'settings.notifications.description',
    keywords: ['alerts', 'native', 'summary', 'push', '通知'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'sessions',
    group: SettingsPageGroup.personalization,
    titleKey: 'settings.sessions.title',
    descriptionKey: 'settings.sessions.description',
    keywords: ['defaults', 'agent', 'model', '会话'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'summary-ai',
    group: SettingsPageGroup.personalization,
    titleKey: 'settings.summaryAi.title',
    descriptionKey: 'settings.summaryAi.description',
    keywords: ['summary', 'commit', 'session title', '摘要'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'projects',
    group: SettingsPageGroup.workspace,
    titleKey: 'settings.projects.title',
    descriptionKey: 'settings.projects.description',
    keywords: ['project', 'worktree', 'repo', '项目'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'git',
    group: SettingsPageGroup.workspace,
    titleKey: 'settings.git.title',
    descriptionKey: 'settings.git.description',
    keywords: ['git', 'github', 'ssh', 'identities'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'providers',
    group: SettingsPageGroup.opencode,
    titleKey: 'settings.providers.title',
    descriptionKey: 'settings.providers.description',
    keywords: ['provider', 'models', 'api key', '提供商'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'agents',
    group: SettingsPageGroup.opencode,
    titleKey: 'settings.agents.title',
    descriptionKey: 'settings.agents.description',
    keywords: ['agent', 'prompts', 'tools', 'permissions'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'assistants',
    group: SettingsPageGroup.opencode,
    titleKey: 'settings.assistants.title',
    descriptionKey: 'settings.assistants.description',
    keywords: ['assistant', 'sharing', '助理'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'behavior',
    group: SettingsPageGroup.opencode,
    titleKey: 'settings.behavior.title',
    descriptionKey: 'settings.behavior.description',
    keywords: ['behavior', 'agents.md', 'instructions', '行为'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'commands',
    group: SettingsPageGroup.opencode,
    titleKey: 'settings.commands.title',
    descriptionKey: 'settings.commands.description',
    keywords: ['command', 'slash', 'macros', '命令'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'mcp',
    group: SettingsPageGroup.opencode,
    titleKey: 'settings.mcp.title',
    descriptionKey: 'settings.mcp.description',
    keywords: ['mcp', 'servers', 'tools'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'plugins',
    group: SettingsPageGroup.opencode,
    titleKey: 'settings.plugins.title',
    descriptionKey: 'settings.plugins.description',
    keywords: ['plugin', 'extensions', '插件'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'magic-prompts',
    group: SettingsPageGroup.content,
    titleKey: 'settings.magicPrompts.title',
    descriptionKey: 'settings.magicPrompts.description',
    keywords: ['prompts', 'templates', 'review', '魔法提示词'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'snippets',
    group: SettingsPageGroup.content,
    titleKey: 'settings.snippets.title',
    descriptionKey: 'settings.snippets.description',
    keywords: ['prompt', 'templates', 'snippet', '片段'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'skills.installed',
    group: SettingsPageGroup.content,
    titleKey: 'settings.skills.title',
    descriptionKey: 'settings.skills.description',
    keywords: ['skill', 'skills', 'catalog', '技能'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'usage',
    group: SettingsPageGroup.system,
    titleKey: 'settings.usage.title',
    descriptionKey: 'settings.usage.description',
    keywords: ['quota', 'billing', 'tokens', '用量'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'voice',
    group: SettingsPageGroup.system,
    titleKey: 'settings.voice.title',
    descriptionKey: 'settings.voice.description',
    keywords: ['tts', 'speech', 'voice', '语音'],
    realEnough: true,
  ),
  SettingsPageMeta(
    slug: 'about',
    group: SettingsPageGroup.system,
    titleKey: 'settings.about.title',
    descriptionKey: 'settings.about.description',
    keywords: ['about', 'version', 'updates', '关于'],
    realEnough: true,
  ),
];

class SettingsGroupPages {
  const SettingsGroupPages({required this.group, required this.pages});
  final SettingsPageGroup group;
  final List<SettingsPageMeta> pages;
}

List<SettingsGroupPages> groupMobileSettingsPages([
  Iterable<SettingsPageMeta>? pages,
]) {
  final source = pages?.toList() ?? mobileSettingsPages;
  return settingsPageGroupOrder
      .map((group) {
        final groupPages = source.where((page) => page.group == group).toList();
        return SettingsGroupPages(group: group, pages: groupPages);
      })
      .where((entry) => entry.pages.isNotEmpty)
      .toList();
}

bool settingsPageMatchesQuery(SettingsPageMeta page, String query, String Function(String key) t) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final haystack = <String>[
    page.slug,
    t(page.titleKey),
    if (page.descriptionKey != null) t(page.descriptionKey!),
    ...page.keywords,
  ].join(' ').toLowerCase();
  return haystack.contains(q);
}

SettingsPageMeta? settingsPageBySlug(String slug) {
  for (final page in mobileSettingsPages) {
    if (page.slug == slug) return page;
  }
  return null;
}
