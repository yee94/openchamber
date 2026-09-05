import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/chat/chat_screen.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';
import 'package:openchamber/native/live_activity_controller.dart';
import 'package:openchamber/native/push_registration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('push data prefers url/deeplink then sessionId', () {
    expect(
      sessionDeepLinkFromPushData({'url': 'openchamber://session/sess-a'}),
      'openchamber://session/sess-a',
    );
    expect(
      sessionDeepLinkFromPushData({'deeplink': 'openchamber://session/sess-b'}),
      'openchamber://session/sess-b',
    );
    expect(
      sessionDeepLinkFromPushData({'sessionId': 'sess-c'}),
      'openchamber://session/sess-c',
    );
    expect(
      sessionDeepLinkFromPushData({'sessionID': 'sess-d'}),
      'openchamber://session/sess-d',
    );
    expect(sessionDeepLinkFromPushData({'sessionId': liveActivityCatalogId}), isNull);
    expect(sessionDeepLinkFromPushData({}), isNull);
    expect(
      sessionDeepLinkFromPushArguments({'sessionId': 'sess-catalog'}),
      'openchamber://session/sess-catalog',
    );
  });

  testWidgets('notification open routes sessionId like Live Activity', (tester) async {
    SecondaryChrome.debugReset();
    final controller = AppController(store: MemorySecureStore());
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pump();

    final uri = sessionDeepLinkFromPushData({'sessionId': 'sess-catalog'});
    expect(uri, 'openchamber://session/sess-catalog');
    await controller.handleIncomingLink(uri!);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('New Session'), findsWidgets);
  });
}
