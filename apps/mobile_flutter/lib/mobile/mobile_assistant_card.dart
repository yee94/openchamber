import 'package:flutter/material.dart';

import '../features/projects/highlighted_text.dart';
import '../motion/pressable.dart';
import '../native/haptics.dart';
import '../theme/ios_chrome.dart';
import 'mobile_surface.dart';

/// Official `MobileAssistantCard` — catalog row inside a floating surface.
///
/// Source: `packages/ui/src/mobile/assistant/MobileAssistantTab.tsx` +
/// `.oc-mobile-assistant-card*` in `mobile.css`.
class MobileAssistantCard extends StatelessWidget {
  const MobileAssistantCard({
    super.key,
    required this.name,
    required this.modeLabel,
    required this.summary,
    required this.onOpen,
    this.pressKey,
  });

  final String name;
  final String modeLabel;
  final String summary;
  final VoidCallback onOpen;
  final Key? pressKey;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : String.fromCharCode(name.runes.first);
    final modeStyle = TextStyle(
      fontSize: OcOptical.meta,
      fontWeight: FontWeight.w400,
      letterSpacing: OcOptical.metaTracking,
      height: OcOptical.metaHeight,
      color: context.oc.mutedForeground,
    );
    return MobileFloatingSurface(
      margin: const EdgeInsets.fromLTRB(
        OcChrome.pageGutter,
        0,
        OcChrome.pageGutter,
        OcOptical.assistantCatalogGap,
      ),
      child: Pressable(
        key: pressKey,
        haptic: HapticStrength.light,
        onPressed: onOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: OcOptical.assistantCardMinHeight),
          child: Padding(
            padding: const EdgeInsets.all(OcOptical.assistantCardPad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: OcOptical.assistantAvatar,
                  height: OcOptical.assistantAvatar,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.oc.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: Center(
                        child: HighlightedText(
                          initial,
                          query: '',
                          halfLead: 0,
                          style: TextStyle(
                            fontSize: OcOptical.projectTitle,
                            fontWeight: FontWeight.w600,
                            color: context.oc.foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: OcOptical.assistantCardGap),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: HighlightedText(
                                name,
                                query: '',
                                // Official root `oc-mobile-entity-title` is 16/20.
                                // CJK fills Regular Micro Hei on WidgetTester.
                                // Live iOS keeps official Semibold. Not a 3.2 / 1.46 pile.
                                halfLead: 0,
                                style: TextStyle(
                                  fontSize: OcOptical.entityTitle,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: OcOptical.entityTitleTracking,
                                  height: OcOptical.entityTitleHeight,
                                  color: context.oc.foreground,
                                ),
                              ),
                            ),
                            const SizedBox(width: OcOptical.assistantHeaderGap),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.oc.surfaceMuted,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: OcOptical.assistantModePadH,
                                  vertical: OcOptical.assistantModePadV,
                                ),
                                child: Text(modeLabel, style: ocCssInk(modeStyle)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: OcOptical.assistantSummaryGap),
                        Text(
                          summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: OcTokens.textMicro,
                            fontWeight: FontWeight.w400,
                            height: OcOptical.assistantSummaryHeight,
                            color: context.oc.mutedForeground,
                          ),
                        ),
                      ],
                    ),
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
