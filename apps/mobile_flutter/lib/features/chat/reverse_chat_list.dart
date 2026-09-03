import 'package:flutter/widgets.dart';

import '../../data/chat_timeline.dart';

/// Reverse chat list — LegendList analogue.
///
/// Index 0 is the newest message (visual bottom). Prepending older history
/// does not move the live edge. Do not use TanStack Virtual, StickToBottom,
/// or Virtua.
///
/// The list rebuilds only when [ReverseChatController] reports a **structure**
/// change. Streaming tokens update per-id [ValueNotifier] slots and must not
/// reconstruct this [ListView].
class ReverseChatList extends StatelessWidget {
  const ReverseChatList({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.scrollController,
    this.padding,
  });

  final ReverseChatController controller;
  final Widget Function(BuildContext context, ChatMessage message, int reverseIndex) itemBuilder;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ListView.builder(
          key: const Key('reverse-chat-list'),
          controller: scrollController,
          reverse: true,
          padding: padding,
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
