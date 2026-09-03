import 'package:flutter/widgets.dart';

import '../../data/chat_timeline.dart';

/// Reverse chat list — LegendList analogue.
///
/// Index 0 is the newest message (visual bottom). Prepending older history
/// does not move the live edge. Do not use TanStack Virtual, StickToBottom,
/// or Virtua.
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
    return ListView.builder(
      key: const Key('reverse-chat-list'),
      controller: scrollController,
      reverse: true,
      padding: padding,
      itemCount: controller.length,
      itemBuilder: (context, index) {
        return itemBuilder(context, controller.newestAtReverseIndex(index), index);
      },
    );
  }
}
