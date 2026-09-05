import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../l10n/app_strings.dart';
import '../../mobile/mobile_assistant_card.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../native/share_targeting.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

/// Official `MobileShareRecipientPicker` — untargeted Android drafts pick an
/// assistant. Never silently defaults.
class ShareRecipientPicker extends StatelessWidget {
  const ShareRecipientPicker({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final draft = controller.pendingShareDraft;
        if (draft == null) return const SizedBox.shrink();
        final entries = [for (final entry in controller.shareCatalog) if (entry.enabled) entry];
        final tokens = context.oc;
        final view = MediaQuery.viewPaddingOf(context);
        return Positioned.fill(
          child: Material(
            key: const Key('share-recipient-picker'),
            color: tokens.pageBackground,
            child: Column(
              children: [
                SizedBox(
                  height: view.top + OcOptical.detailNavigationHeight,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8, view.top, 8, 0),
                    child: Row(
                      children: [
                        Pressable(
                          haptic: HapticStrength.light,
                          enabled: !controller.shareRecipientBusy,
                          onPressed: () => controller.cancelShareRecipient(draft),
                          child: Semantics(
                            button: true,
                            label: t(context, 'share.cancel'),
                            child: SizedBox(
                              key: const Key('share-recipient-cancel'),
                              width: 36,
                              height: 36,
                              child: Center(
                                child: OcGlyph(OcGlyphKind.chevronBack, size: 16, color: tokens.foreground),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            t(context, 'share.chooseAssistant'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: OcTokens.textUiHeader,
                              fontWeight: FontWeight.w600,
                              color: tokens.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: Text(
                            t(context, 'share.assistantsUnavailable'),
                            style: TextStyle(color: tokens.mutedForeground, fontSize: OcTokens.textMarkdown),
                          ),
                        )
                      : Semantics(
                          label: t(context, 'share.assistantListAria'),
                          child: ListView(
                          key: const Key('share-recipient-list'),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          children: [
                            for (final entry in entries)
                              _RecipientRow(
                                entry: entry,
                                busy: controller.shareRecipientBusy,
                                onSelect: () => controller.assignShareRecipient(draft: draft, target: entry),
                              ),
                          ],
                        ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.entry,
    required this.busy,
    required this.onSelect,
  });

  final ShareTarget entry;
  final bool busy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    return Pressable(
      haptic: HapticStrength.light,
      enabled: !busy,
      onPressed: onSelect,
      child: Semantics(
        button: true,
        enabled: !busy,
        label: '${entry.name}. ${entry.serverLabel}',
        child: SizedBox(
          width: double.infinity,
          child: Padding(
          key: Key('share-recipient-${entry.assistantId}'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              AgentIdenticon(seed: entry.assistantId, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: tokens.foreground),
                    ),
                    if (entry.serverLabel.isNotEmpty)
                      Text(
                        entry.serverLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tokens.mutedForeground, fontSize: OcTokens.textMicro),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
