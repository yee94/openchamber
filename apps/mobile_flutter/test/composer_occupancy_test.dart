import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/features/chat/composer_bar.dart';
import 'package:openchamber/features/chat/composer_occupancy.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/theme/ios_chrome.dart';

void main() {
  test('autocomplete stub pan-scrolls commands and files', () {
    expect(autocompleteStubFor('/st').map((item) => item.label), contains('/status'));
    expect(autocompleteStubFor('@RE').map((item) => item.label), contains('@README.md'));
    expect(autocompleteStubFor('#t').map((item) => item.label), contains('#todo'));
    expect(autocompleteStubFor('hello'), isEmpty);
  });

  testWidgets('composer uses Scaffold IME inset without a manual keyboard pad', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    final controller = TextEditingController();
    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings.of(AppStrings.en),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ComposerBar(controller: controller, onSend: () {}),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('composer-field')), findsOneWidget);
    expect(find.byKey(const Key('composer-send')), findsOneWidget);
    expect(find.byKey(const Key('composer-attach')), findsOneWidget);
    expect(find.byKey(const Key('composer-dictate')), findsNothing);
    expect(collapsedComposerOccupancy, 56);
  });

  testWidgets('slash @ # completion sits on a translucent frosted plate', (tester) async {
    final controller = TextEditingController(text: '/st');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings.of(AppStrings.en),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ComposerBar(controller: controller, onSend: () {}),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('composer-autocomplete')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('composer-autocomplete')), matching: find.byType(OcFrosted)),
      findsNothing,
    );
    expect(find.byType(OcFrosted), findsOneWidget);
    controller.text = '#bug';
    await tester.pump();
    expect(find.text('#bug'), findsWidgets);
  });

  test('list reserve uses consumed padding, not keyboard height', () {
    expect(
      composerListReserve(ios: true, paddingBottom: 34, showScrollToBottom: true),
      collapsedComposerOccupancy + 34,
    );
    expect(
      composerListReserve(ios: false, paddingBottom: 34, showScrollToBottom: true),
      collapsedComposerOccupancy + 34 + OcOptical.scrollFab + 6 + composerPillBottomPad,
    );
    expect(
      composerListReserve(ios: false, paddingBottom: 0, showScrollToBottom: false),
      collapsedComposerOccupancy + composerPillBottomPad,
    );
  });
}
