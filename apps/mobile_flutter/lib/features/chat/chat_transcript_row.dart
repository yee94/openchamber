import 'package:flutter/material.dart';

import '../../data/chat_rebuild_counters.dart';
import '../../data/chat_timeline.dart';
import '../../data/context_tool_grouping.dart';
import '../../theme/ios_chrome.dart';
import 'tool_cards.dart';

/// One reverse-list row. Subscribes to that message's slot so a token on
/// another row cannot rebuild this body.
class ChatTranscriptRow extends StatelessWidget {
  const ChatTranscriptRow({
    super.key,
    required this.controller,
    required this.messageId,
    required this.reverseIndex,
    required this.busy,
    this.onPermission,
    this.onCopy,
    this.onShare,
    this.onFork,
    this.onRevert,
    this.onEdit,
  });

  final ReverseChatController controller;
  final String messageId;
  final int reverseIndex;
  final ValueNotifier<bool> busy;
  final void Function(String requestId, String reply)? onPermission;
  final void Function(ChatMessage message)? onCopy;
  final void Function(ChatMessage message)? onShare;
  final void Function(ChatMessage message)? onFork;
  final void Function(ChatMessage message)? onRevert;
  final void Function(ChatMessage message)? onEdit;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChatMessage>(
      valueListenable: controller.slotFor(messageId),
      builder: (context, message, _) {
        return ListenableBuilder(
          listenable: busy,
          builder: (context, _) {
            ChatRebuildCounters.recordRowSlot(message.id);
            final isLastAssistant = !message.isUser && controller.isNewestAssistant(reverseIndex);
            final isStreamingAssistant = busy.value && isLastAssistant;
            final isTurnLive = isStreamingAssistant && messageHasRunningTool(message);
            if (message.isUser) {
              return Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  key: Key('chat-message-${message.id}'),
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: Color.lerp(context.oc.card, context.oc.primary, 0.10),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ChatTranscriptBody(
                          message: message,
                          isLastAssistant: isLastAssistant,
                          isTurnLive: isTurnLive,
                          isStreaming: isStreamingAssistant,
                          onCopy: onCopy == null ? null : () => onCopy!(message),
                          onShare: onShare == null ? null : () => onShare!(message),
                          onFork: onFork == null ? null : () => onFork!(message),
                        ),
                      ),
                      UserTurnToolbar(
                        message: message,
                        onCopy: onCopy == null ? null : () => onCopy!(message),
                        onFork: onFork == null ? null : () => onFork!(message),
                        onRevert: onRevert == null ? null : () => onRevert!(message),
                        onEdit: onEdit == null ? null : () => onEdit!(message),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Padding(
              key: Key('chat-message-${message.id}'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ChatTranscriptBody(
                message: message,
                isLastAssistant: isLastAssistant,
                isTurnLive: isTurnLive,
                isStreaming: isStreamingAssistant,
                onPermission: onPermission,
                onCopy: onCopy == null ? null : () => onCopy!(message),
                onShare: onShare == null ? null : () => onShare!(message),
                onFork: onFork == null ? null : () => onFork!(message),
              ),
            );
          },
        );
      },
    );
  }
}
