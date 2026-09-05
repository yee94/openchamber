import 'package:flutter/material.dart';

import '../../data/context_usage.dart';
import '../../data/settings_remote.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

Future<void> showSessionMetadataSheet({
  required BuildContext context,
  required String branchLabel,
  MobileContextDisplay? contextDisplay,
  List<SettingsNamedItem> quotas = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => SessionMetadataSheet(
      branchLabel: branchLabel,
      contextDisplay: contextDisplay,
      quotas: quotas,
    ),
  );
}

/// Official metadata: branch + token/limit context (not a stub %).
/// Quotas are a separate section from `GET /api/quota/{id}`.
class SessionMetadataSheet extends StatelessWidget {
  const SessionMetadataSheet({
    super.key,
    required this.branchLabel,
    this.contextDisplay,
    this.quotas = const [],
  });

  final String branchLabel;
  final MobileContextDisplay? contextDisplay;
  final List<SettingsNamedItem> quotas;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final percent = contextDisplay?.percentage ?? 0;
    return Material(
      key: const Key('session-metadata-sheet'),
      color: tokens.pageBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + MediaQuery.viewPaddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t(context, 'mobile.header.metadata.context'),
                    style: ocCssInk(TextStyle(
                      fontSize: OcTokens.textUiLabel,
                      fontWeight: FontWeight.w600,
                      color: tokens.foreground,
                    )),
                  ),
                ),
                Pressable(
                  key: const Key('session-metadata-close'),
                  haptic: HapticStrength.light,
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Semantics(
                    button: true,
                    label: t(context, 'mobile.surface.closeAria'),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: OcGlyph(
                          OcGlyphKind.xmark,
                          size: 16,
                          strokeWidth: OcOptical.detailNavGlyphStroke,
                          color: tokens.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _MetadataRow(
              glyph: OcGlyphKind.branch,
              label: t(context, 'mobile.header.metadata.branch'),
              value: branchLabel,
            ),
            _MetadataRow(
              icon: OcContextProgressIcon(percentage: percent),
              label: t(context, 'mobile.header.metadata.context'),
              value: contextDisplay?.tokensLabel ?? t(context, 'common.unavailable'),
            ),
            if (quotas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t(context, 'settings.usage.title'),
                  style: ocCssInk(TextStyle(
                    fontSize: OcTokens.textUiLabel,
                    fontWeight: FontWeight.w600,
                    color: tokens.foreground,
                  )),
                ),
              ),
              for (final row in quotas)
                _MetadataRow(
                  glyph: OcGlyphKind.layers,
                  label: row.title,
                  value: row.subtitle ?? t(context, 'common.unavailable'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.label,
    required this.value,
    this.glyph,
    this.icon,
  });

  final String label;
  final String value;
  final OcGlyphKind? glyph;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: icon ??
                  OcGlyph(
                    glyph!,
                    size: 18,
                    strokeWidth: OcOptical.detailNavGlyphStroke,
                    color: tokens.mutedForeground,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: ocCssInk(TextStyle(
              fontSize: OcTokens.textUiLabel,
              color: tokens.mutedForeground,
            )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ocCssInk(TextStyle(
                fontSize: OcTokens.textUiLabel,
                fontWeight: FontWeight.w500,
                color: tokens.foreground,
              )),
            ),
          ),
        ],
      ),
    );
  }
}
