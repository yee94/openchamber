import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../navigation/platform_route.dart';
import '../../native/deep_link.dart';
import '../../theme/ios_chrome.dart';
import '../assistant/assistant_tab_screen.dart';
import '../chat/chat_screen.dart';
import '../chat/composer_occupancy.dart';
import '../chat/ios_composer_host.dart';
import '../projects/projects_home_screen.dart';
import '../scheduled/scheduled_tab_screen.dart';
import '../settings/settings_home_screen.dart';
import 'floating_tab_bar.dart';
import 'ios_tab_bar_host.dart';
import 'secondary_chrome.dart';

/// Official homepage dock: four roots only.
/// Source: `packages/ui/src/mobile/mobileTabs.ts` + OpenChamberTabBar.
/// Chat is a pushed secondary page, never a dock tab.
const List<String> mobileTabIds = ['projects', 'assistant', 'scheduled', 'settings'];

class MobileTabScaffold extends StatefulWidget {
  const MobileTabScaffold({super.key, required this.controller});

  final AppController controller;

  @override
  State<MobileTabScaffold> createState() => _MobileTabScaffoldState();
}

class _MobileTabScaffoldState extends State<MobileTabScaffold> {
  int _index = 0;
  final TextEditingController _warmComposer = TextEditingController();

  @override
  void initState() {
    super.initState();
    SecondaryChrome.listenable.addListener(_onSecondaryChrome);
    widget.controller.addListener(_onController);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingSessionLink());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    SecondaryChrome.listenable.removeListener(_onSecondaryChrome);
    _warmComposer.dispose();
    super.dispose();
  }

  void _onController() {
    _openPendingSessionLink();
  }

  void _openPendingSessionLink() {
    final link = widget.controller.takePendingSessionDeepLink();
    if (link == null || !mounted) return;
    final sessionId = parseSessionDeepLinkId(link.raw);
    if (sessionId == null) return;
    final row = widget.controller.sessionRowForId(sessionId);
    Navigator.of(context).push(
      platformPageRoute<void>(
        builder: (_) => ChatScreen(session: row, appController: widget.controller),
      ),
    );
  }

  void _onSecondaryChrome() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _select(String id) {
    final next = mobileTabIds.indexOf(id);
    if (next >= 0 && next != _index) setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ProjectsHomeScreen(
        controller: widget.controller,
        bottomOccupancy: defaultTargetPlatform == TargetPlatform.iOS ? collapsedComposerOccupancy : 0,
      ),
      AssistantTabScreen(controller: widget.controller),
      ScheduledTabScreen(controller: widget.controller),
      SettingsHomeScreen(controller: widget.controller),
    ];

    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final hideDock = SecondaryChrome.hideHomepageDock;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final dockReserve = hideDock
        ? safeBottom
        : (ios
            ? iosTabBarDockHeight + safeBottom
            : OcTokens.dockHeight + math.max(OcOptical.dockBottomPad, safeBottom));
    final onProjects = _index == 0 && !hideDock;

    return Stack(
      key: const Key('mobile-tab-scaffold'),
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.paddingOf(context).copyWith(bottom: dockReserve),
            ),
            child: IndexedStack(index: _index, children: pages),
          ),
        ),
        if (ios)
          Positioned(
            left: 0,
            right: 0,
            bottom: dockReserve,
            height: onProjects ? collapsedComposerOccupancy : 0,
            child: IgnorePointer(
              ignoring: !onProjects,
              child: IosComposerHost(
                visible: onProjects,
                warm: true,
                text: _warmComposer.text,
                canSend: _warmComposer.text.trim().isNotEmpty,
                canAbort: false,
                attachments: const [],
                onSend: (_) {},
                onStop: () {},
                onAttach: () {},
                onText: (value) => _warmComposer.text = value,
              ),
            ),
          ),
        if (!hideDock)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ios
                ? SizedBox(
                    height: dockReserve,
                    child: IosTabBarHost(
                      selectedId: mobileTabIds[_index],
                      onSelect: _select,
                    ),
                  )
                : FloatingCapsuleTabBar(
                    selectedId: mobileTabIds[_index],
                    onSelect: _select,
                  ),
          ),
      ],
    );
  }
}
