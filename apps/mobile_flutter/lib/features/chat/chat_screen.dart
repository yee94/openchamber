import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/chat_timeline.dart';
import '../../data/context_usage.dart';
import '../../data/home_session.dart';
import '../../data/message_id.dart';
import '../../data/openchamber_http.dart';
import '../projects/action_dialogs.dart';
import '../../data/prompt_attachment.dart';
import '../../l10n/app_strings.dart';
import '../../data/file_preview.dart';
import '../../native/haptics.dart';
import '../../native/live_activity_controller.dart';
import '../../native/media_channel.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import '../files/file_preview_scope.dart';
import '../files/html_preview_sheet.dart';
import '../shell/secondary_chrome.dart';
import 'chat_transcript_row.dart';
import 'composer_bar.dart';
import 'composer_occupancy.dart';
import 'ios_composer_host.dart';
import 'reverse_chat_list.dart';
import 'session_metadata_sheet.dart';
import 'session_overflow_sheet.dart';

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
  late HomeSessionRow _session = widget.session;
  late final ReverseChatController _timeline = widget.timeline ?? ReverseChatController();
  late final bool _ownsTimeline = widget.timeline == null;
  final ValueNotifier<int> _contextTick = ValueNotifier(0);
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<AttachmentDraft> _attachments = [];
  final _haptics = NativeHaptics();
  late final MediaChannel _media = widget.media ?? MediaChannel();
  final ValueNotifier<bool> _busy = ValueNotifier(false);
  final ValueNotifier<bool> _atLiveEdge = ValueNotifier(true);
  final ValueNotifier<String?> _errorKey = ValueNotifier<String?>(null);
  Timer? _poll;

  LiveActivityController get _live => widget.appController?.liveActivity ?? LiveActivityController();

  @override
  void initState() {
    super.initState();
    _live.selectSession(_session.id);
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
    final match = controller.sessionById(_session.id);
    if (match != null &&
        (match.title != _session.title ||
            match.kind != _session.kind ||
            match.shareUrl != _session.shareUrl)) {
      setState(() => _session = match);
    }
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
    _contextTick.dispose();
    if (_ownsTimeline) _timeline.dispose();
    super.dispose();
  }

  Future<void> _reloadFromLive() async {
    final controller = widget.appController;
    if (controller == null || !mounted) return;
    try {
      final messages = await controller.loadTranscript(_session);
      if (!mounted) return;
      // Diff-apply. Do not setState the page — slots update the live row.
      // Do not jumpTo: scrolled-up readers must not be yanked to the live edge.
      _timeline.applyMessages(messages);
      _contextTick.value += 1;
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
      final messages = await controller.loadTranscript(_session);
      if (!mounted) return;
      _timeline.applyMessages(messages);
      _contextTick.value += 1;
      _errorKey.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
      await controller.refreshSessionStatus(directory: _session.directory);
      await controller.ensureContextLimits();
      _contextTick.value += 1;
      _syncBusyFromController();
    } on OpenChamberHttpException {
      if (!mounted) return;
      _errorKey.value = 'chat.error.loadFailed';
    }
  }

  void _syncBusyFromController() {
    final status = widget.appController?.sessionStatusById[_session.id];
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
      final prepared = await prepareComposerAttachments(
        picked: picked,
        transcodeHeic: _media.transcodeHeic,
      );
      if (!mounted) return;
      if (prepared.ready.isEmpty) {
        if (prepared.errorKey != null) _errorKey.value = prepared.errorKey;
        return;
      }
      for (final draft in prepared.ready) {
        await _media.publishVirtualAsset(draft);
      }
      if (!mounted) return;
      setState(() {
        _attachments.addAll(prepared.ready);
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
        session: _session,
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
        final messages = await controller.loadTranscript(_session);
        if (!mounted) return;
        _timeline.applyMessages(messages);
        await controller.refreshSessionStatus(directory: _session.directory);
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
      await controller.replyToPermission(session: _session, requestId: requestId, reply: reply);
      await _reloadFromLive();
    } on OpenChamberHttpException {
      if (mounted) _errorKey.value = 'chat.error.permissionFailed';
    }
  }

  Future<void> _stop() async {
    _poll?.cancel();
    _haptics.impact(HapticStrength.heavy);
    final controller = widget.appController;
    if (controller != null) {
      try {
        await controller.abortPrompt(_session);
      } on OpenChamberHttpException {
        _errorKey.value = 'chat.error.stopFailed';
      }
    }
    if (mounted) _busy.value = false;
  }

  MobileContextDisplay? _contextDisplay() {
    final controller = widget.appController;
    final tokens = getLatestAssistantTotalTokens(_timeline.oldestFirst);
    final model = getLatestUserMessageModel(_timeline.oldestFirst);
    final limit = resolveContextLimit(
      catalogLimits: controller?.contextLimits ?? const {},
      providerID: model?.providerID,
      modelID: model?.modelID,
      defaultModel: controller?.remoteSettings.blob.value?.defaultModel,
    );
    return buildMobileContextDisplay(totalTokens: tokens, contextLimit: limit ?? 0);
  }

  void _openSessionOverflow(BuildContext context) {
    unawaited(_openSessionOverflowAsync(context));
  }

  Future<void> _openSessionOverflowAsync(BuildContext context) async {
    final controller = widget.appController;
    var session = _session;
    if (controller != null) {
      session = await controller.hydrateSessionShare(session);
      if (mounted) setState(() => _session = session);
    }
    if (!context.mounted) return;
    await showSessionOverflowSheet(
      context: context,
      title: session.title,
      items: buildSessionOverflowItems(
        pinned: session.kind == HomeSessionKind.pinned,
        shared: session.isShared,
        onRename: controller == null ? () {} : () => unawaited(_renameSession(context)),
        onTogglePin: controller == null ? () {} : () => unawaited(_mutateSession(() => controller.toggleSessionPin(session))),
        onShare: controller == null ? null : () => unawaited(_shareSession(context, session)),
        onCopyLink: session.isShared ? () => unawaited(_copyShareUrl(context, session.shareUrl!)) : null,
        onUnshare: controller == null ? null : () => unawaited(_mutateSession(() => controller.unshareSession(session))),
        onRefreshTranscript: () => unawaited(_refreshTranscript(context)),
        onArchive: controller == null ? () {} : () => unawaited(_archiveSession(context)),
        onDelete: controller == null ? () {} : () => unawaited(_deleteSession(context)),
      ),
    );
  }

  Future<void> _shareSession(BuildContext context, HomeSessionRow session) async {
    final controller = widget.appController;
    if (controller == null) return;
    final ok = await controller.shareSession(session);
    if (!context.mounted) return;
    if (!ok) {
      await _mutateSession(() async => false);
      return;
    }
    final match = controller.sessionById(session.id);
    if (match != null && mounted) setState(() => _session = match);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'sessions.sidebar.session.share.successTitle'))),
    );
  }

  Future<void> _copyShareUrl(BuildContext context, String url) async {
    final ok = await copyTextToClipboard(url);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(context, ok ? 'sessions.sidebar.session.menu.copied' : 'sessions.sidebar.session.share.copyUrlError'),
        ),
      ),
    );
  }

  Future<void> _renameSession(BuildContext context) async {
    final next = await showTextPromptDialog(
      context: context,
      titleKey: 'sessions.sidebar.session.menu.rename',
      fieldLabelKey: 'sessions.sidebar.session.menu.rename',
      confirmKey: 'sessions.sidebar.session.rename.save',
      cancelKey: 'sessions.sidebar.session.rename.cancel',
      initial: _session.title,
      fieldKey: const Key('session-rename-field'),
      confirmWidgetKey: const Key('session-rename-save'),
    );
    if (next == null || !context.mounted) return;
    await _mutateSession(() => widget.appController!.renameSession(_session, next));
  }

  Future<void> _refreshTranscript(BuildContext context) async {
    if (_busy.value) return;
    await _reloadFromLive();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'sessions.sidebar.session.refresh.success'))),
    );
  }

  Future<void> _archiveSession(BuildContext context) async {
    final ok = await _mutateSession(() => widget.appController!.archiveSession(_session));
    if (ok && context.mounted) Navigator.of(context).maybePop();
  }

  Future<void> _deleteSession(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context: context,
      titleKey: 'sessions.sidebar.dialogs.deleteSession.title',
      messageKey: 'sessions.sidebar.dialogs.deleteSession.single',
      confirmKey: 'sessions.sidebar.bulkActions.delete',
      cancelKey: 'sessions.sidebar.session.rename.cancel',
      messageParams: {'sessionTitle': _session.title},
      confirmWidgetKey: const Key('session-delete-confirm'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await _mutateSession(() => widget.appController!.deleteSession(_session));
    if (ok && context.mounted) Navigator.of(context).maybePop();
  }

  Future<bool> _mutateSession(Future<bool> Function() run) async {
    final controller = widget.appController;
    if (controller == null) return false;
    final ok = await run();
    if (!mounted) return ok;
    final error = controller.lastMutationErrorKey;
    if (!ok && error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, error))));
    }
    return ok;
  }

  Future<void> _openContextMetadata(BuildContext context) async {
    final controller = widget.appController;
    if (controller != null) {
      await controller.ensureContextLimits();
      if (controller.remoteSettings.usage.value == null) {
        await controller.remoteSettings.loadUsage();
      }
    }
    if (!context.mounted) return;
    final branch = _session.branch?.trim();
    await showSessionMetadataSheet(
      context: context,
      branchLabel: (branch == null || branch.isEmpty)
          ? t(context, 'common.unavailable')
          : branch,
      contextDisplay: _contextDisplay(),
      quotas: controller?.remoteSettings.usage.value ?? const [],
    );
  }

  void _openFilePath(String path) {
    if (!isHtmlFile(path)) return;
    final controller = widget.appController;
    unawaited(showHtmlPreviewSheet(
      context: context,
      path: path,
      loadContent: controller == null
          ? (target) async => ''
          : controller.readWorkspaceFile,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final navH = PushedNavBar.overlayHeight(context);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: context.oc.pageBackground,
      body: Builder(
        builder: (context) {
          final padding = MediaQuery.paddingOf(context);
          return Stack(
            children: [
              FilePreviewScope(
                onOpenPath: _openFilePath,
                child: ReverseChatList(
                  controller: _timeline,
                  scrollController: _scroll,
                  paddingBuilder: (length) {
                    final composerReserve = composerListReserve(
                      ios: ios,
                      paddingBottom: padding.bottom,
                      showScrollToBottom: length >= 2,
                    );
                    return EdgeInsets.fromLTRB(12, navH, 12, composerReserve + 12);
                  },
                  itemBuilder: (context, message, reverseIndex) {
                    return ChatTranscriptRow(
                      controller: _timeline,
                      messageId: message.id,
                      reverseIndex: reverseIndex,
                      busy: _busy,
                      onPermission: widget.appController == null ? null : _replyPermission,
                    );
                  },
                ),
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
                      title: _session.title,
                      subtitle: _session.subtitle,
                      leadingKey: const Key('chat-back'),
                      busy: busy,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: _contextTick,
                            builder: (context, _, _) {
                              return OcDetailNavChip(
                                key: const Key('chat-context'),
                                semanticLabel: t(context, 'mobile.header.openMetadataAria'),
                                onPressed: () => unawaited(_openContextMetadata(context)),
                                child: OcContextProgressIcon(
                                  percentage: _contextDisplay()?.percentage ?? 0,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: OcOptical.detailNavTrailingGap),
                          OcDetailNavChip(
                            key: const Key('chat-more'),
                            semanticLabel: t(context, 'mobile.menu.titleAria'),
                            glyph: OcGlyphKind.ellipsis,
                            onPressed: () => _openSessionOverflow(context),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ios
                    ? SizedBox(
                        height: collapsedComposerOccupancy + padding.bottom,
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
                            showScrollToBottom: !_atLiveEdge.value || _timeline.length >= 2,
                            onScrollToBottom: _jumpToLatest,
                            onSend: _send,
                            onStop: _stop,
                            onAttach: _attach,
                            onRemoveAttachment: (index) => setState(() => _attachments.removeAt(index)),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
