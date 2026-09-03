import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/features/chat/composer_bar.dart';
import 'package:openchamber/features/chat/composer_occupancy.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/theme/ios_hero.dart';

void main() {
  test('autocomplete stub pan-scrolls commands and files', () {
    expect(autocompleteStubFor('/st').map((item) => item.label), contains('/status'));
    expect(autocompleteStubFor('@RE').map((item) => item.label), contains('@README.md'));
    expect(autocompleteStubFor('hello'), isEmpty);
  });

  testWidgets('Android composer sits on a solid viewInset surface', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    final controller = TextEditingController();
    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings.of(AppStrings.en),
        child: MaterialApp(
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 320),
                child: ComposerBar(controller: controller, onSend: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('composer-field')), findsOneWidget);
    expect(find.byKey(const Key('composer-send')), findsOneWidget);
    expect(collapsedComposerOccupancy, 56);
  });

  test('list reserve clears the Android composer stack including the scroll FAB', () {
    expect(
      composerListReserve(ios: true, viewBottom: 34, insetBottom: 0, showScrollToBottom: true),
      collapsedComposerOccupancy + 34,
    );
    expect(
      composerListReserve(ios: false, viewBottom: 34, insetBottom: 0, showScrollToBottom: true),
      collapsedComposerOccupancy + 34 + OcOptical.scrollFab + 6 + composerPillBottomPad,
    );
    expect(
      composerListReserve(ios: false, viewBottom: 34, insetBottom: 320, showScrollToBottom: false),
      collapsedComposerOccupancy + composerPillBottomPad,
    );
  });
}
