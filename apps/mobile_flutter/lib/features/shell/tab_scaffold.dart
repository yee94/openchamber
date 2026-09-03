import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../l10n/app_strings.dart';
import '../assistant/assistant_tab_screen.dart';
import '../chat/composer_occupancy.dart';
import '../chat/ios_composer_host.dart';
import '../projects/projects_home_screen.dart';
import '../scheduled/scheduled_tab_screen.dart';
import '../settings/settings_home_screen.dart';
import 'ios_tab_bar_host.dart';

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
  void dispose() {
    _warmComposer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ProjectsHomeScreen(
        controller: widget.controller,
        bottomOccupancy: defaultTargetPlatform == TargetPlatform.iOS ? collapsedComposerOccupancy : 0,
      ),
      const AssistantTabScreen(),
      const ScheduledTabScreen(),
      SettingsHomeScreen(controller: widget.controller),
    ];

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final onProjects = _index == 0;
      final bottomPad = MediaQuery.paddingOf(context).bottom + iosTabBarDockHeight;
      return Stack(
        key: const Key('mobile-tab-scaffold'),
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.paddingOf(context).copyWith(bottom: bottomPad),
              ),
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPad,
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomPad,
            child: IosTabBarHost(
              selectedId: mobileTabIds[_index],
              onSelect: (id) {
                final next = mobileTabIds.indexOf(id);
                if (next >= 0) setState(() => _index = next);
              },
            ),
          ),
        ],
      );
    }

    return Scaffold(
      key: const Key('mobile-tab-scaffold'),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.folder_open_outlined), label: t(context, 'tabs.projects')),
          NavigationDestination(icon: const Icon(Icons.auto_awesome_outlined), label: t(context, 'tabs.assistant')),
          NavigationDestination(icon: const Icon(Icons.calendar_month_outlined), label: t(context, 'tabs.scheduled')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), label: t(context, 'tabs.settings')),
        ],
      ),
    );
  }
}
