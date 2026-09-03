import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/data/instance_store.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/chat/chat_screen.dart';
import 'package:openchamber/features/chat/tool_cards.dart';
import 'package:openchamber/features/connect/connect_screen.dart';
import 'package:openchamber/features/shell/secondary_chrome.dart';
import 'package:openchamber/features/shell/tab_scaffold.dart';
import 'package:openchamber/features/splash/splash_screen.dart';
import 'package:openchamber/l10n/app_strings.dart';
import 'package:openchamber/data/dictation.dart';
import 'package:openchamber/theme/app_theme.dart';
import 'package:openchamber/theme/ios_chrome.dart';
import 'review_fonts.dart';

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
    await loadReviewFonts();
  });

  setUp(SecondaryChrome.debugReset);

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
      dictation: UnavailableDictation(),
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
    expect(find.textContaining('Code/github'), findsWidgets);
    expect(find.textContaining('个会话'), findsWidgets);
    expect(find.textContaining('更多'), findsWidgets);
    expect(find.textContaining('feat/opencode2up'), findsWidgets);
    expect(find.textContaining('feat/remove-ctx', skipOffstage: false), findsWidgets);
    expect(find.textContaining('ios-native', skipOffstage: false), findsWidgets);
    expect(find.textContaining('NPM 全 package fix'), findsWidgets);
    expect(find.byKey(const Key('projects-attention-strip')), findsOneWidget);
    expect(find.textContaining('置顶'), findsNothing);
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
    expect(find.text('启用助理'), findsNothing);
    expect(find.textContaining('连续模式'), findsWidgets);
    expect(find.byKey(const Key('tab-assistant')), findsOneWidget);
    await _writePng(tester, screenshotKey, '03-assistant.png');

    await tester.tap(find.byKey(const Key('tab-scheduled')));
    await _pumpUntil(tester, find.byKey(const Key('scheduled-task-cron-1')));
    expect(find.byKey(const Key('scheduled-task-cron-1')), findsOneWidget);
    expect(find.textContaining('每天'), findsWidgets);
    expect(find.textContaining('后'), findsWidgets);
    expect(find.textContaining('每日AI会话日报'), findsOneWidget);
    expect(find.textContaining('weekly-architecture-review'), findsOneWidget);
    expect(find.text('任务'), findsWidgets);
    expect(find.text('历史记录'), findsWidgets);
    expect(find.text('已暂停'), findsWidgets);
    expect(find.byKey(const Key('dock-selected-scheduled')), findsOneWidget);
    expect(find.byKey(const Key('dock-selected-projects')), findsNothing);
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

    final chatSession = controller.sessions.firstWhere((row) => row.id == 'sess-extra');
    SecondaryChrome.debugReset();
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
            home: ChatScreen(
              session: chatSession,
              appController: controller,
            ),
          ),
        ),
      ),
    );
    await _pumpUntil(tester, find.byKey(const Key('chat-tool-diff-edit-1')));
    await _pumpUntil(tester, find.byKey(const Key('chat-busy')));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('chat-back')), findsOneWidget);
    expect(find.byKey(const Key('chat-busy')), findsOneWidget);
    expect(find.byKey(const Key('reverse-chat-list')), findsOneWidget);
    expect(find.byKey(const Key('composer-field')), findsOneWidget);
    expect(find.text('点击输入'), findsOneWidget);
    expect(find.byKey(const Key('composer-attach')), findsOneWidget);
    expect(find.byKey(const Key('composer-send')), findsOneWidget);
    expect(find.byKey(const Key('composer-dictate')), findsNothing);
    expect(find.text('Grok 4.6'), findsWidgets);
    expect(find.byKey(const Key('chat-role-badge')), findsWidgets);
    expect(find.text('Orchestrator'), findsWidgets);
    expect(find.byKey(const Key('chat-header-subtitle')), findsOneWidget);
    expect(find.byKey(const Key('chat-agent-count')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-copy')), findsWidgets);
    expect(find.byKey(const Key('chat-action-share')), findsWidgets);
    expect(find.byKey(const Key('chat-action-up')), findsNothing);
    expect(find.byKey(const Key('chat-action-down')), findsNothing);
    expect(find.byKey(const Key('chat-action-revert')), findsWidgets);
    expect(find.byKey(const Key('chat-action-edit')), findsWidgets);
    expect(find.textContaining('绘画的内容在这里写'), findsOneWidget);
    expect(find.textContaining('已处理'), findsWidgets);
    expect(find.textContaining('Agent 参与'), findsOneWidget);
    expect(find.byKey(const Key('chat-tool-diff-edit-1')), findsOneWidget);
    expect(find.textContaining('已更改文件'), findsOneWidget);
    expect(find.textContaining('个文件'), findsWidgets);
    expect(find.textContaining('+5 个文件'), findsOneWidget);
    expect(find.byKey(const Key('chat-tps-m-asst')), findsOneWidget);
    expect(find.textContaining('需要权限'), findsNothing);
    expect(find.byKey(const Key('tab-projects')), findsNothing);
    expect(find.byKey(const Key('projects-plus-menu')), findsNothing);
    expect(find.text('项目'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('chat-tool-diff-edit-1')));
    expect(find.byKey(const Key('chat-scroll-to-bottom')), findsOneWidget);
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
              appBar: const PushedNavBar(title: '发布说明'),
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
    await tester.pump(const Duration(seconds: 6));
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
  const fallbacks = <String>['ReviewCjk', 'RobotoReal', 'DroidSansFallback'];
  return ThemeData(
    useMaterial3: true,
    colorScheme: base.colorScheme,
    scaffoldBackgroundColor: base.scaffoldBackgroundColor,
    appBarTheme: base.appBarTheme,
    navigationBarTheme: base.navigationBarTheme,
    pageTransitionsTheme: base.pageTransitionsTheme,
    fontFamily: 'ReviewSans',
    textTheme: base.textTheme.apply(fontFamily: 'ReviewSans', fontFamilyFallback: fallbacks),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'ReviewSans', fontFamilyFallback: fallbacks),
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
  final now = DateTime.now().millisecondsSinceEpoch;
  final transport = MemoryOpenChamberTransport(
    sessionIndex: {
      'available': true,
      'revision': 1,
      'pinnedSessionIds': ['sess-pinned'],
      'directories': [
        {
          'directory': '/workspace/Code/github/openchamber',
          'sessions': [
            {
              'id': 'sess-pinned',
              'title': '发布说明',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 60000, 'pinned': '2026-09-01T00:00:00.000Z'},
              'branch': 'main',
              'unread': true,
            },
            {
              'id': 'sess-busy',
              'title': '修复输入法',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 33 * 60000},
              'branch': 'main',
            },
            {
              'id': 'sess-catalog',
              'title': '新会话',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 2 * 3600000},
              'branch': 'main',
            },
            {
              'id': 'sess-diff',
              'title': '写入类型无法点开查看 diff',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 5 * 3600000},
              'branch': 'main',
            },
            {
              'id': 'sess-extra',
              'title': '写入工具 diff 点开看不到的路径',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 8 * 3600000},
              'branch': 'main',
            },
            {
              'id': 'sess-npm',
              'title': 'NPM 全 package fix 版本发布',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 4 * 60000},
              'branch': 'main',
            },
            for (var i = 1; i <= 6; i += 1)
              {
                'id': 'sess-more-$i',
                'title': '目录会话 $i',
                'directory': '/workspace/Code/github/openchamber',
                'parentID': null,
                'project': {'name': 'openchamber'},
                'time': {'updated': now - (24 + i) * 3600000},
                'branch': 'main',
              },
            {
              'id': 'sess-wt-1',
              'title': 'OpenCode 升级',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 12 * 3600000},
              'branch': 'feat/opencode2up',
            },
            {
              'id': 'sess-wt-2',
              'title': 'Composer IME',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 20 * 3600000},
              'branch': 'feat/opencode2up',
            },
            {
              'id': 'sess-ctx-1',
              'title': '合并上下文窗口',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 4 * 86400000},
              'branch': 'feat/remove-ctx',
            },
            {
              'id': 'sess-ctx-2',
              'title': 'Halo greeting',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 6 * 86400000},
              'branch': 'feat/remove-ctx',
            },
            {
              'id': 'sess-ctx-3',
              'title': '去掉多余上下文',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 7 * 86400000},
              'branch': 'feat/remove-ctx',
            },
            {
              'id': 'sess-ios-1',
              'title': 'Composer UIKit overlay',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 5 * 60000},
              'branch': 'ios-native',
            },
            {
              'id': 'sess-ios-2',
              'title': 'Live Activity 状态',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 2 * 86400000},
              'branch': 'ios-native',
            },
            {
              'id': 'sess-ios-3',
              'title': 'Tab bar 玻璃',
              'directory': '/workspace/Code/github/openchamber',
              'parentID': null,
              'project': {'name': 'openchamber'},
              'time': {'updated': now - 3 * 86400000},
              'branch': 'ios-native',
            },
          ],
        },
      ],
    },
    transcript: [
      {
        'info': {
          'id': 'm-user',
          'role': 'user',
          'time': {'created': DateTime(2026, 9, 3, 23, 24).millisecondsSinceEpoch},
        },
        'parts': [
          {'type': 'text', 'text': '写入类型无法点开查看 diff 参考这个'},
          {'type': 'text', 'text': '绘画的内容在这里写'},
        ],
      },
      {
        'info': {
          'id': 'm-asst',
          'role': 'assistant',
          'model': {'name': 'Grok 4.6'},
          'agent': 'Orchestrator',
          'time': {'created': now - 29 * 60000, 'completed': now - 1000},
          'tokens': {'output': 44000},
        },
        'parts': [
          {
            'type': 'text',
            'text': '路径匹配已经按目录前缀对齐。已跑: ToolPart / toolDiffUtils / DiffView 相关测试，58 过。',
          },
          {
            'id': 'task-1',
            'type': 'tool',
            'tool': 'task',
            'state': {
              'status': 'completed',
              'input': {'description': 'patch diff viewer', 'prompt': 'patch diff viewer'},
              'output': 'done',
            },
          },
          {
            'id': 'edit-1',
            'type': 'tool',
            'tool': 'edit',
            'state': {
              'status': 'completed',
              'input': {'path': 'DOCUMENTATION.md'},
              'output':
                  '--- a/DOCUMENTATION.md\n+++ b/DOCUMENTATION.md\n@@\n-old\n+new line 1\n+new line 2\n',
            },
          },
          {
            'id': 'edit-2',
            'type': 'tool',
            'tool': 'edit',
            'state': {
              'status': 'completed',
              'input': {'path': 'ToolPart.tsx'},
              'output':
                  '--- a/ToolPart.tsx\n+++ b/ToolPart.tsx\n@@\n-a\n-b\n+c\n+d\n+e\n',
            },
          },
          {
            'id': 'edit-3',
            'type': 'tool',
            'tool': 'edit',
            'state': {
              'status': 'completed',
              'input': {'path': 'toolDiffUtils.ts'},
              'output':
                  '--- a/toolDiffUtils.ts\n+++ b/toolDiffUtils.ts\n@@\n-x\n+y\n',
            },
          },
          {
            'id': 'edit-4',
            'type': 'tool',
            'tool': 'edit',
            'state': {
              'status': 'completed',
              'input': {'path': 'DiffView.tsx'},
              'output': '--- a/DiffView.tsx\n+++ b/DiffView.tsx\n@@\n-old\n+new\n+line\n',
            },
          },
          {
            'id': 'edit-5',
            'type': 'tool',
            'tool': 'edit',
            'state': {
              'status': 'completed',
              'input': {'path': 'chat_screen.dart'},
              'output': '--- a/chat_screen.dart\n+++ b/chat_screen.dart\n@@\n-a\n+b\n',
            },
          },
          {
            'id': 'edit-6',
            'type': 'tool',
            'tool': 'edit',
            'state': {
              'status': 'completed',
              'input': {'path': 'ios_chrome.dart'},
              'output': '--- a/ios_chrome.dart\n+++ b/ios_chrome.dart\n@@\n-a\n+b\n+c\n',
            },
          },
          {
            'id': 'edit-7',
            'type': 'tool',
            'tool': 'edit',
            'state': {
              'status': 'completed',
              'input': {'path': 'composer_bar.dart'},
              'output': '--- a/composer_bar.dart\n+++ b/composer_bar.dart\n@@\n-a\n+b\n',
            },
          },
          {
            'id': 'edit-8',
            'type': 'tool',
            'tool': 'edit',
            'state': {
              'status': 'completed',
              'input': {'path': 'tab_scaffold.dart'},
              'output': '--- a/tab_scaffold.dart\n+++ b/tab_scaffold.dart\n@@\n-a\n+b\n',
            },
          },
          {
            'id': 'edit-9',
            'type': 'tool',
            'tool': 'edit',
            'state': {
              'status': 'completed',
              'input': {'path': 'secondary_chrome.dart'},
              'output': '--- a/secondary_chrome.dart\n+++ b/secondary_chrome.dart\n@@\n-a\n+b\n',
            },
          },
          {
            'id': 'edit-10',
            'type': 'tool',
            'tool': 'edit',
            'state': {
              'status': 'completed',
              'input': {'path': 'app_theme.dart'},
              'output': '--- a/app_theme.dart\n+++ b/app_theme.dart\n@@\n-a\n+b\n+c\n',
            },
          },
        ],
      },
    ],
  );
  transport.permissions = const [];
  transport.statusBySession = const {'sess-extra': 'busy', 'sess-npm': 'busy'};
  transport.assistants = {
    'revision': 1,
    'enabled': true,
    'assistants': [
      {
        'id': 'asst-1',
        'revision': 1,
        'enabled': true,
        'name': '首页助理',
        'defaultPrompt': '一段持续的长对话，处理首页和通知。',
        'workspacePath': '/workspace/Code/github/openchamber',
        'providerID': 'anthropic',
        'modelID': 'claude-sonnet-4',
        'mode': 'continuous',
        'sessionID': 'sess-catalog',
      },
      {
        'id': 'asst-2',
        'revision': 1,
        'enabled': true,
        'name': '代码审查',
        'defaultPrompt': '审查 diff 与测试，不携带无关历史。',
        'workspacePath': '/workspace/Code/github/openchamber',
        'providerID': 'openai',
        'modelID': 'gpt-5',
        'mode': 'stateless',
        'sessionID': 'sess-busy',
      },
    ],
  };
  transport.scheduledTasks = {
    'tasks': [
      _reviewTask(
        id: 'cron-1',
        name: '每日AI会话日报',
        enabled: true,
        kind: 'daily',
        time: '23:30',
        nextRunAt: now + const Duration(hours: 23, minutes: 31).inMilliseconds,
      ),
      _reviewTask(
        id: 'cron-3',
        name: '月度笔记回顾',
        enabled: true,
        kind: 'cron',
        time: '0 9 1 * *',
        nextRunAt: now + const Duration(days: 12).inMilliseconds,
      ),
      _reviewTask(
        id: 'cron-4',
        name: '周度笔记回顾',
        enabled: true,
        kind: 'cron',
        time: '0 9 * * 1',
        nextRunAt: now + const Duration(days: 3).inMilliseconds,
      ),
      _reviewTask(
        id: 'cron-2',
        name: 'Langfuse 前一日小程序 AI 场景分析',
        enabled: false,
        kind: 'daily',
        time: '08:00',
      ),
      _reviewTask(
        id: 'cron-5',
        name: 'weekly-architecture-review',
        enabled: false,
        kind: 'weekly',
        time: '09:00',
      ),
    ],
    'failedProjectIds': <Object?>[],
  };
  return transport;
}

Map<String, Object?> _reviewTask({
  required String id,
  required String name,
  required bool enabled,
  required String kind,
  required String time,
  int? nextRunAt,
}) {
  return {
    'projectId': 'proj-1',
    'task': {
      'id': id,
      'name': name,
      'enabled': enabled,
      'schedule': {'kind': kind, 'time': time},
      'execution': {
        'prompt': 'Review the diff',
        'providerID': 'anthropic',
        'modelID': 'claude-sonnet-4',
      },
      'state': {
        'createdAt': 1,
        'updatedAt': 2,
        'lastStatus': enabled ? 'success' : 'idle',
        'lastSessionId': enabled ? 'sess-catalog' : null,
        'nextRunAt': nextRunAt,
        'lastError': null,
      },
    },
  };
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
