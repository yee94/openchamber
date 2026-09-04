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
    tester.view.viewPadding = const FakeViewPadding(top: 47 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

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
    expect(find.byKey(const Key('mobile-tab-page-header-slot')), findsOneWidget);
    expect(find.byKey(const Key('mobile-tab-page-header-spacer')), findsOneWidget);
    expect(find.byKey(const Key('projects-attention-strip')), findsNothing);

    final expanded = tester.getSize(find.byKey(const Key('mobile-tab-page-header')));
    expect(expanded.height, 47 + OcOptical.collapsingTopPad + OcOptical.collapsingActionSize);
    expect(
      tester.getSize(find.byKey(const Key('mobile-tab-page-header-slot'))).height,
      expanded.height,
    );
    expect(tester.getSize(find.byKey(const Key('mobile-tab-page-header-spacer'))).height, 10);

    final headerRect = tester.getRect(find.byType(MobileTabPageHeader));
    final rowAtRest = tester.getTopLeft(find.text('row-0')).dy;
    expect(rowAtRest, greaterThanOrEqualTo(headerRect.bottom + OcOptical.collapsingExpandShift - 0.5));

    final titleAtRest = tester.widget<Transform>(find.byKey(const Key('mobile-tab-page-title')));
    expect(titleAtRest.transform.storage[0], closeTo(1, 0.001));

    final view = tester.widget<SingleChildScrollView>(find.byKey(const Key('mobile-tab-page-scroll')));
    view.controller!.jumpTo(80);
    await tester.pump();

    final collapsed = tester.getSize(find.byKey(const Key('mobile-tab-page-header')));
    expect(collapsed.height, expanded.height);

    final header = tester.widget<MobileTabPageHeader>(find.byType(MobileTabPageHeader));
    expect(header.collapse, closeTo(1, 0.02));
    final titleCollapsed = tester.widget<Transform>(find.byKey(const Key('mobile-tab-page-title')));
    expect(titleCollapsed.transform.storage[0], closeTo(0.625, 0.02));

    final headerBottom = tester.getBottomLeft(find.byType(MobileTabPageHeader)).dy;
    final rowTop = tester.getTopLeft(find.text('row-0')).dy;
    expect(rowTop, lessThan(headerBottom));
  });

  testWidgets('detail nav consumes viewPadding.top and keeps a 56px band', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 47 * 3, left: 0, right: 0);
    tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, left: 12 * 3, right: 8 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings.of(AppStrings.zhCN),
        child: MaterialApp(
          theme: materialTheme(Brightness.light),
          home: const Scaffold(
            body: PushedNavBar(title: '会话标题', leadingKey: Key('chat-back')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(PushedNavBar)).height, 47 + 56);
    expect(tester.getSize(find.byKey(const Key('chat-back'))).height, OcOptical.chatChip);
    expect(tester.getTopLeft(find.byKey(const Key('chat-back'))).dx, 16);
  });
}
