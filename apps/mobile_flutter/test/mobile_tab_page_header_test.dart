import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/mobile/mobile_surface.dart';
import 'package:openchamber/mobile/mobile_tab_page_header.dart';
import 'package:openchamber/theme/app_theme.dart';
import 'package:openchamber/theme/ios_chrome.dart';

void main() {
  testWidgets('root-tab header keeps a fixed layout height while the title scales', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 47 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings.of(AppStrings.zhCN),
        child: MaterialApp(
          theme: materialTheme(Brightness.light),
          home: MobileTabPageScaffold(
            title: '项目',
            children: [
              for (var i = 0; i < 20; i += 1)
                SizedBox(height: 80, child: Text('row-$i')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MobileTabPageHeader), findsOneWidget);
    expect(find.byKey(const Key('mobile-tab-page-header-spacer')), findsOneWidget);
    expect(find.byKey(const Key('projects-attention-strip')), findsNothing);

    final expanded = tester.getSize(find.byKey(const Key('mobile-tab-page-header')));
    expect(expanded.height, 47 + OcOptical.collapsingTopPad + OcOptical.collapsingActionSize);
    expect(tester.getSize(find.byKey(const Key('mobile-tab-page-header-spacer'))).height, 10);

    final titleAtRest = tester.widget<Transform>(find.byKey(const Key('mobile-tab-page-title')));
    expect(titleAtRest.transform.getMaxScaleOnAxis(), closeTo(1, 0.001));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -80));
    await tester.pumpAndSettle();

    final collapsed = tester.getSize(find.byKey(const Key('mobile-tab-page-header')));
    expect(collapsed.height, expanded.height);

    final titleCollapsed = tester.widget<Transform>(find.byKey(const Key('mobile-tab-page-title')));
    expect(titleCollapsed.transform.getMaxScaleOnAxis(), closeTo(0.625, 0.02));
  });
}
