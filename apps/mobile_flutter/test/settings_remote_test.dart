import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/settings_remote.dart';

void main() {
  test('settings and catalog reads use official OpenChamber paths', () async {
    final transport = MemoryOpenChamberTransport();
    final api = OpenChamberApi(transport: transport);
    final base = Uri.parse('http://192.168.1.74:2606');

    await api.getConfigSettings(base: base, bearer: 'tok');
    await api.putConfigSettings(base: base, bearer: 'tok', changes: {'chatRenderMode': 'live'});
    await api.getProviderCatalog(base: base, bearer: 'tok');
    await api.getAgents(base: base, bearer: 'tok');
    await api.getAssistantsSnapshot(base: base, bearer: 'tok');
    await api.getCommandCatalog(base: base, bearer: 'tok');
    await api.getMcpConfigs(base: base, bearer: 'tok');
    await api.getPlugins(base: base, bearer: 'tok');
    await api.getInstalledSkills(base: base, bearer: 'tok');
    await api.getSnippets(base: base, bearer: 'tok');
    await api.getMagicPrompts(base: base, bearer: 'tok');
    await api.getGitIdentities(base: base, bearer: 'tok');
    await api.getBehaviorAgentsMd(base: base, bearer: 'tok');
    await api.getDictationStatus(base: base, bearer: 'tok');
    await api.getTtsStatus(base: base, bearer: 'tok');
    await api.getSmallModel(base: base, bearer: 'tok');
    await api.getQuota(base: base, bearer: 'tok', providerId: 'openai');

    expect(transport.calls.map((call) => '${call.method} ${call.path}').toList(), [
      'GET ${OpenChamberPaths.configSettings}',
      'PUT ${OpenChamberPaths.configSettings}',
      'GET ${OpenChamberPaths.providerCatalog}',
      'GET ${OpenChamberPaths.agents}',
      'GET ${OpenChamberPaths.assistantsSnapshot}',
      'POST ${OpenChamberPaths.commandsMetadata}',
      'GET ${OpenChamberPaths.mcp}',
      'GET ${OpenChamberPaths.plugins}',
      'GET ${OpenChamberPaths.skills}',
      'GET ${OpenChamberPaths.snippets}',
      'GET ${OpenChamberPaths.magicPrompts}',
      'GET ${OpenChamberPaths.gitIdentities}',
      'GET ${OpenChamberPaths.behaviorAgentsMd}',
      'GET ${OpenChamberPaths.dictationStatus}',
      'GET ${OpenChamberPaths.ttsStatus}',
      'GET ${OpenChamberPaths.smallModel}',
      'GET ${OpenChamberPaths.quota('openai')}',
    ]);
    expect(transport.calls.firstWhere((call) => call.path == OpenChamberPaths.commandsMetadata).body, {'catalog': true});
    expect(transport.calls.firstWhere((call) => call.path == OpenChamberPaths.skills).query['summary'], 'true');
    expect(transport.settings['chatRenderMode'], 'live');
  });

  test('provider catalog failure does not become an empty success', () async {
    final transport = MemoryOpenChamberTransport()..catalogStatus = 503;
    final store = SettingsRemoteStore(
      api: OpenChamberApi(transport: transport),
      base: () => Uri.parse('http://192.168.1.74:2606'),
      bearer: () => 'tok',
    );
    store.providers = const SettingsResource(
      value: [SettingsNamedItem(id: 'kept', title: 'Kept')],
    );

    await store.loadProviders();

    expect(store.providers.errorKey, 'settings.error.loadFailed');
    expect(store.providers.value?.single.id, 'kept');
  });

  test('parse helpers keep list identity fields from official payloads', () {
    expect(parseProviderCatalog(MemoryOpenChamberTransport.defaultTestProviderCatalog).map((item) => item.id), [
      'anthropic',
      'openai',
    ]);
    expect(parseAgentList(MemoryOpenChamberTransport.defaultTestAgents).first.id, 'build');
    expect(parseAssistantSnapshot(MemoryOpenChamberTransport.defaultTestAssistants).first.title, 'Home');
    expect(parseCommandCatalog(MemoryOpenChamberTransport.defaultTestCommands).first.id, 'review');
    expect(parseMcpServers(MemoryOpenChamberTransport.defaultTestMcp).first.id, 'filesystem');
    expect(parsePluginEntries(MemoryOpenChamberTransport.defaultTestPlugins).first.title, 'opencode-plugin/example');
    expect(parseSkills(MemoryOpenChamberTransport.defaultTestSkills).first.id, 'release-notes');
    expect(parseSnippets(MemoryOpenChamberTransport.defaultTestSnippets).first.id, 'repro');
    expect(parseMagicPromptOverrides(MemoryOpenChamberTransport.defaultTestMagicPrompts).first.id, 'git.commit.generate.visible');
    expect(parseGitIdentities(MemoryOpenChamberTransport.defaultTestGitIdentities).first.subtitle, 'dev@example.com');
    expect(parseQuotaRow('openai', MemoryOpenChamberTransport.defaultTestQuotas['openai']).subtitle, '12%');
  });
}
