import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/chat_timeline.dart';
import '../../data/home_session.dart';
import '../../native/live_activity_controller.dart';
import 'composer_bar.dart';
import 'composer_occupancy.dart';
import 'ios_composer_host.dart';
import 'reverse_chat_list.dart';

/// Pushed secondary page — never a dock tab.
/// 1.19.3-beta.5: re-entry jumps to the latest message (reverse index 0).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.session, this.timeline, this.appController});

  final HomeSessionRow session;
  final ReverseChatController? timeline;
  final AppController? appController;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ReverseChatController _timeline = widget.timeline ?? ReverseChatController(seed: demoTranscript());
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<String> _attachments = [];
  bool _busy = false;
  Timer? _workTimer;

  LiveActivityController get _live => widget.appController?.liveActivity ?? LiveActivityController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
    _live.selectSession(widget.session.id);
    if (widget.session.kind == HomeSessionKind.inProgress) {
      _startDemoWork();
    }
  }

  @override
  void dispose() {
    _workTimer?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _startDemoWork() {
    _busy = true;
    _live.markWorkStarted();
    _workTimer = Timer(liveActivityBusyDelay, () async {
      await _live.startIfDue();
      if (mounted) setState(() {});
    });
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(ReverseChatController.latestReverseIndex.toDouble());
  }

  void _send([String? raw]) {
    final body = (raw ?? _composer.text).trim();
    if (body.isEmpty) return;
    setState(() {
      _timeline.appendNewer(
        ChatMessage(id: 'local-${DateTime.now().microsecondsSinceEpoch}', body: body, isUser: true),
      );
      _composer.clear();
      _attachments.clear();
      _busy = true;
    });
    _live.markWorkStarted();
    _workTimer?.cancel();
    _workTimer = Timer(liveActivityBusyDelay, () async {
      await _live.startIfDue();
      if (mounted) setState(() {});
    });
    _jumpToLatest();
  }

  void _stop() {
    _workTimer?.cancel();
    _live.complete(error: false);
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final inset = MediaQuery.viewInsetsOf(context);
    return Scaffold(
      resizeToAvoidBottomInset: !ios,
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
          if (ios)
            SizedBox(
              height: collapsedComposerOccupancy + MediaQuery.paddingOf(context).bottom,
              child: IosComposerHost(
                visible: true,
                warm: false,
                text: _composer.text,
                canSend: _composer.text.trim().isNotEmpty,
                canAbort: _busy,
                attachments: _attachments,
                onSend: _send,
                onStop: _stop,
                onAttach: () => setState(() => _attachments.add('attachment-${_attachments.length + 1}')),
                onText: (value) => setState(() => _composer.text = value),
              ),
            )
          else
            ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: EdgeInsets.only(bottom: inset.bottom),
                child: ComposerBar(
                  controller: _composer,
                  busy: _busy,
                  onSend: _send,
                  onStop: _stop,
                  onAttach: () => setState(() => _attachments.add('attachment-${_attachments.length + 1}')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
