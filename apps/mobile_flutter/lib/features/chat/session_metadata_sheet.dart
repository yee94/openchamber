import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

Future<void> showSessionMetadataSheet({
  required BuildContext context,
  required String branchLabel,
  required double contextPercent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => SessionMetadataSheet(
      branchLabel: branchLabel,
      contextPercent: contextPercent,
    ),
  );
}

/// Visual stub of official session metadata (branch + context ring).
/// Quota groups stay off until Flutter has a usage store.
class SessionMetadataSheet extends StatelessWidget {
  const SessionMetadataSheet({
    super.key,
    required this.branchLabel,
    required this.contextPercent,
  });

  final String branchLabel;
  final double contextPercent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
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
              icon: OcContextProgressIcon(percentage: contextPercent),
              label: t(context, 'mobile.header.metadata.context'),
              value: '${contextPercent.toStringAsFixed(1)}%',
            ),
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
