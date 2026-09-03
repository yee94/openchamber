import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/settings_catalog.dart';
import '../../l10n/app_strings.dart';
import '../../navigation/platform_route.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            LargeTitleHeader(title: t(context, 'settings.home.title')),
            Padding(
              padding: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 0, OcChrome.pageGutter, 16),
              child: TextField(
                key: const Key('settings-search'),
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: t(context, 'settings.search.placeholder'),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10, right: 4),
                    child: OcGlyph(OcGlyphKind.search, size: 16, color: context.oc.mutedForeground),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 18),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: t(context, 'settings.search.clear'),
                          onPressed: () => setState(() => _query = ''),
                          icon: OcGlyph(OcGlyphKind.xmark, size: 16, color: context.oc.mutedForeground),
                        ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OcChrome.pillRadius),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OcChrome.pillRadius),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OcChrome.pillRadius),
                    borderSide: BorderSide.none,
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
              ),
            ),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
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
                      subtitle: page.descriptionKey == null ? null : t(context, page.descriptionKey!),
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
          ),
        ),
      ),
    );
  }
}
