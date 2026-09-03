import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../l10n/app_strings.dart';
import '../assistant/assistant_tab_screen.dart';
import '../projects/projects_home_screen.dart';
import '../scheduled/scheduled_tab_screen.dart';
import '../settings/settings_home_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ProjectsHomeScreen(controller: widget.controller),
      const AssistantTabScreen(),
      const ScheduledTabScreen(),
      SettingsHomeScreen(controller: widget.controller),
    ];

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoTabScaffold(
        key: const Key('mobile-tab-scaffold'),
        tabBar: CupertinoTabBar(
          currentIndex: _index,
          onTap: (index) => setState(() => _index = index),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.folder),
              label: t(context, 'tabs.projects'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.sparkles),
              label: t(context, 'tabs.assistant'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.calendar),
              label: t(context, 'tabs.scheduled'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.settings),
              label: t(context, 'tabs.settings'),
            ),
          ],
        ),
        tabBuilder: (context, index) => pages[index],
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
