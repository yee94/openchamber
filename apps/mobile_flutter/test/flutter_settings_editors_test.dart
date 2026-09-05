import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/data/settings_remote.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SecondaryChrome.debugReset);

  Future<({AppController controller, MemoryOpenChamberTransport transport})> connected() async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    return (controller: controller, transport: transport);
  }

  test('sessions / summary-ai blob fields PUT the settings merge', () async {
    final env = await connected();
    await env.controller.patchChatSetting('defaultModel', 'openai/gpt-4.1');
    await env.controller.patchChatSetting('defaultAgent', 'build');
    await env.controller.patchChatSetting('autoDeleteAfterDays', 14);
    await env.controller.patchChatSetting('sessionRetentionAction', 'delete');
    await env.controller.patchChatSetting('summaryModelMode', 'custom');
    await env.controller.patchChatSetting('summaryCustomBaseURL', 'https://example.test/v1');
    expect(env.transport.settings['defaultModel'], 'openai/gpt-4.1');
    expect(env.transport.settings['defaultAgent'], 'build');
    expect(env.transport.settings['autoDeleteAfterDays'], 14);
    expect(env.transport.settings['sessionRetentionAction'], 'delete');
    expect(env.transport.settings['summaryModelMode'], 'custom');
    expect(env.transport.settings['summaryCustomBaseURL'], 'https://example.test/v1');
  });

  test('git identities / snippets / magic-prompts / AGENTS.md use official write paths', () async {
    final env = await connected();
    final store = env.controller.remoteSettings;
    await store.createGitIdentity(name: 'Home', userName: 'Ada', userEmail: 'ada@example.com', authType: 'ssh');
    expect(
      env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.gitIdentities),
      isTrue,
    );
    await store.loadGitIdentities();
    final created = store.gitIdentities.value!.last;
    await store.updateGitIdentity(
      id: created.id,
      name: 'Home',
      userName: 'Ada',
      userEmail: 'ada@example.com',
      host: 'github.com',
    );
    expect(
      env.transport.calls.any((call) => call.method == 'PUT' && call.path == OpenChamberPaths.gitIdentity(created.id)),
      isTrue,
    );

    await store.createSnippet(name: 'repro2', content: 'steps', description: 'bug', aliases: const ['bug']);
    expect(
      env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.snippet('repro2')),
      isTrue,
    );
    await store.updateSnippet(name: 'repro2', content: 'updated', description: 'bug');
    expect(
      env.transport.calls.any((call) => call.method == 'PATCH' && call.path == OpenChamberPaths.snippet('repro2')),
      isTrue,
    );

    await store.saveMagicPrompt(id: 'session.summary.visible', text: 'Title this thread.');
    expect(
      env.transport.calls.any(
        (call) => call.method == 'PUT' && call.path == OpenChamberPaths.magicPrompt('session.summary.visible'),
      ),
      isTrue,
    );
    await store.resetMagicPrompt('session.summary.visible');
    expect(
      env.transport.calls.any(
        (call) => call.method == 'DELETE' && call.path == OpenChamberPaths.magicPrompt('session.summary.visible'),
      ),
      isTrue,
    );

    await store.saveAgentsMd('Prefer official APIs.');
    expect(
      env.transport.calls.any((call) => call.method == 'PUT' && call.path == OpenChamberPaths.behaviorAgentsMd),
      isTrue,
    );
    expect(store.agentsMd.value, 'Prefer official APIs.');
  });

  testWidgets('sessions and summary-ai pages expose editors, not display-only rows', (tester) async {
    final env = await connected();
    await tester.pumpWidget(OpenChamberApp(controller: env.controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-settings')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings-slug-sessions')));
    await tester.tap(find.byKey(const Key('settings-slug-sessions')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-sessions-default-model')), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-sessions-default-model')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings-editor-field-defaultModel')), 'anthropic/claude-opus-4');
    await tester.tap(find.byKey(const Key('settings-editor-save')));
    await tester.pumpAndSettle();
    expect(env.transport.settings['defaultModel'], 'anthropic/claude-opus-4');
    await tester.tap(find.byKey(const Key('settings-sessions-retention-delete')));
    await tester.pumpAndSettle();
    expect(env.transport.settings['sessionRetentionAction'], 'delete');
    await tester.tap(find.byKey(const Key('settings-back')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings-slug-summary-ai')));
    await tester.tap(find.byKey(const Key('settings-slug-summary-ai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-summary-mode-custom')));
    await tester.pumpAndSettle();
    expect(env.transport.settings['summaryModelMode'], 'custom');
    await tester.tap(find.byKey(const Key('settings-back')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings-slug-behavior')));
    await tester.tap(find.byKey(const Key('settings-slug-behavior')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-behavior-agents-md')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings-editor-field-content')), 'Keep changes small.');
    await tester.tap(find.byKey(const Key('settings-editor-save')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any((call) => call.method == 'PUT' && call.path == OpenChamberPaths.behaviorAgentsMd),
      isTrue,
    );
  });

  testWidgets('snippets and magic-prompts editors write official paths', (tester) async {
    final env = await connected();
    await tester.pumpWidget(OpenChamberApp(controller: env.controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-settings')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings-slug-snippets')));
    await tester.tap(find.byKey(const Key('settings-slug-snippets')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-item-repro')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings-editor-field-content')), 'Please include logs');
    await tester.tap(find.byKey(const Key('settings-editor-save')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any((call) => call.method == 'PATCH' && call.path == OpenChamberPaths.snippet('repro')),
      isTrue,
    );
    await tester.tap(find.byKey(const Key('settings-back')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings-slug-magic-prompts')));
    await tester.tap(find.byKey(const Key('settings-slug-magic-prompts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-editor-add')), findsNothing);
    await tester.tap(find.byKey(const Key('settings-item-git.commit.generate.visible')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings-editor-field-text')), 'One-line commit.');
    await tester.tap(find.byKey(const Key('settings-editor-save')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) => call.method == 'PUT' && call.path == OpenChamberPaths.magicPrompt('git.commit.generate.visible'),
      ),
      isTrue,
    );
  });

  test('parse helpers keep editor meta from official payloads', () {
    expect(parseSnippets(MemoryOpenChamberTransport.defaultTestSnippets).first.meta['content'], 'Please include a repro');
    final prompts = parseMagicPromptOverrides(MemoryOpenChamberTransport.defaultTestMagicPrompts);
    expect(prompts.first.id, 'git.commit.generate.visible');
    expect(prompts.first.meta['text'], isNotEmpty);
    expect(prompts.any((item) => item.id == 'session.summary.visible'), isTrue);
    expect(parseGitIdentities(MemoryOpenChamberTransport.defaultTestGitIdentities).first.meta['userEmail'], 'dev@example.com');
  });
}
