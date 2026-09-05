import 'package:flutter/material.dart';

import '../../data/message_queue.dart';
import '../../l10n/app_strings.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import 'composer_occupancy.dart';

/// Cap `QueuedMessageChips`: send-now + remove + reserve-edit + drag-reorder.
/// Official `/api/openchamber/message-queue` items only — no local ledger.
class QueuedMessageChips extends StatelessWidget {
  const QueuedMessageChips({
    super.key,
    required this.items,
    required this.onSendNow,
    required this.onRemove,
    required this.onEdit,
    required this.onReorder,
  });

  final List<MessageQueueItem> items;
  final ValueChanged<MessageQueueItem> onSendNow;
  final ValueChanged<MessageQueueItem> onRemove;
  final ValueChanged<MessageQueueItem> onEdit;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final oc = context.oc;
    return SizedBox(
      key: const Key('queued-message-chips'),
      height: queuedMessageChipsOccupancy,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        proxyDecorator: (child, index, animation) => child,
        onReorder: onReorder,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final preview = item.content.trim().isEmpty
              ? (item.attachments.isEmpty
                  ? t(context, 'chat.queuedMessage.empty')
                  : item.attachments.first.filename)
              : item.content.trim();
          return ReorderableDelayedDragStartListener(
            key: Key('queued-chip-${item.queueItemID}'),
            index: index,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 220, minHeight: 40),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              decoration: BoxDecoration(
                color: oc.glassChipFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: oc.mobileBorder, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: OcGlyph(OcGlyphKind.file, size: 12, color: oc.mutedForeground),
                    ),
                  Flexible(
                    child: GestureDetector(
                      onTap: () => onEdit(item),
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
