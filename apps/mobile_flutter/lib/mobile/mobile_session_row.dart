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
    this.highlightQuery = '',
    this.showUnreadKey = false,
    this.showBottomDivider = false,
    this.clipStart = false,
    this.clipEnd = false,
  });

  final HomeSessionRow row;
  final String highlightQuery;
  final VoidCallback onSelect;
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
    final rowBody = Pressable(
      haptic: HapticStrength.light,
      onPressed: onSelect,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: OcOptical.sessionRowVisualHeight),
        child: Row(
          // Official `.oc-mobile-session-row-content` is items-center.
          // Start was a README-trace from the 114.8 invented-air era so
          // time / ··· sat on the title band. Row is 46.4 now — port
          // the official center. Do not screenshot-trace README.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  OcOptical.sessionRowPadH,
                  OcOptical.sessionRowPadV,
                  OcOptical.sessionRowPadRight,
                  OcOptical.sessionRowPadV,
                ),
                child: Row(
                  // Official `.oc-mobile-session-row-main` is items-center.
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
                            halfLead: OcOptical.sessionTitleHalfLead,
                            stem: OcOptical.sessionTitleStem,
                            style: TextStyle(
                              fontSize: OcOptical.rowTitle,
                              // Official `.oc-mobile-session-title` is
                              // `font-medium` / unread `font-semibold`.
                              // ReviewSans Medium covers Latin. CJK uses
                              // the PingFang Medium optical cut (review
                              // Noto DemiLight@500 — not Noto Medium).
                              // w600 snaps to that cut — not Noto Bold.
                              // Do not stem.
                              fontWeight: row.unread ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: OcOptical.rowTitleTracking,
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
            SizedBox(
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
            const SizedBox(width: OcOptical.sessionMoreEdge),
          ],
        ),
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
