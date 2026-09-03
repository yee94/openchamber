import 'package:flutter/material.dart';

import '../data/home_session.dart';
import '../data/relative_time.dart';
import '../features/projects/highlighted_text.dart';
import '../motion/pressable.dart';
import '../native/haptics.dart';
import '../theme/ios_chrome.dart';

/// Official `MobileSessionRow` — one home-list session.
///
/// Source: `packages/ui/src/mobile/projects/MobileSessionRow.tsx`.
/// Session title follows official `.oc-mobile-session-title` 12 / 16 / −0.012em.
class MobileSessionRow extends StatelessWidget {
  const MobileSessionRow({
    super.key,
    required this.row,
    required this.onSelect,
    this.highlightQuery = '',
    this.showUnreadKey = false,
  });

  final HomeSessionRow row;
  final String highlightQuery;
  final VoidCallback onSelect;
  final bool showUnreadKey;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      haptic: HapticStrength.light,
      onPressed: onSelect,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: OcOptical.sessionRowVisualHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, OcOptical.sessionRowPadV, 12, OcOptical.sessionRowPadV),
          child: Row(
            children: [
              Container(
                width: OcOptical.sessionBullet,
                height: OcOptical.sessionBullet,
                decoration: BoxDecoration(
                  color: row.unread ? context.oc.unreadDot : context.oc.mutedForeground.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: row.unread && showUnreadKey ? const SizedBox(key: Key('unread-dot')) : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HighlightedText(
                  row.title,
                  query: highlightQuery,
                  style: const TextStyle(
                    fontSize: OcOptical.rowTitle,
                    fontWeight: FontWeight.w400,
                    letterSpacing: OcOptical.rowTitleTracking,
                    height: OcOptical.rowTitleHeight,
                  ),
                ),
              ),
              if (formatRelativeTime(row.updated) != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: Text(
                    formatRelativeTime(row.updated)!,
                    style: TextStyle(
                      fontSize: OcOptical.sessionTime,
                      fontWeight: FontWeight.w400,
                      letterSpacing: OcOptical.sessionTimeTracking,
                      height: OcOptical.sessionTimeHeight,
                      color: context.oc.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
