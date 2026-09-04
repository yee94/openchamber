import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/app.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/data/settings_catalog.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';
import 'package:openchamber/features/shell/tab_scaffold.dart';
import 'package:openchamber/features/settings/settings_primitives.dart';
import 'package:openchamber/mobile/mobile_surface.dart';
import 'package:openchamber/theme/ios_chrome.dart';
import 'package:openchamber/theme/oc_glyphs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SecondaryChrome.debugReset);

  Future<AppController> pumpConnected(WidgetTester tester) async {
    final controller = AppController(store: MemorySecureStore());
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('connect onboarding is not a local PIN lock', (tester) async {
    final controller = AppController(store: MemorySecureStore());
    await controller.bootstrap(skipDelay: true);
    await tester.pumpWidget(OpenChamberApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Connect to OpenChamber'), findsOneWidget);
    expect(find.byKey(const Key('connect-url')), findsOneWidget);
    expect(find.byKey(const Key('connect-scan-qr')), findsOneWidget);
    expect(find.text('Face ID'), findsNothing);
    expect(find.text('PIN'), findsNothing);
    expect(find.textContaining('passcode'), findsNothing);
  });

  testWidgets('four-tab dock has no Chat root tab', (tester) async {
    await pumpConnected(tester);
    expect(find.byKey(const Key('mobile-tab-scaffold')), findsOneWidget);
    expect(mobileTabIds, ['projects', 'assistant', 'scheduled', 'settings']);
    expect(find.text('Projects'), findsWidgets);
    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('tab-projects')), findsOneWidget);
    expect(find.byKey(const Key('tab-assistant')), findsOneWidget);
    expect(find.byKey(const Key('tab-scheduled')), findsOneWidget);
    expect(find.byKey(const Key('tab-settings')), findsOneWidget);
    expect(find.byKey(const Key('tab-chat'), skipOffstage: false), findsNothing);
    expect(find.byKey(const Key('dock-capsule')), findsOneWidget);
    final capsule = tester.getSize(find.byKey(const Key('dock-capsule')));
    expect(capsule.height, OcTokens.dockHeight);
    final dockGlyphs = tester.widgetList<OcGlyph>(
      find.descendant(of: find.byKey(const Key('dock-capsule')), matching: find.byType(OcGlyph)),
    );
    expect(dockGlyphs.length, 4);
    for (final glyph in dockGlyphs) {
      expect(glyph.size, OcOptical.dockGlyphVisual);
      final stroke = glyph.kind == OcGlyphKind.folder || glyph.kind == OcGlyphKind.sparkles
          ? OcOptical.dockStrokeGlyphStrokeVisual
          : OcOptical.dockGlyphStrokeVisual;
      expect(glyph.strokeWidth, stroke);
      expect(glyph.filled, OcOptical.dockGlyphFillBodies);
    }
    final dockLabel = tester.widget<Text>(
      find.descendant(of: find.byKey(const Key('dock-capsule')), matching: find.text('Projects')),
    );
    expect(dockLabel.style?.fontWeight, FontWeight.w400);
    final pageTitle = tester.widget<Text>(
      find.descendant(of: find.byKey(const Key('mobile-tab-page-title')), matching: find.byType(Text)),
    );
    expect(pageTitle.style?.fontWeight, FontWeight.w600);
    expect(capsule.width, lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio));
  });

  testWidgets('OcCssLine keeps official CSS line boxes with tiny CJK half-lead', (tester) async {
    const title = TextStyle(fontSize: OcOptical.rowTitle, height: OcOptical.rowTitleHeight);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OcCssLine(
            style: title,
            child: Text('会话标题', style: TextStyle(fontSize: OcOptical.rowTitle, height: 1)),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(OcCssLine)).height, OcCssLine.boxHeight(title));
    expect(
      OcCssLine.boxHeight(title),
      OcOptical.rowTitle * OcOptical.rowTitleHeight + 2 * OcOptical.cssLineCjkHalfLead,
    );
    expect(OcOptical.sessionTitleSubtitleGap, 34);
    expect(OcOptical.cssLineCjkHalfLead, closeTo(4.7, 0.01));
  });

  testWidgets('chat is a pushed secondary page from Projects', (tester) async {
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('home-session-sess-pinned')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reverse-chat-list')), findsOneWidget);
    expect(find.byKey(const Key('composer-field')), findsOneWidget);
    expect(find.byKey(const Key('composer-send')), findsOneWidget);
    final idleSend = tester.widget<OcGlyph>(
      find.descendant(of: find.byKey(const Key('composer-send')), matching: find.byType(OcGlyph)),
    );
    expect(idleSend.kind, OcGlyphKind.arrowUp);
    expect(idleSend.size, OcOptical.sendArrow);
    expect(idleSend.strokeWidth, OcOptical.headerGlyphStrokeVisual);
    final idleDisc = tester.widgetList<DecoratedBox>(
      find.descendant(of: find.byKey(const Key('composer-send')), matching: find.byType(DecoratedBox)),
    ).map((box) => box.decoration).whereType<BoxDecoration>().firstWhere(
      (decoration) => decoration.shape == BoxShape.circle && decoration.color != null,
    );
    expect(idleDisc.color, OcTokens.light.foreground);
    expect(idleDisc.border, isNull);
    expect(find.byKey(const Key('chat-back')), findsOneWidget);
    expect(find.text('Release notes'), findsOneWidget);
    expect(find.text('Open a session from Projects.'), findsOneWidget);
    expect(find.byKey(const Key('tab-projects')), findsNothing);
  });

  testWidgets('scheduled dock selects only Schedule', (tester) async {
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('tab-scheduled')));
    await tester.pump();
    expect(find.byKey(const Key('dock-selected-scheduled')), findsOneWidget);
    expect(find.byKey(const Key('dock-selected-projects')), findsNothing);
    expect(find.byKey(const Key('tab-projects')), findsOneWidget);
    final add = tester.widget<CircularChromeButton>(find.byKey(const Key('scheduled-add')));
    expect(add.ink, isTrue);
    expect(add.filled, isFalse);
    final scheduleCard = tester.widget<MobileFloatingSurface>(find.byType(MobileFloatingSurface).first);
    expect(scheduleCard.tight, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const Key('scheduled-task-cron-1')),
        matching: find.byType(OcGlassChip),
      ),
      findsNothing,
    );
  });

  testWidgets('project and session titles paint full foreground ink', (tester) async {
    await pumpConnected(tester);
    final sessionTitle = tester.widgetList<Text>(find.text('Release notes')).firstWhere(
      (title) => title.style?.color != null,
    );
    expect(sessionTitle.style?.color, OcTokens.light.foreground);
    expect(sessionTitle.style?.color!.computeLuminance(), lessThan(0.12));
    expect(sessionTitle.style?.fontWeight, FontWeight.w500);
    final projectTitle = tester.widgetList<Text>(find.text('openchamber')).firstWhere(
      (title) => title.style?.color != null,
    );
    expect(projectTitle.style?.color, OcTokens.light.foreground);
    expect(projectTitle.style?.fontWeight, FontWeight.w600);
    final row = tester.getSize(find.byKey(const Key('home-session-sess-pinned')));
    expect(row.height, greaterThanOrEqualTo(OcOptical.sessionRowVisualHeight));
    expect(row.height, lessThan(OcOptical.sessionRowVisualHeight + 1));
    final codeGlyph = tester.widgetList<OcGlyph>(find.byType(OcGlyph)).firstWhere(
      (glyph) => glyph.kind == OcGlyphKind.code,
    );
    expect(codeGlyph.size, OcOptical.leadingGlyphVisual);
    expect(codeGlyph.size, lessThan(OcOptical.leadingGlyph));
    expect(codeGlyph.strokeWidth, OcOptical.headerGlyphStrokeVisual);
    expect(codeGlyph.strokeWidth, lessThan(OcOptical.headerGlyphStroke));
    final plusPlate = tester.widgetList<SizedBox>(
      find.descendant(of: find.byKey(const Key('projects-plus-menu')), matching: find.byType(SizedBox)),
    ).firstWhere((box) => box.width == OcOptical.addButton && box.height == OcOptical.addButton);
    expect(plusPlate.width, OcOptical.addButton);
    expect(plusPlate.width, greaterThan(OcOptical.headerDiscVisual));
  });

  testWidgets('session search matches titles and hides non-matches', (tester) async {
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('projects-search-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('projects-search')), 'Release');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-session-sess-pinned')), findsOneWidget);
    expect(find.byKey(const Key('home-session-sess-catalog')), findsNothing);
    expect(find.byKey(const Key('home-session-sess-busy')), findsNothing);
  });

  testWidgets('projects plus disc is contact-only, not control umbra', (tester) async {
    await pumpConnected(tester);
    final discs = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byKey(const Key('projects-plus-menu')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final plus = discs.firstWhere((box) {
      final decoration = box.decoration;
      return decoration is BoxDecoration && decoration.shape == BoxShape.circle;
    });
    final decoration = plus.decoration as BoxDecoration;
    expect(decoration.boxShadow, OcElevation.chipFor(OcTokens.light));
    expect(
      decoration.boxShadow!.every((s) => s.blurRadius <= 12 && s.offset == Offset.zero),
      isTrue,
    );
  });

  testWidgets('projects search chip has no painted disc rim', (tester) async {
    await pumpConnected(tester);
    final discs = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byKey(const Key('projects-search-toggle')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final circular = discs.where((box) {
      final decoration = box.decoration;
      return decoration is BoxDecoration && decoration.shape == BoxShape.circle;
    }).toList();
    expect(circular, isNotEmpty);
    for (final box in circular) {
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.border, isNull);
    }
    final searchChip = tester.widget<OcGlassChip>(find.descendant(
      of: find.byKey(const Key('projects-search-toggle')),
      matching: find.byType(OcGlassChip),
    ));
    expect(searchChip.fill, OcTokens.light.glassChipThrough);
    expect(searchChip.size, OcOptical.headerDiscVisual);
    expect(searchChip.fill!.a, closeTo(0.22, 0.01));
    expect(find.descendant(
      of: find.byKey(const Key('projects-search-toggle')),
      matching: find.byType(OcFrosted),
    ), findsOneWidget);
  });

  testWidgets('settings home lists every mobile slug and search filters', (tester) async {
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('tab-settings')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Language and theme'), findsNothing);
    expect(find.textContaining('iosNativeUi'), findsNothing);
    final appearance = tester.widget<SettingsNavRow>(find.byKey(const Key('settings-slug-appearance')));
    expect(appearance.icon, OcGlyphKind.palette);
    expect(appearance.subtitle, isNull);
    for (final page in mobileSettingsPages) {
      expect(settingsNavIcon(page.slug), isNot(OcGlyphKind.gear), reason: page.slug);
    }
    expect(
      tester.getTopLeft(find.byKey(const Key('settings-search'))).dy,
      greaterThan(tester.getBottomLeft(find.byKey(const Key('mobile-tab-page-title'))).dy),
    );
    for (final slug in mobileSettingsPageSlugs) {
      final slugFinder = find.byKey(Key('settings-slug-$slug'), skipOffstage: false);
      expect(slugFinder, findsOneWidget, reason: slug);
      await tester.ensureVisible(find.byKey(Key('settings-slug-$slug'), skipOffstage: false));
    }
    expect(find.byKey(const Key('settings-slug-iosNativeUi'), skipOffstage: false), findsNothing);

    await tester.enterText(find.byKey(const Key('settings-search')), 'about');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-slug-about')), findsOneWidget);
    expect(find.byKey(const Key('settings-slug-mcp')), findsNothing);

    await tester.tap(find.byKey(const Key('settings-slug-about')));
    await tester.pumpAndSettle();
    expect(find.text('Native client'), findsOneWidget);
    expect(find.text('1.19.3-beta.5'), findsOneWidget);
  });

  testWidgets('chat settings load official blob fields instead of a placeholder', (tester) async {
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('tab-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-slug-chat')));
    await tester.tap(find.byKey(const Key('settings-slug-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-chat-render-sorted')), findsOneWidget);
    expect(find.text('This page is structured for the Flutter rewrite. Server-backed controls land in a later slice.'), findsNothing);
    expect(find.textContaining('iosNativeUi'), findsNothing);
  });

  testWidgets('appearance dark restyles Projects Scheduled and Settings immediately', (tester) async {
    final controller = await pumpConnected(tester);
    OcTokens tokensOf(Finder finder) => Theme.of(tester.element(finder)).extension<OcTokens>()!;

    expect(tokensOf(find.byKey(const Key('tab-projects'))).brightness, Brightness.light);

    await tester.tap(find.byKey(const Key('tab-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-slug-appearance')));
    await tester.tap(find.byKey(const Key('settings-slug-appearance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance-theme-dark')));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.dark);
    expect(tokensOf(find.byKey(const Key('appearance-theme-dark'))).brightness, Brightness.dark);
    expect(tokensOf(find.byKey(const Key('appearance-theme-dark'))).pageBackground, OcTokens.dark.pageBackground);

    await tester.tap(find.byKey(const Key('settings-back')));
    await tester.pumpAndSettle();
    expect(tokensOf(find.byKey(const Key('settings-slug-appearance'))).pageBackground, OcTokens.dark.pageBackground);

    await tester.tap(find.byKey(const Key('tab-projects')));
    await tester.pumpAndSettle();
    expect(tokensOf(find.byKey(const Key('tab-projects'))).pageBackground, OcTokens.dark.pageBackground);

    await tester.tap(find.byKey(const Key('tab-scheduled')));
    await tester.pumpAndSettle();
    expect(tokensOf(find.byKey(const Key('tab-scheduled'))).pageBackground, OcTokens.dark.pageBackground);
  });

  testWidgets('providers settings lists catalog rows and failed fetch is not empty', (tester) async {
    await pumpConnected(tester);
    await tester.tap(find.byKey(const Key('tab-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-slug-providers')));
    await tester.tap(find.byKey(const Key('settings-slug-providers')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-item-anthropic')), findsOneWidget);
    expect(find.byKey(const Key('settings-item-openai')), findsOneWidget);
    expect(find.byKey(const Key('settings-resource-error')), findsNothing);
  });
}
