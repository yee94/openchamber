import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/home_session.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/data/session_swipe.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SecondaryChrome.debugReset);

  Future<({AppController controller, MemoryOpenChamberTransport transport})> connected({
    Object? assistants,
  }) async {
    final transport = MemoryOpenChamberTransport();
    if (assistants != null) transport.assistants = assistants;
    final controller = AppController(store: MemorySecureStore(), api: OpenChamberApi(transport: transport));
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    return (controller: controller, transport: transport);
  }

  Future<({AppController controller, MemoryOpenChamberTransport transport})> pumpApp(
    WidgetTester tester, {
    Object? assistants,
  }) async {
    final env = await connected(assistants: assistants);
    await tester.pumpWidget(OpenChamberApp(controller: env.controller));
    await tester.pumpAndSettle();
    return env;
  }

  HomeSessionRow row({
    required String id,
    required num updated,
  }) {
    return HomeSessionRow(
      id: id,
      title: id,
      projectLabel: 'openchamber',
      kind: HomeSessionKind.catalog,
      updated: updated,
    );
  }

  test('swipe geometry matches Cap 64px / 0.6 off-axis / composer and iOS back-edge gates', () {
    expect(
      evaluateSwipeDirection(startX: 100, startY: 40, endX: 36, endY: 40),
      SessionSwipeDirection.next,
    );
    expect(
      evaluateSwipeDirection(startX: 100, startY: 40, endX: 164, endY: 40),
      SessionSwipeDirection.prev,
    );
    expect(evaluateSwipeDirection(startX: 100, startY: 40, endX: 37, endY: 40), isNull);
    expect(evaluateSwipeDirection(startX: 100, startY: 40, endX: 20, endY: 80), isNull);
    expect(
      shouldStartSessionSwipe(onExplicitSurface: true),
      isTrue,
    );
    expect(
      shouldStartSessionSwipe(onExplicitSurface: true, composerActive: true),
      isFalse,
    );
    expect(
      shouldStartSessionSwipe(onExplicitSurface: true, withinNativeBackEdge: true),
      isFalse,
    );
    expect(
      evaluateSwipeProgress(
        startX: 100,
        startY: 40,
        endX: 93,
        endY: 40,
        canPrev: true,
        canNext: true,
      ),
      isNull,
    );
    final progress = evaluateSwipeProgress(
      startX: 100,
      startY: 40,
      endX: 36,
      endY: 40,
      canPrev: true,
      canNext: true,
    );
    expect(progress?.direction, SessionSwipeDirection.next);
    expect(progress?.canSwitch, isTrue);
    expect(progress?.progress, 1);
  });

  test('swipe neighbors walk newest-first top-level sessions', () {
    final sessions = [
      row(id: 'old', updated: 10),
      row(id: 'mid', updated: 20),
      row(id: 'new', updated: 30),
      HomeSessionRow.draft(directory: '/workspace/openchamber'),
    ];
    expect(
      orderedTopLevelSessionsForSwipe(sessions).map((item) => item.id).toList(),
      ['new', 'mid', 'old'],
    );
    expect(
      swipeNeighbor(sessions: sessions, currentId: 'mid', direction: SessionSwipeDirection.next)?.id,
      'old',
    );
    expect(
      swipeNeighbor(sessions: sessions, currentId: 'mid', direction: SessionSwipeDirection.prev)?.id,
      'new',
    );
    expect(swipeNeighbor(sessions: sessions, currentId: 'old', direction: SessionSwipeDirection.next), isNull);
    expect(swipeNeighbor(sessions: sessions, currentId: '', direction: SessionSwipeDirection.next), isNull);
  });

  test('openNewSessionDraft does not POST /api/session', () async {
    final env = await connected();
    final draft = env.controller.openNewSessionDraft(directory: '/workspace/openchamber');
    expect(draft, isNotNull);
    expect(draft!.isDraft, isTrue);
    expect(draft.directory, '/workspace/openchamber');
    expect(
      env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionCreate),
      isFalse,
    );
  });

  test('materializeDraft POSTs /api/session once', () async {
    final env = await connected();
    final draft = env.controller.openNewSessionDraft(directory: '/workspace/openchamber')!;
    final created = await env.controller.materializeDraft(draft);
    expect(created, isNotNull);
    expect(created!.isDraft, isFalse);
    expect(created.id, startsWith('ses_flutter_'));
    expect(
      env.transport.calls.where((call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionCreate).length,
      1,
    );
    expect(await env.controller.materializeDraft(created), created);
  });

  testWidgets('first draft send creates the session then prompt_async', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('home-session-sess-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-overflow-newSession')));
    await tester.pumpAndSettle();
    expect(find.text('New session'), findsWidgets);
    expect(
      env.transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionCreate),
      isFalse,
    );
    await tester.enterText(find.byKey(const Key('composer-field')), 'hello draft');
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pumpAndSettle();
    final createIndex = env.transport.calls.indexWhere(
      (call) => call.method == 'POST' && call.path == OpenChamberPaths.sessionCreate,
    );
    final promptIndex = env.transport.calls.indexWhere((call) => call.path.endsWith('/prompt_async'));
    expect(createIndex, isNonNegative);
    expect(promptIndex, greaterThan(createIndex));
    expect(env.transport.sentPrompts, contains('hello draft'));
    expect(env.transport.calls[createIndex].query['directory'], '/workspace/openchamber');
  });

  testWidgets('empty assistants onboarding opens Settings create form', (tester) async {
    final env = await pumpApp(
      tester,
      assistants: const {
        'revision': 1,
        'enabled': true,
        'assistants': <Object?>[],
      },
    );
    await tester.tap(find.byKey(const Key('tab-assistant')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-onboarding')), findsOneWidget);
    expect(find.text('Create your first assistant'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-onboarding-create')));
    await tester.pumpAndSettle();
    expect(env.controller.pendingSettingsSlug, isNull);
    expect(find.byKey(const Key('settings-editor-field-name')), findsOneWidget);
    expect(find.text('Create'), findsWidgets);
  });
}
