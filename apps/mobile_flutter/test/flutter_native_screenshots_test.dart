import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/data/instance_store.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/chat/tool_cards.dart';
import 'package:openchamber/features/connect/connect_screen.dart';
import 'package:openchamber/features/shell/tab_scaffold.dart';
import 'package:openchamber/features/splash/splash_screen.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/theme/app_theme.dart';

/// Dedicated capture of the real Flutter widgets for Yee's visual review.
///
/// Device: 390×844 logical px @ devicePixelRatio 3 (1170×2532 PNG).
/// Locale: zh-CN. Data: MemorySecureStore + MemoryOpenChamberTransport.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const logical = Size(390, 844);
  const dpr = 3.0;
  const screenshotKey = ValueKey<String>('screenshot-root');

  setUpAll(() async {
    await _loadCjkFont();
  });

  testWidgets('write zh-CN Flutter widget screenshots for visual review', (tester) async {
    tester.view.physicalSize = Size(logical.width * dpr, logical.height * dpr);
    tester.view.devicePixelRatio = dpr;
    tester.view.padding = FakeViewPadding(top: 47 * dpr, bottom: 34 * dpr);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    final transport = _seededTransport();
    final controller = AppController(
      store: MemorySecureStore({localeStorageKey: 'zh-CN'}),
      api: OpenChamberApi(transport: transport),
    );
    await controller.bootstrap(skipDelay: true);
    expect(controller.locale.languageCode, 'zh');

    await _pumpShell(tester, controller, screenshotKey);
    await tester.enterText(find.byKey(const Key('connect-url')), 'http://192.168.1.74:2606');
    await tester.enterText(find.byKey(const Key('connect-token')), 'oc_client_review');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(find.text('连接到 OpenChamber'), findsOneWidget);
    expect(find.byKey(const Key('connect-url')), findsOneWidget);
    expect(find.byKey(const Key('connect-scan-qr')), findsOneWidget);
    expect(find.textContaining('二维码'), findsWidgets);
    expect(find.textContaining('密码'), findsWidgets);
    expect(find.textContaining('Face ID'), findsNothing);
    expect(find.textContaining('PIN'), findsNothing);
    expect(find.textContaining('passcode'), findsNothing);
    await _writePng(tester, screenshotKey, '01-connect.png');

    final connected = await controller.connect(url: 'http://192.168.1.74:2606', label: '工作室');
    expect(connected, isTrue);
    await _pumpFrames(tester);

    expect(find.byKey(const Key('unread-dot')), findsOneWidget);
    expect(find.textContaining('openchamber'), findsWidgets);
    expect(find.textContaining('个会话'), findsWidgets);
    expect(find.byKey(const Key('tab-projects')), findsOneWidget);
    await tester.tap(find.byKey(const Key('projects-plus-menu')));
    await _pumpFrames(tester);
    expect(find.text('新建对话'), findsOneWidget);
    await tester.tapAt(const Offset(48, 720));
    await _pumpFrames(tester);
    await _writePng(tester, screenshotKey, '02-projects.png');

    await tester.tap(find.byKey(const Key('tab-assistant')));
    await _pumpUntil(tester, find.byKey(const Key('assistant-item-asst-1')));
    expect(find.byKey(const Key('assistant-item-asst-1')), findsOneWidget);
    expect(find.byKey(const Key('assistant-item-asst-2')), findsOneWidget);
    expect(find.byKey(const Key('tab-assistant')), findsOneWidget);
    await _writePng(tester, screenshotKey, '03-assistant.png');

    await tester.tap(find.byKey(const Key('tab-scheduled')));
    await _pumpUntil(tester, find.byKey(const Key('scheduled-task-cron-1')));
    expect(find.byKey(const Key('scheduled-task-cron-1')), findsOneWidget);
    expect(find.textContaining('每天'), findsWidgets);
    expect(find.text('任务'), findsWidgets);
    expect(find.text('历史记录'), findsWidgets);
    await _writePng(tester, screenshotKey, '04-scheduled.png');

    await tester.tap(find.byKey(const Key('tab-settings')));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('settings-search')), findsOneWidget);
    expect(find.byKey(const Key('settings-slug-appearance')), findsOneWidget);
    expect(find.byKey(const Key('settings-slug-iosNativeUi'), skipOffstage: false), findsNothing);
    await _writePng(tester, screenshotKey, '05-settings.png');

    await tester.ensureVisible(find.byKey(const Key('settings-slug-appearance')));
    await tester.tap(find.byKey(const Key('settings-slug-appearance')));
    await _pumpUntil(tester, find.byKey(const Key('appearance-lang-zh')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('外观'), findsWidgets);
    expect(find.textContaining('iosNativeUi'), findsNothing);
    expect(find.byKey(const Key('appearance-lang-zh')), findsOneWidget);
    await _writePng(tester, screenshotKey, '06-settings-appearance.png');

    await tester.tap(find.byKey(const Key('settings-back')));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('tab-projects')));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('home-session-sess-pinned')));
    await _pumpUntil(tester, find.byKey(const Key('reverse-chat-list')));
    expect(find.byKey(const Key('reverse-chat-list')), findsOneWidget);
    expect(find.byKey(const Key('composer-field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('composer-field')), '继续改 lib/theme/app_theme.dart');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-activity-m-asst')));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('chat-tool-diff-edit-1')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('chat-tool-diff-edit-1')));
    await tester.pump();
    await _writePng(tester, screenshotKey, '07-chat.png');

    await tester.pumpWidget(
      StringsScope(
        strings: AppStrings.of(AppStrings.zhCN),
        child: RepaintBoundary(
          key: screenshotKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: AppStrings.zhCN,
            supportedLocales: AppStrings.supported,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: _reviewTheme(),
            home: Scaffold(
              appBar: AppBar(title: const Text('发布说明')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  ChatTranscriptBody(
                    message: ChatMessage(
                      id: 'm-perm',
                      body: '需要你批准这次 bash。',
                      isUser: false,
                      parts: [
                        ChatPart(
                          id: 't',
                          kind: ChatPartKind.text,
                          title: 'text',
                          body: '需要你批准这次 bash。',
                        ),
                        ChatPart(
                          id: 'perm-1',
                          kind: ChatPartKind.permission,
                          title: 'bash',
                          toolName: 'bash',
                          permissionId: 'perm-1',
                          patterns: ['git status'],
                          metadata: {'command': 'git status'},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await _pumpFrames(tester);
    expect(find.text('允许一次'), findsOneWidget);
    expect(find.text('始终同意'), findsOneWidget);
    expect(find.text('拒绝'), findsOneWidget);
    expect(find.byKey(const Key('chat-permission-once')), findsOneWidget);
    await _writePng(tester, screenshotKey, '08-permission.png');
  });
}

Future<void> _pumpShell(
  WidgetTester tester,
  AppController controller,
  Key screenshotKey,
) async {
  final theme = _reviewTheme();
  await tester.pumpWidget(
    AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final home = switch (controller.phase) {
          AppPhase.splash => SplashScreen(controller: controller),
          AppPhase.connect => ConnectScreen(controller: controller),
          AppPhase.shell => MobileTabScaffold(controller: controller),
        };
        return StringsScope(
          strings: AppStrings.of(controller.locale),
          child: RepaintBoundary(
            key: screenshotKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: controller.locale,
              supportedLocales: AppStrings.supported,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: theme,
              home: home,
            ),
          ),
        );
      },
    ),
  );
  await _pumpFrames(tester);
}

ThemeData _reviewTheme() {
  final base = materialTheme(Brightness.light);
  const fallbacks = <String>['RobotoReal', 'DroidSansFallback'];
  return ThemeData(
    useMaterial3: true,
    colorScheme: base.colorScheme,
    scaffoldBackgroundColor: base.scaffoldBackgroundColor,
    appBarTheme: base.appBarTheme,
    navigationBarTheme: base.navigationBarTheme,
    pageTransitionsTheme: base.pageTransitionsTheme,
    fontFamily: 'DroidSansFallback',
    textTheme: base.textTheme.apply(fontFamily: 'DroidSansFallback', fontFamilyFallback: fallbacks),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'DroidSansFallback', fontFamilyFallback: fallbacks),
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder, {int max = 40}) async {
  for (var i = 0; i < max; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
}

MemoryOpenChamberTransport _seededTransport() {
  final transport = MemoryOpenChamberTransport(
    sessionIndex: {
      'available': true,
      'revision': 1,
      'pinnedSessionIds': ['sess-pinned'],
      'directories': [
        {
          'directory': '/workspace/openchamber',
          'sessions': [
            {
              'id': 'sess-pinned',
              'title': '发布说明',
              'directory': '/workspace/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': 1756900740000, 'pinned': '2026-09-01T00:00:00.000Z'},
              'branch': 'work/flutter-native',
              'unread': true,
            },
            {
              'id': 'sess-busy',
              'title': '修复输入法',
              'directory': '/workspace/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': 1756899000000},
              'branch': 'feat/home',
            },
            {
              'id': 'sess-catalog',
              'title': '新会话',
              'directory': '/workspace/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': 1756895400000},
              'branch': 'main',
            },
          ],
        },
      ],
    },
    transcript: [
      {
        'info': {'id': 'm-user', 'role': 'user'},
        'parts': [
          {'type': 'text', 'text': '把主题色改到 lib/theme/app_theme.dart。'},
        ],
      },
      {
        'info': {
          'id': 'm-asst',
          'role': 'assistant',
          'model': {'name': 'Grok 4.6'},
          'agent': 'Orchestrator',
          'time': {'created': 1756899000000, 'completed': 1756900740000},
          'tokens': {'output': 44000},
        },
        'parts': [
          {'type': 'text', 'text': '已改 primary，请确认这次 edit。'},
          {
            'id': 'edit-1',
            'type': 'tool',
            'tool': 'edit',
            'state': {
              'status': 'completed',
              'input': {'path': 'lib/theme/app_theme.dart'},
              'output':
                  '--- a/lib/theme/app_theme.dart\n+++ b/lib/theme/app_theme.dart\n@@\n-  static const Color primary = Color(0xFF2F6FED);\n+  static const Color primary = Color(0xFF1D4ED8);\n',
            },
          },
        ],
      },
    ],
  );
  transport.permissions = [
    {
      'id': 'perm-1',
      'sessionID': 'sess-pinned',
      'permission': 'bash',
      'patterns': ['git status'],
      'metadata': {'command': 'git status'},
    },
  ];
  transport.assistants = {
    'revision': 1,
    'enabled': true,
    'assistants': [
      {
        'id': 'asst-1',
        'revision': 1,
        'enabled': true,
        'name': '首页助理',
        'workspacePath': '/workspace/openchamber',
        'providerID': 'anthropic',
        'modelID': 'claude-sonnet-4',
        'mode': 'chat',
        'sessionID': 'sess-catalog',
      },
      {
        'id': 'asst-2',
        'revision': 1,
        'enabled': true,
        'name': '代码审查',
        'workspacePath': '/workspace/openchamber',
        'providerID': 'openai',
        'modelID': 'gpt-5',
        'mode': 'chat',
        'sessionID': 'sess-busy',
      },
    ],
  };
  transport.scheduledTasks = {
    'tasks': [
      {
        'projectId': 'proj-1',
        'task': {
          'id': 'cron-1',
          'name': '夜间审查',
          'enabled': true,
          'schedule': {'kind': 'daily', 'time': '02:00'},
          'execution': {
            'prompt': 'Review the diff',
            'providerID': 'anthropic',
            'modelID': 'claude-sonnet-4',
          },
          'state': {
            'createdAt': 1,
            'updatedAt': 2,
            'lastStatus': 'success',
            'lastSessionId': 'sess-catalog',
            'nextRunAt': 1756987200000,
            'lastError': null,
          },
        },
      },
      {
        'projectId': 'proj-1',
        'task': {
          'id': 'cron-2',
          'name': '每周备份',
          'enabled': true,
          'schedule': {'kind': 'weekly', 'time': '09:00'},
          'execution': {
            'prompt': 'Backup notes',
            'providerID': 'openai',
            'modelID': 'gpt-5',
          },
          'state': {
            'createdAt': 1,
            'updatedAt': 3,
            'lastStatus': 'idle',
            'lastSessionId': null,
            'nextRunAt': 1894060800000,
            'lastError': null,
          },
        },
      },
    ],
    'failedProjectIds': <Object?>[],
  };
  return transport;
}

Future<void> _loadCjkFont() async {
  const cjkCandidates = <String>[
    '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf',
    '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/noto-cjk/NotoSansCJKsc-Regular.otf',
  ];
  ByteData? cjk;
  for (final path in cjkCandidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    if (bytes.isEmpty) continue;
    cjk = ByteData.sublistView(Uint8List.fromList(bytes));
    break;
  }
  if (cjk != null) {
    try {
      await (FontLoader('DroidSansFallback')..addFont(Future<ByteData>.value(cjk))).load();
    } catch (_) {}
  }
  const robotoPath = '/home/ubuntu/development/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf';
  final robotoFile = File(robotoPath);
  if (robotoFile.existsSync()) {
    final roboto = ByteData.sublistView(Uint8List.fromList(robotoFile.readAsBytesSync()));
    try {
      await (FontLoader('RobotoReal')..addFont(Future<ByteData>.value(roboto))).load();
    } catch (_) {}
  }
  const iconCandidates = <String>[
    '/home/ubuntu/development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/home/ubuntu/development/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
  ];
  for (final path in iconCandidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final data = ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync()));
    try {
      await (FontLoader('MaterialIcons')..addFont(Future<ByteData>.value(data))).load();
    } catch (_) {}
    break;
  }
}

Future<void> _writePng(WidgetTester tester, Key screenshotKey, String name) async {
  await tester.pump();
  final boundary = tester.renderObject(find.byKey(screenshotKey)) as RenderRepaintBoundary;
  final png = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
    final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
    return encoded?.buffer.asUint8List();
  });
  expect(png, isNotNull, reason: name);
  expect(png!.length, greaterThan(8000), reason: name);
  expect(png[0], 0x89, reason: name);
  expect(png[1], 0x50, reason: name);

  for (final dir in _outputDirs()) {
    dir.createSync(recursive: true);
    File('${dir.path}/$name').writeAsBytesSync(png);
  }
}

List<Directory> _outputDirs() {
  final cwd = Directory.current;
  final docs = cwd.path.endsWith('mobile_flutter')
      ? Directory('${cwd.path}/../../docs/flutter-native-screenshots')
      : Directory('${cwd.path}/docs/flutter-native-screenshots');
  return [
    docs,
    Directory('/opt/cursor/artifacts/flutter-native-screenshots'),
  ];
}
