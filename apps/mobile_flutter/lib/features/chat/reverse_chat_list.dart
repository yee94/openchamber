import 'package:flutter/widgets.dart';

import '../../data/chat_rebuild_counters.dart';
import '../../data/chat_timeline.dart';

/// Reverse chat list — LegendList analogue.
///
/// Index 0 is the newest message (visual bottom). Prepending older history
/// does not move the live edge. Do not use TanStack Virtual, StickToBottom,
/// or Virtua.
///
/// The list rebuilds only when [ReverseChatController] reports a **structure**
/// change. Streaming tokens update per-id [ValueNotifier] slots and must not
/// reconstruct this [ListView]. Padding that depends on length is computed
/// here so [ChatScreen] does not also subscribe to structure notifies.
class ReverseChatList extends StatelessWidget {
  const ReverseChatList({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.scrollController,
    this.padding,
    this.paddingBuilder,
  });

  final ReverseChatController controller;
  final Widget Function(BuildContext context, ChatMessage message, int reverseIndex) itemBuilder;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry Function(int length)? paddingBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        ChatRebuildCounters.recordListStructure();
        return ListView.builder(
          key: const Key('reverse-chat-list'),
          controller: scrollController,
          reverse: true,
          padding: paddingBuilder?.call(controller.length) ?? padding,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          findChildIndexCallback: (key) {
            if (key is ValueKey<String>) {
              return controller.reverseIndexOfId(key.value);
            }
            return null;
          },
          itemCount: controller.length,
          itemBuilder: (context, index) {
            final message = controller.newestAtReverseIndex(index);
            ChatRebuildCounters.recordRowWidget(message.id);
            return KeyedSubtree(
              key: ValueKey<String>(message.id),
              child: itemBuilder(context, message, index),
            );
          },
        );
      },
    );
  }
}
