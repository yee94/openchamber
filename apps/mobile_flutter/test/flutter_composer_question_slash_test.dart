import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/composer_session_pick.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/local_chat_commands.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/question_request.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SecondaryChrome.debugReset);

  Future<({AppController controller, MemoryOpenChamberTransport transport})> pumpApp(
    WidgetTester tester, {
    List<Object?> questions = const [],
  }) async {
    final transport = MemoryOpenChamberTransport()..questions = questions;
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    return (controller: controller, transport: transport);
  }

  test('slash classifier matches Cap immediate and model commands', () {
    expect(getLocalChatCommand('/compact'), 'compact');
    expect(getLocalChatCommand('/undo'), 'undo');
    expect(getLocalChatCommand('/redo'), 'redo');
    expect(getLocalChatCommand('/model'), 'model');
    expect(consumesImmediateCommandText('/compact'), isTrue);
    expect(consumesImmediateCommandText('/model'), isFalse);
    expect(isModelSlashCommand('/model extra'), isTrue);
    expect(shouldSubmitCommandOnSelection('/compact'), isTrue);
    expect(shouldSubmitCommandOnSelection('/review'), isFalse);
  });

  test('parseComposerModelOptions reads official catalog providers.models', () {
    final models = parseComposerModelOptions(MemoryOpenChamberTransport.defaultTestProviderCatalog);
    expect(models.map((item) => item.id), containsAll(['anthropic/claude-sonnet-4', 'openai/gpt-5']));
  });

  test('parseQuestionList reads official QuestionRequest rows', () {
    final parsed = parseQuestionList([
      {
        'id': 'q-1',
        'sessionID': 'sess-catalog',
        'questions': [
          {
            'question': 'Ship the change?',
            'header': 'Release',
            'options': [
              {'label': 'Yes', 'description': 'Ship it'},
              {'label': 'No', 'description': 'Hold'},
            ],
          },
        ],
      },
    ], sessionId: 'sess-catalog');
    expect(parsed.single.id, 'q-1');
    expect(parsed.single.questions.single.options.map((item) => item.label), ['Yes', 'No']);
  });

  test('sendPrompt includes official model and agent on prompt_async', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.refreshSessions();
    final session = controller.sessions.firstWhere((row) => row.id == 'sess-catalog');
    controller.setSessionPick(
      session.id,
      const ComposerSessionPick(providerId: 'openai', modelId: 'gpt-5', agent: 'plan', variant: 'high'),
    );
    await controller.sendPrompt(session: session, messageId: 'msg-1', text: 'hello from flutter');
    final prompt = transport.calls.lastWhere((call) => call.path.endsWith('/prompt_async'));
    expect(prompt.body?['model'], {'providerID': 'openai', 'modelID': 'gpt-5'});
    expect(prompt.body?['agent'], 'plan');
    expect(prompt.body?['variant'], 'high');
    expect(transport.sentPrompts, ['hello from flutter']);
  });

  test('summarize and unrevert hit official session paths', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.refreshSessions();
    final session = controller.sessions.firstWhere((row) => row.id == 'sess-catalog');
    expect(
      await controller.summarizeSession(session: session, providerId: 'anthropic', modelId: 'claude-sonnet-4'),
      isTrue,
    );
    expect(
      transport.calls.any(
        (call) =>
            call.method == 'POST' &&
            call.path == OpenChamberPaths.sessionSummarize('sess-catalog') &&
            call.body?['providerID'] == 'anthropic' &&
            call.body?['modelID'] == 'claude-sonnet-4',
      ),
      isTrue,
    );
    expect(await controller.unrevertSession(session: session), isTrue);
    expect(
      transport.calls.any(
        (call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionUnrevert('sess-catalog'),
      ),
      isTrue,
    );
  });

  test('question reply and reject use official /api/question paths', () async {
    final transport = MemoryOpenChamberTransport()
      ..questions = [
        {
          'id': 'q-1',
          'sessionID': 'sess-catalog',
          'questions': [
            {
              'question': 'Ship the change?',
              'header': 'Release',
              'options': [
                {'label': 'Yes'},
              ],
            },
          ],
        },
      ];
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    final session = HomeSessionRow(
      id: 'sess-catalog',
      title: 'Catalog',
      projectLabel: 'openchamber',
      kind: HomeSessionKind.catalog,
      directory: '/workspace/openchamber',
    );
    await controller.replyToQuestion(session: session, requestId: 'q-1', answers: const [
      ['Yes'],
    ]);
    final reply = transport.calls.lastWhere(
      (call) => call.method == 'POST' && call.path == OpenChamberPaths.questionReply('q-1'),
    );
    expect(reply.body?['answers'], [
      ['Yes'],
    ]);
    transport.questions = [
      {'id': 'q-2', 'sessionID': 'sess-catalog', 'questions': const []},
    ];
    await controller.rejectQuestion(session: session, requestId: 'q-2');
    expect(
      transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.questionReject('q-2')),
      isTrue,
    );
  });

  testWidgets('composer model chip POSTs the picked model on send', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer-model')), findsOneWidget);
    await tester.tap(find.byKey(const Key('composer-model')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer-model-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('composer-pick-openai/gpt-5')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('composer-field')), 'use gpt');
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pumpAndSettle();
    final prompt = env.transport.calls.lastWhere((call) => call.path.endsWith('/prompt_async'));
    expect(prompt.body?['model'], {'providerID': 'openai', 'modelID': 'gpt-5'});
    expect(prompt.body?['agent'], 'build');
  });

  testWidgets('/compact send hits summarize and does not prompt_async the token', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    env.transport.calls.removeWhere((call) => call.path.contains('prompt_async'));
    await tester.enterText(find.byKey(const Key('composer-field')), '/compact');
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pumpAndSettle();
    expect(env.transport.calls.any((call) => call.path.contains('prompt_async')), isFalse);
    expect(
      env.transport.calls.any(
        (call) =>
            call.method == 'POST' &&
            call.path == OpenChamberPaths.sessionSummarize('sess-catalog') &&
            call.body?['providerID'] == 'anthropic' &&
            call.body?['modelID'] == 'claude-sonnet-4',
      ),
      isTrue,
    );
  });

  testWidgets('/undo send POSTs session.revert for the last user message', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('composer-field')), '/undo');
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pumpAndSettle();
    expect(
      env.transport.calls.any(
        (call) =>
            call.method == 'POST' &&
            call.path == OpenChamberPaths.sessionRevert('sess-catalog') &&
            call.body?['messageID'] == 'm3',
      ),
      isTrue,
    );
    expect(env.transport.sentPrompts, isNot(contains('/undo')));
  });

  testWidgets('pending question card replies with official answers payload', (tester) async {
    final env = await pumpApp(
      tester,
      questions: [
        {
          'id': 'q-1',
          'sessionID': 'sess-catalog',
          'questions': [
            {
              'question': 'Ship the change?',
              'header': 'Release',
              'options': [
                {'label': 'Yes', 'description': 'Ship it'},
                {'label': 'No', 'description': 'Hold'},
              ],
            },
          ],
        },
      ],
    );
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-question-q-1')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('chat-question-q-1-option-0-Yes')));
    await tester.tap(find.byKey(const Key('chat-question-q-1-option-0-Yes')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('chat-permission-question-submit-q-1')));
    await tester.tap(find.byKey(const Key('chat-permission-question-submit-q-1')));
    await tester.pumpAndSettle();
    final reply = env.transport.calls.lastWhere(
      (call) => call.method == 'POST' && call.path == OpenChamberPaths.questionReply('q-1'),
    );
    expect(reply.body?['answers'], [
      ['Yes'],
    ]);
  });
}
