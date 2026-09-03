import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/chat_timeline.dart';
import '../../data/dictation.dart';
import '../../data/home_session.dart';
import '../../data/message_id.dart';
import '../../data/openchamber_http.dart';
import '../../data/prompt_attachment.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../native/live_activity_controller.dart';
import '../../native/media_channel.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import '../shell/secondary_chrome.dart';
import 'chat_transcript_row.dart';
import 'composer_bar.dart';
import 'composer_occupancy.dart';
import 'ios_composer_host.dart';
import 'reverse_chat_list.dart';

/// Pushed secondary page — never a dock tab.
/// 1.19.3-beta.5: re-entry jumps to the latest message (reverse index 0).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.session, this.timeline, this.appController, this.media});

  final HomeSessionRow session;
  final ReverseChatController? timeline;
  final AppController? appController;
  final MediaChannel? media;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ReverseChatController _timeline = widget.timeline ?? ReverseChatController();
  late final bool _ownsTimeline = widget.timeline == null;
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<AttachmentDraft> _attachments = [];
  final _haptics = NativeHaptics();
  late final MediaChannel _media = widget.media ?? MediaChannel();
  final ValueNotifier<bool> _busy = ValueNotifier(false);
  final ValueNotifier<bool> _atLiveEdge = ValueNotifier(true);
  final ValueNotifier<String?> _errorKey = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _speakingMessageId = ValueNotifier<String?>(null);
  String? _dictationLabel;
  Timer? _poll;

  DictationSession get _dictation => widget.appController?.dictation ?? UnavailableDictation();

  LiveActivityController get _live => widget.appController?.liveActivity ?? LiveActivityController();

  @override
  void initState() {
    super.initState();
    _live.selectSession(widget.session.id);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SecondaryChrome.chatOpened();
      _jumpToLatest();
    });
    widget.appController?.addListener(_onApp);
    unawaited(_load());
  }

  void _onApp() {
    final controller = widget.appController;
    if (controller == null || !mounted) return;
    if (controller.transcriptEpoch != _seenEpoch) {
      _seenEpoch = controller.transcriptEpoch;
      unawaited(_reloadFromLive());
    }
    _syncBusyFromController();
    if (controller.liveEventsConnected) {
      _poll?.cancel();
      _poll = null;
    } else if (_busy.value && _poll == null) {
      _pollTranscript();
    }
  }

  int _seenEpoch = 0;

  @override
  void dispose() {
    SecondaryChrome.chatClosed();
    widget.appController?.removeListener(_onApp);
    _poll?.cancel();
    _scroll.removeListener(_onScroll);
    _composer.dispose();
    _scroll.dispose();
    _busy.dispose();
    _atLiveEdge.dispose();
    _errorKey.dispose();
    _speakingMessageId.dispose();
    if (_ownsTimeline) _timeline.dispose();
    super.dispose();
  }

  Future<void> _reloadFromLive() async {
    final controller = widget.appController;
    if (controller == null || !mounted) return;
    try {
      final messages = await controller.loadTranscript(widget.session);
      if (!mounted) return;
      // Diff-apply. Do not setState the page — slots update the live row.
      // Do not jumpTo: scrolled-up readers must not be yanked to the live edge.
      _timeline.applyMessages(messages);
      _syncBusyFromController();
    } on OpenChamberHttpException {
      // Keep the last transcript; failure is not empty success.
    }
  }

  Future<void> _load() async {
    final controller = widget.appController;
    if (controller == null) {
      _errorKey.value = 'chat.error.loadFailed';
      return;
    }
    try {
      final messages = await controller.loadTranscript(widget.session);
      if (!mounted) return;
      _timeline.applyMessages(messages);
      _errorKey.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
      await controller.refreshSessionStatus(directory: widget.session.directory);
      _syncBusyFromController();
    } on OpenChamberHttpException {
      if (!mounted) return;
      _errorKey.value = 'chat.error.loadFailed';
    }
  }

  void _syncBusyFromController() {
    final status = widget.appController?.sessionStatusById[widget.session.id];
    final busy = status == 'busy' || status == 'retry';
    if (busy) {
      _live.markWorkStarted();
    }
    if (_busy.value != busy) _busy.value = busy;
  }

  void _onScroll() {
    final atEdge = !_scroll.hasClients || _scroll.offset <= 24;
    if (atEdge == _atLiveEdge.value) return;
    _atLiveEdge.value = atEdge;
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(ReverseChatController.latestReverseIndex.toDouble());
    _onScroll();
  }

  Future<void> _attach() async {
    try {
      final picked = await _media.pickImages();
      final ready = <AttachmentDraft>[];
      for (final draft in picked) {
        var next = draft;
        if (next.isHeic) {
          next = await _media.transcodeHeic(next);
        }
        if (next.bytes.length > maxPromptAttachmentBytes) {
          if (mounted) _errorKey.value = 'chat.error.attachmentTooLarge';
          continue;
        }
        await _media.publishVirtualAsset(next);
        ready.add(next);
      }
      if (!mounted || ready.isEmpty) return;
      setState(() {
        _attachments.addAll(ready);
      });
      _errorKey.value = null;
    } on PromptAttachmentUploadError {
      if (mounted) _errorKey.value = 'chat.error.attachFailed';
    }
  }

  Future<void> _send([String? raw]) async {
    final body = (raw ?? _composer.text).trim();
    if (body.isEmpty && _attachments.isEmpty) return;
    final controller = widget.appController;
    final messageId = ascendingId('msg');
    final pending = List<AttachmentDraft>.from(_attachments);
    _timeline.appendNewer(
      ChatMessage(id: messageId, body: body.isEmpty ? pending.map((item) => item.name).join(', ') : body, isUser: true),
    );
    _composer.clear();
    setState(() => _attachments.clear());
    _busy.value = true;
    _errorKey.value = null;
    _jumpToLatest();
    if (controller == null) {
      _errorKey.value = 'chat.error.sendFailed';
      _busy.value = false;
      return;
    }
    try {
      await controller.sendPrompt(
        session: widget.session,
        messageId: messageId,
        text: body,
        attachments: pending,
      );
      if (controller.liveEventsConnected) {
        _poll?.cancel();
        _poll = null;
      } else {
        _pollTranscript();
      }
    } on PromptAttachmentUploadError {
      setState(() {
        _attachments
          ..clear()
          ..addAll(pending);
      });
      _busy.value = false;
      _errorKey.value = 'chat.error.attachFailed';
    } on OpenChamberHttpException {
      _busy.value = false;
      _errorKey.value = 'chat.error.sendFailed';
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
        _timeline.applyMessages(messages);
        await controller.refreshSessionStatus(directory: widget.session.directory);
        _syncBusyFromController();
        if (!_busy.value || ticks >= 30) timer.cancel();
      } on OpenChamberHttpException {
        timer.cancel();
      }
    });
  }

  Future<void> _replyPermission(String requestId, String reply) async {
    final controller = widget.appController;
    if (controller == null) return;
    try {
      await controller.replyToPermission(session: widget.session, requestId: requestId, reply: reply);
      await _reloadFromLive();
    } on OpenChamberHttpException {
      if (mounted) _errorKey.value = 'chat.error.permissionFailed';
    }
  }

  Future<void> _speak(ChatMessage message) async {
    final controller = widget.appController;
    if (controller == null) return;
    if (_speakingMessageId.value == message.id) {
      await controller.stopSpeaking();
      if (mounted) _speakingMessageId.value = null;
      return;
    }
    final text = message.parts
        .where((part) => part.kind == ChatPartKind.text)
        .map((part) => part.body?.trim() ?? '')
        .where((item) => item.isNotEmpty)
        .join('\n');
    final spoken = text.isNotEmpty ? text : message.body;
    _speakingMessageId.value = message.id;
    try {
      await controller.speakMessage(spoken);
    } on OpenChamberHttpException {
      if (mounted) _errorKey.value = 'chat.error.ttsFailed';
    } finally {
      if (mounted) _speakingMessageId.value = null;
    }
  }

  Future<void> _dictate() async {
    final session = _dictation;
    if (session.status == DictationStatus.recording) {
      final result = await session.confirm();
      if (!mounted) return;
      if (result != null && result.text.isNotEmpty) {
        _composer.text = _composer.text.isEmpty ? result.text : '${_composer.text} ${result.text}';
        setState(() => _dictationLabel = null);
      } else {
        setState(() => _dictationLabel = t(context, 'chat.dictation.failed'));
      }
      return;
    }
    await session.start();
    if (!mounted) return;
    setState(() {
      _dictationLabel = session.status == DictationStatus.failed
          ? t(context, 'chat.dictation.unavailable')
          : t(context, 'chat.dictation.listening');
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
        _errorKey.value = 'chat.error.stopFailed';
      }
    }
    if (mounted) _busy.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final inset = MediaQuery.viewInsetsOf(context);
    final view = MediaQuery.viewPaddingOf(context);
    final navH = PushedNavBar.overlayHeight(context);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: !ios,
      backgroundColor: context.oc.pageBackground,
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: _timeline,
            builder: (context, _) {
              final composerReserve = composerListReserve(
                ios: ios,
                viewBottom: view.bottom,
                insetBottom: inset.bottom,
                showScrollToBottom: _timeline.length >= 2,
              );
              return ReverseChatList(
                controller: _timeline,
                scrollController: _scroll,
                padding: EdgeInsets.fromLTRB(12, navH, 12, composerReserve + 12),
                itemBuilder: (context, message, reverseIndex) {
                  return ChatTranscriptRow(
                    controller: _timeline,
                    messageId: message.id,
                    reverseIndex: reverseIndex,
                    busy: _busy,
                    speakingId: _speakingMessageId,
                    onSpeak: widget.appController == null ? null : _speak,
                    onPermission: widget.appController == null ? null : _replyPermission,
                  );
                },
              );
            },
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _errorKey,
            builder: (context, errorKey, _) {
              if (errorKey == null) return const SizedBox.shrink();
              return Positioned(
                top: navH,
                left: 8,
                right: 8,
                child: Text(t(context, errorKey), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _busy,
              builder: (context, busy, _) {
                return PushedNavBar(
                  title: widget.session.title,
                  subtitle: widget.session.subtitle,
                  leadingKey: const Key('chat-back'),
                  busy: busy,
                  trailing: Pressable(
                    haptic: HapticStrength.light,
                    highlight: false,
                    onPressed: () {},
                    child: SizedBox(
                      width: OcOptical.headerDisc,
                      height: OcOptical.headerDisc,
                      child: Center(
                        child: OcGlassChip(
                          child: OcGlyph(
                            OcGlyphKind.ellipsis,
                            size: OcOptical.headerGlyph,
                            strokeWidth: OcOptical.headerGlyphStrokeVisual,
                            color: context.oc.foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ios ? 0 : inset.bottom,
            child: ios
                ? SizedBox(
                    height: collapsedComposerOccupancy + MediaQuery.paddingOf(context).bottom,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _busy,
                      builder: (context, busy, _) {
                        return IosComposerHost(
                          visible: true,
                          warm: false,
                          text: _composer.text,
                          canSend: _composer.text.trim().isNotEmpty || _attachments.isNotEmpty,
                          canAbort: busy,
                          attachments: _attachments.map((item) => item.name).toList(),
                          onSend: _send,
                          onStop: _stop,
                          onAttach: _attach,
                          onDictate: _dictate,
                          onText: (value) => _composer.text = value,
                        );
                      },
                    ),
                  )
                : ListenableBuilder(
                    listenable: Listenable.merge([_busy, _atLiveEdge, _timeline]),
                    builder: (context, _) {
                      return ComposerBar(
                        controller: _composer,
                        busy: _busy.value,
                        attachments: _attachments,
                        dictationLabel: _dictationLabel,
                        showScrollToBottom: !_atLiveEdge.value || _timeline.length >= 2,
                        onScrollToBottom: _jumpToLatest,
                        onSend: _send,
                        onStop: _stop,
                        onAttach: _attach,
                        onDictate: widget.appController?.dictation is UnavailableDictation ? null : _dictate,
                        onRemoveAttachment: (index) => setState(() => _attachments.removeAt(index)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
