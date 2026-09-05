import 'package:flutter/material.dart';

import '../data/home_session.dart';
import '../data/relative_time.dart';
import '../features/projects/highlighted_text.dart';
import '../motion/pressable.dart';
import '../native/haptics.dart';
import '../theme/ios_chrome.dart';
import '../theme/oc_glyphs.dart';

/// Official `MobileSessionRow` — one home-list session.
///
/// Source: `packages/ui/src/mobile/projects/MobileSessionRow.tsx` +
/// `.oc-mobile-session-row-main` / title / subtitle in `mobile.css`.
class MobileSessionRow extends StatelessWidget {
  const MobileSessionRow({
    super.key,
    required this.row,
    required this.onSelect,
    this.onOpenActions,
    this.highlightQuery = '',
    this.showUnreadKey = false,
    this.showBottomDivider = false,
    this.clipStart = false,
    this.clipEnd = false,
  });

  final HomeSessionRow row;
  final String highlightQuery;
  final VoidCallback onSelect;
  final VoidCallback? onOpenActions;
  final bool showUnreadKey;

  /// Official `.oc-mobile-session-row:not(:last-child)` inset divider.
  final bool showBottomDivider;

  /// Official labeled-group first/last row `inset-radius - 1px` corners.
  final bool clipStart;
  final bool clipEnd;

  @override
  Widget build(BuildContext context) {
    final inner = OcTokens.insetRadius - 1;
    final subtitle = row.subtitle.trim();
    final rowBody = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: OcOptical.sessionRowVisualHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Pressable(
              haptic: HapticStrength.light,
              onPressed: onSelect,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  OcOptical.sessionRowPadH,
                  OcOptical.sessionRowPadV,
                  OcOptical.sessionRowPadRight,
                  OcOptical.sessionRowPadV,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: OcOptical.sessionStatus,
                      height: OcOptical.sessionStatus,
                      child: Center(
                        child: Container(
                          width: OcOptical.sessionBullet,
                          height: OcOptical.sessionBullet,
                          decoration: BoxDecoration(
                            color: row.unread
                                ? context.oc.unreadDot
                                : context.oc.mutedForeground.withValues(alpha: OcOptical.sessionBulletReadAlpha),
                            shape: BoxShape.circle,
                          ),
                          child: row.unread && showUnreadKey ? const SizedBox(key: Key('unread-dot')) : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: OcOptical.sessionRowMainGap),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HighlightedText(
                            row.title,
                            query: highlightQuery,
                            halfLead: OcOptical.sessionTitleHalfLeadPaint,
                            stem: OcOptical.sessionTitleStem,
                            style: TextStyle(
                              fontSize: OcOptical.rowTitle,
                              fontWeight: row.unread ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: OcOptical.rowTitleTrackingOfficial,
                              height: OcOptical.rowTitleHeight,
                              color: context.oc.foreground,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: OcOptical.sessionTitleSubtitleGap),
                            HighlightedText(
                              subtitle,
                              query: highlightQuery,
                              halfLead: OcOptical.sessionSubtitleHalfLead,
                              style: TextStyle(
                                fontSize: OcOptical.sessionSubtitle,
                                fontWeight: FontWeight.w400,
                                height: OcOptical.sessionSubtitleHeight,
                                color: context.oc.mutedForeground,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (formatRelativeTime(row.updated) != null)
                      Padding(
                        padding: const EdgeInsets.only(left: OcOptical.sessionTimeGap),
                        child: OcCssLine(
                          expand: false,
                          halfLead: OcOptical.sessionSubtitleHalfLead,
                          style: const TextStyle(
                            fontSize: OcOptical.sessionTime,
                            height: OcOptical.sessionTimeHeight,
                          ),
                          child: Text(
                            formatRelativeTime(row.updated)!,
                            style: ocCssInk(TextStyle(
                              fontSize: OcOptical.sessionTime,
                              fontWeight: FontWeight.w400,
                              letterSpacing: OcOptical.sessionTimeTracking,
                              height: OcOptical.sessionTimeHeight,
                              color: context.oc.mutedForeground,
                            )),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Pressable(
            key: Key('home-session-actions-${row.id}'),
            haptic: HapticStrength.light,
            onPressed: onOpenActions,
            child: SizedBox(
              width: OcOptical.sessionMoreHit,
              height: OcOptical.sessionMoreHit,
              child: Center(
                child: OcGlyph(
                  OcGlyphKind.ellipsis,
                  size: OcOptical.sessionMore,
                  strokeWidth: OcOptical.sessionMoreStroke,
                  color: context.oc.mutedForeground,
                ),
              ),
            ),
          ),
          const SizedBox(width: OcOptical.sessionMoreEdge),
        ],
      ),
    );

    Widget child = rowBody;
    if (clipStart || clipEnd) {
      child = ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: clipStart ? Radius.circular(inner) : Radius.zero,
          topRight: clipStart ? Radius.circular(inner) : Radius.zero,
          bottomLeft: clipEnd ? Radius.circular(inner) : Radius.zero,
          bottomRight: clipEnd ? Radius.circular(inner) : Radius.zero,
        ),
        child: child,
      );
    }
    if (showBottomDivider) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.oc.mobileDivider, width: 1),
          ),
        ),
        child: child,
      );
    }
    return child;
  }
}
