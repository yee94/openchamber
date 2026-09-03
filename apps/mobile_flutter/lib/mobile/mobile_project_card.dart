import 'package:flutter/material.dart';

import '../features/projects/highlighted_text.dart';
import '../l10n/app_strings.dart';
import '../motion/pressable.dart';
import '../native/haptics.dart';
import '../theme/ios_chrome.dart';
import '../theme/oc_glyphs.dart';

/// Official `MobileProjectCard` — project header inside a floating surface.
///
/// Source: `packages/ui/src/mobile/projects/MobileProjectCard.tsx`.
class MobileProjectCard extends StatelessWidget {
  const MobileProjectCard({
    super.key,
    required this.name,
    required this.count,
    required this.expanded,
    required this.onToggle,
    this.glyph = OcGlyphKind.code,
    this.activity,
    this.pathHint,
    this.compact = false,
    this.highlightQuery = '',
  });

  final String name;
  final OcGlyphKind glyph;
  final int count;
  final String? activity;
  final String? pathHint;
  final bool expanded;
  final bool compact;
  final String highlightQuery;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      haptic: HapticStrength.light,
      onPressed: onToggle,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          compact ? OcOptical.groupHeaderPadVCompact : OcOptical.groupHeaderPadV,
          10,
          compact ? OcOptical.groupHeaderPadVCompact : OcOptical.groupHeaderPadV,
        ),
        child: Row(
          children: [
            Container(
              width: compact ? OcOptical.leadingCircleCompact : OcOptical.leadingCircle,
              height: compact ? OcOptical.leadingCircleCompact : OcOptical.leadingCircle,
              decoration: BoxDecoration(
                color: context.oc.muted,
                shape: BoxShape.circle,
              ),
              child: OcGlyph(
                glyph,
                size: compact ? OcOptical.leadingGlyphCompact : OcOptical.leadingGlyph,
                strokeWidth: OcOptical.headerGlyphStroke,
                color: context.oc.mutedForeground,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HighlightedText(
                    name,
                    query: highlightQuery,
                    style: TextStyle(
                      fontSize: compact ? OcOptical.rowTitle : OcOptical.entityTitle,
                      fontWeight: FontWeight.w500,
                      letterSpacing: compact ? OcOptical.rowTitleTracking : OcOptical.entityTitleTracking,
                      height: compact ? OcOptical.rowTitleHeight : OcOptical.entityTitleHeight,
                    ),
                  ),
                  const SizedBox(height: OcOptical.groupTitleMetaGap),
                  Text(
                    [
                      count == 1
                          ? t(context, 'projects.sessionsCount.one')
                          : t(context, 'projects.sessionsCount', {'count': '$count'}),
                      if (activity != null) activity,
                      if (pathHint != null && pathHint!.isNotEmpty) pathHint,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: OcOptical.meta,
                      fontWeight: FontWeight.w400,
                      letterSpacing: OcOptical.metaTracking,
                      height: OcOptical.metaHeight,
                      color: context.oc.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            OcGlyph(
              expanded ? OcGlyphKind.chevronDown : OcGlyphKind.chevronRight,
              size: OcOptical.chevron,
              strokeWidth: OcOptical.headerGlyphStroke,
              color: context.oc.mutedForeground,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 6),
              child: OcGlyph(OcGlyphKind.ellipsis, size: OcOptical.overflow, strokeWidth: OcOptical.headerGlyphStroke, color: context.oc.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}
