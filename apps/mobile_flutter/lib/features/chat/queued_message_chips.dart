import 'package:flutter/material.dart';

import '../../data/message_queue.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import 'composer_occupancy.dart';

/// Cap `QueuedMessageChips` essentials: count + prompt + send-now + remove.
/// Official `/api/openchamber/message-queue` items only — no local ledger.
class QueuedMessageChips extends StatelessWidget {
  const QueuedMessageChips({
    super.key,
    required this.items,
    required this.onSendNow,
    required this.onRemove,
    required this.onEdit,
  });

  final List<MessageQueueItem> items;
  final ValueChanged<MessageQueueItem> onSendNow;
  final ValueChanged<MessageQueueItem> onRemove;
  final ValueChanged<MessageQueueItem> onEdit;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final oc = context.oc;
    return SizedBox(
      key: const Key('queued-message-chips'),
      height: queuedMessageChipsOccupancy,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final preview = item.content.trim().isEmpty
              ? t(context, 'chat.queuedMessage.empty')
              : item.content.trim();
          return Pressable(
            onPressed: () => onEdit(item),
            child: Container(
              key: Key('queued-chip-${item.queueItemID}'),
              constraints: const BoxConstraints(maxWidth: 220, minHeight: 40),
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              decoration: BoxDecoration(
                color: oc.glassChipFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: oc.mobileBorder, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: OcTokens.textMicro,
                        color: oc.foreground,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('queued-chip-send-${item.queueItemID}'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                    tooltip: t(context, 'chat.queuedMessage.send'),
                    onPressed: () => onSendNow(item),
                    icon: OcGlyph(OcGlyphKind.sendPlane, size: 14, color: oc.foreground),
                  ),
                  IconButton(
                    key: Key('queued-chip-remove-${item.queueItemID}'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                    tooltip: t(context, 'chat.queuedMessage.removeAria'),
                    onPressed: () => onRemove(item),
                    icon: OcGlyph(OcGlyphKind.xmark, size: 14, color: oc.mutedForeground),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
