import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/data/context_usage.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/secure_store.dart';

void main() {
  test('scanContextTokenBaseline uses the newest token-bearing assistant', () {
    final messages = [
      const ChatMessage(id: 'u1', body: 'hi', isUser: true),
      const ChatMessage(
        id: 'a1',
        body: 'old',
        isUser: false,
        tokens: ContextTokenRecord(input: 10, output: 10),
      ),
      const ChatMessage(
        id: 'a2',
        body: 'new',
        isUser: false,
        tokens: ContextTokenRecord(input: 1000, output: 2000, reasoning: 500, cacheRead: 100, cacheWrite: 50),
      ),
    ];
    final baseline = scanContextTokenBaseline(messages);
    expect(baseline?.messageId, 'a2');
    expect(baseline?.totalTokens, 3650);
  });

  test('compaction newer than the last tokens resets the baseline', () {
    final messages = [
      const ChatMessage(
        id: 'a1',
        body: 'old',
        isUser: false,
        tokens: ContextTokenRecord(input: 40, output: 10),
      ),
      const ChatMessage(
        id: 'u2',
        body: '',
        isUser: true,
        hasCompactionPart: true,
      ),
    ];
    expect(scanContextTokenBaseline(messages), isNull);
    expect(getLatestAssistantTotalTokens(messages), 0);
  });

  test('buildMobileContextDisplay hides when tokens or limit are missing', () {
    expect(buildMobileContextDisplay(totalTokens: 0, contextLimit: 200000), isNull);
    expect(buildMobileContextDisplay(totalTokens: 35000, contextLimit: 0), isNull);
    expect(buildMobileContextDisplay(totalTokens: 35000, contextLimit: 200000, isDraft: true), isNull);
    final display = buildMobileContextDisplay(totalTokens: 35000, contextLimit: 200000);
    expect(display?.percentage, closeTo(17.5, 0.01));
    expect(display?.tokensLabel, '35.0K/200.0K');
  });

  test('parseProviderContextLimits reads catalog limit.context', () {
    final limits = parseProviderContextLimits(MemoryOpenChamberTransport.defaultTestProviderCatalog);
    expect(limits['anthropic/claude-sonnet-4'], 200000);
    expect(resolveContextLimit(catalogLimits: limits, defaultModel: 'anthropic/claude-sonnet-4'), 200000);
  });

  test('ensureContextLimits loads catalog limits without inventing a stub percent', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.ensureContextLimits();
    expect(controller.contextLimits['anthropic/claude-sonnet-4'], 200000);
    expect(
      buildMobileContextDisplay(totalTokens: 0, contextLimit: controller.contextLimits['anthropic/claude-sonnet-4'] ?? 0),
      isNull,
    );
  });
}
