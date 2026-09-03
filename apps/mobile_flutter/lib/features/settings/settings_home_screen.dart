import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/settings_catalog.dart';
import '../../l10n/app_strings.dart';
import 'settings_pages.dart';
import 'settings_primitives.dart';

class SettingsHomeScreen extends StatefulWidget {
  const SettingsHomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsHomeScreen> createState() => _SettingsHomeScreenState();
}

class _SettingsHomeScreenState extends State<SettingsHomeScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = StringsScope.of(context);
    final matches = mobileSettingsPages
        .where((page) => settingsPageMatchesQuery(page, _query, strings.t))
        .toList();
    final groups = groupMobileSettingsPages(matches);

    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'settings.home.title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          TextField(
            key: const Key('settings-search'),
            decoration: InputDecoration(
              hintText: t(context, 'settings.search.placeholder'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: t(context, 'settings.search.clear'),
                      onPressed: () => setState(() => _query = ''),
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 20),
          if (groups.isEmpty)
            Text(t(context, 'settings.search.noResults'))
          else
            ...groups.map((group) {
              return SettingsGroup(
                label: groupLabel(context, group.group),
                children: group.pages.map((page) {
                  return SettingsNavRow(
                    key: Key('settings-slug-${page.slug}'),
                    label: t(context, page.titleKey),
                    subtitle: page.descriptionKey == null ? null : t(context, page.descriptionKey!),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AnimatedBuilder(
                            animation: widget.controller,
                            builder: (context, _) => SettingsDetailPage(
                              controller: widget.controller,
                              page: page,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            }),
        ],
        ),
      ),
    );
  }
}
