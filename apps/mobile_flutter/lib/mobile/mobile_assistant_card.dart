import 'package:flutter/material.dart';

import '../features/projects/highlighted_text.dart';
import '../motion/pressable.dart';
import '../native/haptics.dart';
import '../theme/ios_chrome.dart';
import 'mobile_surface.dart';

/// Official `hashAgentSeed` — unsigned 32-bit geometry hash.
int hashAgentSeed(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = ((hash << 5) - hash + unit).toSigned(32);
  }
  return hash.toUnsigned(32);
}

/// Official `getAgentColor` signed hash. Empty / `build` stay index 0.
int agentColorIndex(String seed) {
  if (seed.isEmpty || seed == 'build') return 0;
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = ((hash << 5) - hash + unit).toSigned(32);
  }
  return 1 + (hash.abs() % 7);
}

/// Official 5×5 mirrored identicon from [hashAgentSeed].
List<List<bool>> agentIdenticonMatrix(String seed) {
  const grid = 5;
  const half = 3;
  final matrix = List.generate(grid, (_) => List<bool>.filled(grid, false));
  if (seed.isEmpty) return matrix;
  var bits = hashAgentSeed(seed);
  for (var y = 0; y < grid; y++) {
    for (var x = 0; x < half; x++) {
      final on = (bits & 1) == 1;
      bits >>>= 1;
      matrix[y][x] = on;
      matrix[y][grid - 1 - x] = on;
    }
  }
  return matrix;
}

/// Official `AgentAvatar` identicon inside the 40/38 assistant ring.
class AgentIdenticon extends StatelessWidget {
  const AgentIdenticon({super.key, required this.seed, required this.size});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final palette = tokens.agentPalette;
    final color = palette[agentColorIndex(seed) % palette.length];
    return CustomPaint(
      size: Size.square(size),
      painter: _IdenticonPainter(
        matrix: agentIdenticonMatrix(seed),
        color: color,
      ),
    );
  }
}

class _IdenticonPainter extends CustomPainter {
  const _IdenticonPainter({required this.matrix, required this.color});

  final List<List<bool>> matrix;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 5;
    canvas.drawRect(Offset.zero & size, Paint()..color = color.withValues(alpha: 0.14));
    final fill = Paint()..color = color;
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 5; x++) {
        if (!matrix[y][x]) continue;
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IdenticonPainter old) =>
      old.color != color || old.matrix != matrix;
}

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
    this.seed,
    this.pressKey,
  });

  final String name;
  final String modeLabel;
  final String summary;
  final VoidCallback onOpen;
  /// Official `AgentAvatar` seed is the assistant id, not the display name.
  final String? seed;
  final Key? pressKey;

  @override
  Widget build(BuildContext context) {
    final modeStyle = TextStyle(
      fontSize: OcOptical.entityMeta,
      fontWeight: FontWeight.w400,
      letterSpacing: OcOptical.metaTracking,
      height: OcOptical.entityMetaHeight,
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: AgentIdenticon(
                          seed: seed ?? name,
                          size: OcOptical.assistantAvatarVisual,
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
                                // Official `.oc-mobile-assistant-name` is
                                // 15/20 / −0.02em (overrides entity-title).
                                // CJK fills Regular Micro Hei on WidgetTester.
                                // Live iOS keeps official Semibold. Not a 3.2 / 1.46 pile.
                                halfLead: 0,
                                style: TextStyle(
                                  fontSize: OcOptical.assistantName,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: OcOptical.assistantNameTrackingOfficial,
                                  height: OcOptical.assistantNameHeight,
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
