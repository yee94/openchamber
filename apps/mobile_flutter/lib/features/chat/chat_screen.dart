import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/chat_timeline.dart';
import '../../data/home_session.dart';
import '../../data/message_id.dart';
import '../../data/openchamber_http.dart';
import '../../l10n/app_strings.dart';
import '../../native/haptics.dart';
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
  late final ReverseChatController _timeline = widget.timeline ?? ReverseChatController();
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<String> _attachments = [];
  final _haptics = NativeHaptics();
  bool _busy = false;
  String? _errorKey;
  Timer? _poll;

  LiveActivityController get _live => widget.appController?.liveActivity ?? LiveActivityController();

  @override
  void initState() {
    super.initState();
    _live.selectSession(widget.session.id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
    unawaited(_load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final controller = widget.appController;
    if (controller == null) {
      setState(() => _errorKey = 'chat.error.loadFailed');
      return;
    }
    try {
      final messages = await controller.loadTranscript(widget.session);
      if (!mounted) return;
      setState(() {
        _timeline.prependOlder(messages);
        _errorKey = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
      await controller.refreshSessionStatus(directory: widget.session.directory);
      _syncBusyFromController();
    } on OpenChamberHttpException {
      if (!mounted) return;
      setState(() {
        _errorKey = 'chat.error.loadFailed';
      });
    }
  }

  void _syncBusyFromController() {
    final status = widget.appController?.sessionStatusById[widget.session.id];
    final busy = status == 'busy' || status == 'retry';
    if (busy) {
      _live.markWorkStarted();
    }
    if (mounted) setState(() => _busy = busy);
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(ReverseChatController.latestReverseIndex.toDouble());
  }

  Future<void> _send([String? raw]) async {
    final body = (raw ?? _composer.text).trim();
    if (body.isEmpty) return;
    final controller = widget.appController;
    final messageId = ascendingId('msg');
    setState(() {
      _timeline.appendNewer(ChatMessage(id: messageId, body: body, isUser: true));
      _composer.clear();
      _attachments.clear();
      _busy = true;
      _errorKey = null;
    });
    _haptics.impact(HapticStrength.medium);
    _jumpToLatest();
    if (controller == null) {
      _errorKey = 'chat.error.sendFailed';
      setState(() => _busy = false);
      return;
    }
    try {
      await controller.sendPrompt(session: widget.session, messageId: messageId, text: body);
      _pollTranscript();
    } on OpenChamberHttpException {
      setState(() {
        _busy = false;
        _errorKey = 'chat.error.sendFailed';
      });
    }
  }

  void _pollTranscript() {
    _poll?.cancel();
    var ticks = 0;
    _poll = Timer.periodic(const Duration(seconds: 2), (timer) async {
      ticks += 1;
      final controller = widget.appController;
      if (controller == null || !mounted) {
        timer.cancel();
        return;
      }
      try {
        final messages = await controller.loadTranscript(widget.session);
        if (!mounted) return;
        setState(() {
          _timeline.replaceAll(messages);
        });
        await controller.refreshSessionStatus(directory: widget.session.directory);
        _syncBusyFromController();
        if (!_busy || ticks >= 30) timer.cancel();
      } on OpenChamberHttpException {
        timer.cancel();
      }
    });
  }

  Future<void> _stop() async {
    _poll?.cancel();
    _haptics.impact(HapticStrength.heavy);
    final controller = widget.appController;
    if (controller != null) {
      try {
        await controller.abortPrompt(widget.session);
      } on OpenChamberHttpException {
        // Stop still clears local busy; server abort failure is surfaced.
        setState(() => _errorKey = 'chat.error.stopFailed');
      }
    }
    if (mounted) setState(() => _busy = false);
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
          if (_errorKey != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(t(context, _errorKey!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
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
