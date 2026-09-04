import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/settings_catalog.dart';
import '../../l10n/app_strings.dart';
import '../../navigation/platform_route.dart';
import '../../mobile/mobile_surface.dart';
import '../../theme/oc_tokens.dart';
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

    return MobileTabPageScaffold(
      title: t(context, 'settings.home.title'),
      restPeek: 0,
      children: [
            SettingsSearchField(
              query: _query,
              onChanged: (value) => setState(() => _query = value),
              onClear: () => setState(() => _query = ''),
            ),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OcTokens.pageInlineInset),
                child: Text(t(context, 'settings.search.noResults')),
              )
            else
              ...groups.map((group) {
                return SettingsGroup(
                  label: groupLabel(context, group.group),
                  children: group.pages.map((page) {
                    return SettingsNavRow(
                      key: Key('settings-slug-${page.slug}'),
                      label: t(context, page.titleKey),
                      icon: settingsNavIcon(page.slug),
                      subtitle: _query.trim().isEmpty || page.descriptionKey == null
                          ? null
                          : t(context, page.descriptionKey!),
                      onTap: () {
                        Navigator.of(context).push(
                          platformPageRoute<void>(
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
    );
  }
}
