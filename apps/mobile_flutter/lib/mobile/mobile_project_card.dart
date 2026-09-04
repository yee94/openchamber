import 'package:flutter/material.dart';

import '../features/projects/highlighted_text.dart';
import '../l10n/app_strings.dart';
import '../motion/pressable.dart';
import '../native/haptics.dart';
import '../theme/ios_chrome.dart';
import '../theme/oc_glyphs.dart';

/// Official `MobileProjectCard` — project header inside a floating surface.
///
/// Source: `packages/ui/src/mobile/projects/MobileProjectCard.tsx` +
/// `.oc-mobile-project-shell` / `.oc-mobile-project-card` in `mobile.css`.
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
    final metaStyle = TextStyle(
      fontSize: OcOptical.meta,
      fontWeight: FontWeight.w400,
      letterSpacing: OcOptical.metaTracking,
      height: OcOptical.metaHeight,
      color: context.oc.mutedForeground,
    );
    final metaInk = ocCssInk(metaStyle)!;
    return Pressable(
      haptic: HapticStrength.light,
      onPressed: onToggle,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: compact ? 0 : OcOptical.projectHeaderHeight,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            OcOptical.projectTriggerPad,
            compact ? OcOptical.groupHeaderPadVCompact : OcOptical.projectTriggerPad,
            OcOptical.projectTriggerPad,
            compact ? OcOptical.groupHeaderPadVCompact : OcOptical.projectTriggerPad,
          ),
          child: Row(
            children: [
              SizedBox(
                width: compact ? OcOptical.leadingCircleCompact : OcOptical.leadingCircle,
                height: compact ? OcOptical.leadingCircleCompact : OcOptical.leadingCircle,
                child: Center(
                  child: Container(
                    width: compact ? OcOptical.leadingCircleCompact : OcOptical.leadingCircleVisual,
                    height: compact ? OcOptical.leadingCircleCompact : OcOptical.leadingCircleVisual,
                    decoration: BoxDecoration(
                      color: context.oc.glassChipFill,
                      shape: BoxShape.circle,
                      boxShadow: OcElevation.glassHighlight(context),
                    ),
                    alignment: Alignment.center,
                    child: OcGlyph(
                      glyph,
                      size: compact ? OcOptical.leadingGlyphCompact : OcOptical.leadingGlyphVisual,
                      strokeWidth: OcOptical.headerGlyphStroke,
                      color: context.oc.mutedForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: OcOptical.projectTriggerGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightedText(
                      name,
                      query: highlightQuery,
                      style: TextStyle(
                        fontSize: compact ? OcOptical.rowTitle : OcOptical.projectTitle,
                        fontWeight: FontWeight.w600,
                        letterSpacing: compact ? OcOptical.rowTitleTracking : OcOptical.projectTitleTracking,
                        height: compact ? OcOptical.rowTitleHeight : OcOptical.projectTitleHeight,
                        color: context.oc.foreground,
                      ),
                    ),
                    const SizedBox(height: OcOptical.groupTitleMetaGap),
                    OcCssLine(
                      style: metaStyle,
                      child: Row(
                        children: [
                          Text(
                            count == 1
                                ? t(context, 'projects.sessionsCount.one')
                                : t(context, 'projects.sessionsCount', {'count': '$count'}),
                            style: metaInk,
                          ),
                          if (activity != null && activity!.isNotEmpty) ...[
                            const SizedBox(width: OcOptical.entityMetaGap),
                            Text(
                              '·',
                              style: metaInk,
                            ),
                            const SizedBox(width: OcOptical.entityMetaGap),
                            Text(activity!, style: metaInk),
                          ],
                          if (pathHint != null && pathHint!.isNotEmpty) ...[
                            const SizedBox(width: OcOptical.entityMetaGap),
                            Text(
                              '·',
                              style: metaInk,
                            ),
                            const SizedBox(width: OcOptical.entityMetaGap),
                            Expanded(
                              child: Text(
                                pathHint!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: metaInk,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              OcGlyph(
                expanded ? OcGlyphKind.chevronDown : OcGlyphKind.chevronRight,
                size: OcOptical.chevron,
                strokeWidth: OcOptical.listGlyphStroke,
                color: context.oc.mutedForeground,
              ),
              Padding(
                padding: const EdgeInsets.only(right: OcOptical.projectActionMargin),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: OcGlyph(
                      OcGlyphKind.ellipsis,
                      size: OcOptical.overflow,
                      strokeWidth: OcOptical.listGlyphStroke,
                      color: context.oc.mutedForeground,
                    ),
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
