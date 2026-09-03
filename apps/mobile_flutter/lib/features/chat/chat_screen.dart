import 'package:flutter/material.dart';

import '../../data/chat_timeline.dart';
import '../../data/home_session.dart';
import 'composer_bar.dart';
import 'reverse_chat_list.dart';

/// Pushed secondary page — never a dock tab.
/// 1.19.3-beta.5: re-entry jumps to the latest message (reverse index 0).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.session, this.timeline});

  final HomeSessionRow session;
  final ReverseChatController? timeline;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ReverseChatController _timeline = widget.timeline ?? ReverseChatController(seed: demoTranscript());
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(ReverseChatController.latestReverseIndex.toDouble());
  }

  void _send() {
    final body = _composer.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _timeline.appendNewer(
        ChatMessage(id: 'local-${DateTime.now().microsecondsSinceEpoch}', body: body, isUser: true),
      );
      _composer.clear();
    });
    _jumpToLatest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.title),
        leading: BackButton(key: const Key('chat-back'), onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: Column(
        children: [
          Expanded(
            child: ReverseChatList(
              controller: _timeline,
              scrollController: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemBuilder: (context, message, reverseIndex) {
                final align = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
                return Align(
                  alignment: align,
                  child: Container(
                    key: Key('chat-message-${message.id}'),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(message.body),
                  ),
                );
              },
            ),
          ),
          ComposerBar(controller: _composer, onSend: _send),
        ],
      ),
    );
  }
}
