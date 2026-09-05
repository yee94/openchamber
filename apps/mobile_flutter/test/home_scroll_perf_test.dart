import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/mobile/mobile_surface.dart';
import 'package:openchamber/mobile/mobile_tab_page_header.dart';
import 'package:openchamber/theme/app_theme.dart';
import 'package:openchamber/theme/ios_chrome.dart';

/// Home-tab scroll contract: collapse must not rebuild the tab body or
/// trailing chrome, and scrolling cards must not run BackdropFilter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('root-tab scroll does not rebuild trailing chrome or body rows', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    final trailingBuilds = <int>[0];
    final rowBuilds = List<List<int>>.generate(24, (_) => <int>[0]);

    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings.of(AppStrings.zhCN),
        child: MaterialApp(
          theme: materialTheme(Brightness.light),
          home: MobileTabPageScaffold(
            title: '项目',
            trailing: _BuildProbe(counts: trailingBuilds, child: const SizedBox(width: 36, height: 36, child: Text('trail'))),
            children: [
              for (var i = 0; i < 24; i += 1)
                MobileFloatingSurface(
                  key: Key('perf-card-$i'),
                  child: _BuildProbe(
                    counts: rowBuilds[i],
                    child: SizedBox(height: 72, child: Text('row-$i')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byKey(const Key('mobile-tab-page-header-fill')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MobileFloatingSurface),
        matching: find.byType(OcFrosted),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('mobile-float-plate')), findsWidgets);
    final plate = tester.widget<ColoredBox>(find.byKey(const Key('mobile-float-plate')).first);
    expect(plate.color, OcTokens.light.floatPlate);
    expect(plate.color.a, closeTo(1.0, 0.001));

    final trailingAfterMount = trailingBuilds.single;
    final mountedRows = <int, int>{
      for (var i = 0; i < rowBuilds.length; i += 1)
        if (rowBuilds[i].single > 0) i: rowBuilds[i].single,
    };
    expect(trailingAfterMount, greaterThan(0));
    expect(mountedRows, isNotEmpty);

    final scroll = tester.widget<SingleChildScrollView>(find.byKey(const Key('mobile-tab-page-scroll')));
    scroll.controller!.jumpTo(80);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final header = tester.widget<MobileTabPageHeader>(find.byType(MobileTabPageHeader));
    expect(header.currentCollapse, closeTo(1, 0.02));
    expect(trailingBuilds.single, trailingAfterMount);
    for (final entry in mountedRows.entries) {
      expect(rowBuilds[entry.key].single, entry.value, reason: 'row-${entry.key} rebuilt on collapse');
    }

    final list = find.byKey(const Key('mobile-tab-page-scroll'));
    await tester.fling(list, const Offset(0, -1200), 2800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 32));

    expect(trailingBuilds.single, trailingAfterMount);
    for (final entry in mountedRows.entries) {
      expect(rowBuilds[entry.key].single, entry.value, reason: 'row-${entry.key} rebuilt on fling');
    }
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('mobile-tab-page-header-fill'))).color.a,
      closeTo(1.0, 0.001),
    );
  });

  testWidgets('scheduled track chrome has no live BackdropFilter', (tester) async {
    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings.of(AppStrings.zhCN),
        child: MaterialApp(
          theme: materialTheme(Brightness.light),
          home: const Scaffold(
            body: Column(
              children: [
                SegmentedPill(labels: ['任务', '历史记录'], selectedIndex: 0, onSelected: _noop),
                FilterChipBar(labels: ['全部', '已启用', '已暂停'], selectedIndex: 0, onSelected: _noop),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(OcFrosted), findsNothing);
    expect(find.byType(SegmentedPill), findsOneWidget);
    expect(find.byType(FilterChipBar), findsOneWidget);
  });
}

void _noop(int _) {}

class _BuildProbe extends StatefulWidget {
  const _BuildProbe({required this.counts, required this.child});

  final List<int> counts;
  final Widget child;

  @override
  State<_BuildProbe> createState() => _BuildProbeState();
}

class _BuildProbeState extends State<_BuildProbe> {
  @override
  Widget build(BuildContext context) {
    widget.counts[0] += 1;
    return widget.child;
  }
}
