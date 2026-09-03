import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/features/chat/composer_bar.dart';
import 'package:openchamber/features/chat/composer_occupancy.dart';
import 'package:openchamber/l10n/app_strings.dart';

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
}
