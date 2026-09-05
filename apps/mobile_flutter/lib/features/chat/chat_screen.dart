import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/chat_timeline.dart';
import '../../data/diagnostics_export.dart';
import '../../data/composer_session_pick.dart';
import '../../data/context_usage.dart';
import '../../data/home_session.dart';
import '../../data/local_chat_commands.dart';
import '../../data/message_id.dart';
import '../../data/message_queue.dart';
import '../../data/chat_parts.dart';
import '../../data/openchamber_http.dart';
import '../../data/question_request.dart';
import '../../data/session_swipe.dart';
import '../projects/action_dialogs.dart';
import '../../data/prompt_attachment.dart';
import '../../l10n/app_strings.dart';
import '../../navigation/platform_route.dart';
import '../../data/file_preview.dart';
import '../../native/haptics.dart';
import '../../native/live_activity_controller.dart';
import '../../native/media_channel.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import '../files/changes_sheet.dart';
import '../files/file_preview_scope.dart';
import '../files/files_browser_sheet.dart';
import '../files/html_preview_sheet.dart';
import '../files/mcp_overlay_sheet.dart';
import '../shell/secondary_chrome.dart';
import 'chat_transcript_row.dart';
import 'composer_bar.dart';
import 'composer_occupancy.dart';
import 'composer_session_chips.dart';
import 'ios_composer_host.dart';
import 'queued_message_chips.dart';
import 'tool_cards.dart';
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
  List<String> _commands = const [];
  List<String> _files = const [];
  List<String> _skills = const [];
  List<String> _snippets = const [];
  String? _editingMessageId;
  MessageQueueScope? _queue;
  int _seenQueueEpoch = 0;
  List<QuestionRequest> _questions = const [];
  Offset? _swipeStart;
  Offset? _swipeLast;

  LiveActivityController get _live => widget.appController?.liveActivity ?? LiveActivityController();

  @override
  void initState() {
    super.initState();
    if (!_session.isDraft) _live.selectSession(_session.id);
    final handoff = widget.appController?.takePendingComposerHandoff(_session.id);
    if (handoff != null) {
      _composer.text = handoff.text;
      _attachments.addAll(handoff.attachments);
    }
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SecondaryChrome.chatOpened();
      _jumpToLatest();
    });
    widget.appController?.addListener(_onApp);
    if (_session.isDraft) {
      unawaited(_loadComposerCatalogs());
    } else {
      unawaited(_load());
    }
  }

  void _onApp() {
    final controller = widget.appController;
    if (controller == null || !mounted) return;
    if (!_session.isDraft) {
      final match = controller.sessionById(_session.id);
      if (match != null &&
          (match.title != _session.title ||
              match.kind != _session.kind ||
              match.shareUrl != _session.shareUrl)) {
        setState(() => _session = match);
      }
    }
    if (!_session.isDraft && controller.transcriptEpoch != _seenEpoch) {
      _seenEpoch = controller.transcriptEpoch;
      unawaited(_reloadFromLive());
    }
    if (!_session.isDraft && controller.messageQueueEpoch != _seenQueueEpoch) {
      _seenQueueEpoch = controller.messageQueueEpoch;
      unawaited(_refreshQueue());
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
      final structureChanged = _timeline.applyMessages(messages);
      if (structureChanged) {
        recordChatTranscriptDiagnostics(
          kind: 'sse-event',
          sessionID: _session.id,
          directory: _session.directory,
          transport: controller.liveEventTransport,
          source: 'sse',
          messages: messages,
        );
      }
      _contextTick.value += 1;
      _syncBusyFromController();
      unawaited(_refreshQuestions());
    } on OpenChamberHttpException catch (error) {
      recordChatTranscriptDiagnostics(
        kind: 'request-error',
        sessionID: _session.id,
        directory: _session.directory,
        source: 'sse',
        requestStatus: 'error',
        purpose: 'load-failed',
        error: error,
      );
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
      recordChatTranscriptDiagnostics(
        kind: 'ensure-initial',
        sessionID: _session.id,
        directory: _session.directory,
        transport: controller.liveEventTransport,
        source: 'network',
        purpose: 'ensure-initial',
        messages: messages,
      );
      _contextTick.value += 1;
      _errorKey.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
      await controller.refreshSessionStatus(directory: _session.directory);
      await controller.ensureContextLimits();
      _contextTick.value += 1;
      _syncBusyFromController();
      unawaited(_refreshQueue());
      unawaited(_refreshQuestions());
      unawaited(_loadComposerCatalogs());
      unawaited(controller.remoteSettings.loadAgents());
      if (mounted) setState(() {});
    } on OpenChamberHttpException catch (error) {
      if (!mounted) return;
      recordChatTranscriptDiagnostics(
        kind: 'request-error',
        sessionID: _session.id,
        directory: _session.directory,
        source: 'network',
        requestStatus: 'error',
        purpose: 'load-failed',
        error: error,
      );
      _errorKey.value = 'chat.error.loadFailed';
    }
  }

  Future<void> _loadComposerCatalogs() async {
    final controller = widget.appController;
    if (controller == null) return;
    final slash = await controller.composerSuggestions(text: '/', directory: _session.directory);
    final at = await controller.composerSuggestions(text: '@', directory: _session.directory ?? '/workspace');
    final skills = await controller.composerSuggestions(text: ' /', directory: _session.directory);
    final hash = await controller.composerSuggestions(text: '#', directory: _session.directory);
    if (!mounted) return;
    setState(() {
      _commands = slash.map((item) => item.label.replaceFirst('/', '')).toList();
      _files = at.map((item) => item.label.replaceFirst('@', '')).toList();
      _skills = skills.map((item) => item.label.replaceFirst('/', '')).toList();
      _snippets = hash.map((item) => item.label.replaceFirst('#', '')).toList();
    });
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
      await _acceptAttachments(picked);
    } on PromptAttachmentUploadError {
      if (mounted) _errorKey.value = 'chat.error.attachFailed';
    }
  }

  Future<void> _attachFiles() async {
    try {
      final picked = await _media.pickFiles();
      await _acceptAttachments(picked);
    } on PromptAttachmentUploadError {
      if (mounted) _errorKey.value = 'chat.error.attachFailed';
    }
  }

  Future<void> _acceptAttachments(List<AttachmentDraft> picked) async {
    try {
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

  Future<void> _refreshQuestions() async {
    final controller = widget.appController;
    if (controller == null) return;
    final next = await controller.loadQuestions(_session);
    if (!mounted) return;
    if (next == null) return;
    setState(() => _questions = next);
  }

  Future<void> _refreshQueue() async {
    final controller = widget.appController;
    if (controller == null) return;
    try {
      final scope = await controller.loadMessageQueueScope(_session);
      if (!mounted) return;
      setState(() => _queue = scope);
    } on OpenChamberHttpException {
      if (!mounted) return;
      // Preserve the last chips; failure is not empty success.
    }
  }

  ComposerSessionPick get _pick {
    final controller = widget.appController;
    if (controller == null) return ComposerSessionPick.fromSettings(null);
    return controller.sessionPick(_session.id);
  }

  Future<void> _send([String? raw]) async {
    final body = (raw ?? _composer.text).trim();
    if (body.isEmpty && _attachments.isEmpty) return;
    final controller = widget.appController;
    if (controller != null && _attachments.isEmpty && await _handleSlashCommand(body)) {
      return;
    }
    if (controller != null && _session.isDraft) {
      final created = await controller.materializeDraft(_session);
      if (created == null) {
        _errorKey.value = controller.createSessionErrorKey ?? 'projects.newChat.failed';
        return;
      }
      if (mounted) setState(() => _session = created);
      _live.selectSession(created.id);
    }
    final pending = List<AttachmentDraft>.from(_attachments);
    if (controller != null &&
        !_session.isDraft &&
        controller.followUpBehavior == 'queue' &&
        _busy.value &&
        (body.isNotEmpty || pending.isNotEmpty)) {
      _composer.clear();
      setState(() => _attachments.clear());
      _errorKey.value = null;
      try {
        final admitted = await controller.admitQueuedFollowUp(
          session: _session,
          text: body,
          current: _queue,
          attachments: pending,
        );
        if (admitted != null) {
          await _refreshQueue();
          return;
        }
        _composer.text = body;
        setState(() {
          _attachments
            ..clear()
            ..addAll(pending);
        });
      } on PromptAttachmentUploadError {
        _composer.text = body;
        setState(() {
          _attachments
            ..clear()
            ..addAll(pending);
        });
        _errorKey.value = 'chat.error.attachFailed';
        return;
      } on OpenChamberHttpException {
        _composer.text = body;
        setState(() {
          _attachments
            ..clear()
            ..addAll(pending);
        });
        _errorKey.value = 'chat.queuedMessage.admitFailed';
        return;
      }
    }
    final messageId = ascendingId('msg');
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
      final editId = _editingMessageId;
      if (editId != null) {
        await controller.revertSession(session: _session, messageId: editId);
        _editingMessageId = null;
      }
      await controller.sendPrompt(
        session: _session,
        messageId: messageId,
        text: body,
        attachments: pending,
        pick: _pick,
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
        final structureChanged = _timeline.applyMessages(messages);
        if (structureChanged) {
          recordChatTranscriptDiagnostics(
            kind: 'refresh',
            sessionID: _session.id,
            directory: _session.directory,
            source: 'network',
            purpose: 'poll',
            messages: messages,
          );
        }
        await controller.refreshSessionStatus(directory: _session.directory);
        _syncBusyFromController();
        if (!_busy.value || ticks >= 30) timer.cancel();
      } on OpenChamberHttpException {
        timer.cancel();
      }
    });
  }

  Future<bool> _handleSlashCommand(String body) async {
    final controller = widget.appController;
    if (controller == null) return false;
    if (isModelSlashCommand(body)) {
      _composer.clear();
      if (!mounted) return true;
      final selected = await showComposerModelPicker(
        context: context,
        models: controller.composerModels,
        selectedId: _pick.modelKey,
      );
      if (selected != null) {
        controller.setSessionPick(_session.id, _pick.copyWith(providerId: selected.providerId, modelId: selected.modelId));
      }
      return true;
    }
    if (!consumesImmediateCommandText(body)) return false;
    final command = getLocalChatCommand(body);
    _composer.clear();
    _errorKey.value = null;
    switch (command) {
      case 'compact':
        final ok = await controller.summarizeSession(
          session: _session,
          providerId: _pick.providerId,
          modelId: _pick.modelId,
        );
        if (!ok && mounted) _errorKey.value = controller.lastMutationErrorKey ?? 'chat.chatInput.toast.compactFailed';
        return true;
      case 'undo':
        ChatMessage? target;
        for (final message in _timeline.oldestFirst.reversed) {
          if (message.isUser) {
            target = message;
            break;
          }
        }
        if (target == null) return true;
        final ok = await controller.revertSession(session: _session, messageId: target.id);
        if (!ok && mounted) _errorKey.value = controller.lastMutationErrorKey ?? 'chat.messageBody.actions.revertFailed';
        if (ok) await _reloadFromLive();
        return true;
      case 'redo':
        final restored = await controller.unrevertSession(session: _session);
        if (!restored && mounted) _errorKey.value = controller.lastMutationErrorKey;
        if (restored) await _reloadFromLive();
        return true;
      case 'fork':
        final forked = await controller.forkSession(session: _session);
        if (forked != null && mounted) {
          await Navigator.of(context).pushReplacement(
            platformPageRoute<void>(builder: (_) => ChatScreen(session: forked, appController: controller)),
          );
        } else if (mounted) {
          _errorKey.value = controller.lastMutationErrorKey ?? 'chat.messageBody.actions.forkFailed';
        }
        return true;
      case 'new':
        final draft = controller.openNewSessionDraft(directory: _session.directory);
        if (draft != null && mounted) {
          await Navigator.of(context).pushReplacement(
            platformPageRoute<void>(builder: (_) => ChatScreen(session: draft, appController: controller)),
          );
        } else if (mounted) {
          _errorKey.value = controller.createSessionErrorKey ?? 'projects.newChat.needsServer';
        }
        return true;
      default:
        return false;
    }
  }

  Future<void> _replyQuestion(String requestId, List<List<String>> answers) async {
    final controller = widget.appController;
    if (controller == null) return;
    try {
      await controller.replyToQuestion(session: _session, requestId: requestId, answers: answers);
      await _reloadFromLive();
    } on OpenChamberHttpException {
      if (mounted) _errorKey.value = 'chat.questionCard.submitFailed';
    }
  }

  Future<void> _rejectQuestion(String requestId) async {
    final controller = widget.appController;
    if (controller == null) return;
    try {
      await controller.rejectQuestion(session: _session, requestId: requestId);
      await _reloadFromLive();
    } on OpenChamberHttpException {
      if (mounted) _errorKey.value = 'chat.questionCard.dismissFailed';
    }
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
      items: [
        ...buildChatWorkspaceOverflowItems(
          onNewSession: () => unawaited(_newSession(context)),
          onFiles: () => unawaited(_openFiles(context)),
          onChanges: () => unawaited(_openChanges(context)),
          onMcp: () => unawaited(_openMcp(context)),
          onRefreshTranscript: () => unawaited(_refreshTranscript(context)),
        ),
        ...buildSessionOverflowItems(
          pinned: session.kind == HomeSessionKind.pinned,
          shared: session.isShared,
          onRename: controller == null ? () {} : () => unawaited(_renameSession(context)),
          onTogglePin: controller == null ? () {} : () => unawaited(_mutateSession(() => controller.toggleSessionPin(session))),
          onShare: controller == null ? null : () => unawaited(_shareSession(context, session)),
          onCopyLink: session.isShared ? () => unawaited(_copyShareUrl(context, session.shareUrl!)) : null,
          onUnshare: controller == null ? null : () => unawaited(_mutateSession(() => controller.unshareSession(session))),
          onRefreshTranscript: () => unawaited(_refreshTranscript(context)),
          includeRefresh: false,
          onArchive: controller == null ? () {} : () => unawaited(_archiveSession(context)),
          onDelete: controller == null ? () {} : () => unawaited(_deleteSession(context)),
        ),
      ],
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

  Future<void> _copyMessage(ChatMessage message) async {
    final text = message.body.trim();
    if (text.isEmpty) return;
    final ok = await copyTextToClipboard(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, ok ? 'sessions.sidebar.session.menu.copied' : 'sessions.sidebar.session.share.copyUrlError'))),
    );
  }

  Future<void> _revertMessage(ChatMessage message) async {
    final controller = widget.appController;
    if (controller == null) return;
    final ok = await controller.revertSession(session: _session, messageId: message.id);
    if (!mounted) return;
    if (!ok) {
      final error = controller.lastMutationErrorKey;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, error))));
      }
      return;
    }
    await _reloadFromLive();
  }

  void _editMessage(ChatMessage message) {
    _editingMessageId = message.id;
    _composer.text = message.body;
    _composer.selection = TextSelection.collapsed(offset: _composer.text.length);
    setState(() {});
  }

  Future<void> _forkMessage(ChatMessage message) async {
    final controller = widget.appController;
    if (controller == null) return;
    final forked = await controller.forkSession(session: _session, messageId: message.id);
    if (!mounted) return;
    if (forked == null) {
      final error = controller.lastMutationErrorKey;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, error))));
      }
      return;
    }
    await Navigator.of(context).pushReplacement(
      platformPageRoute<void>(
        builder: (_) => ChatScreen(session: forked, appController: controller),
      ),
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

  Future<void> _newSession(BuildContext context) async {
    final controller = widget.appController;
    if (controller == null) return;
    final draft = controller.openNewSessionDraft(directory: _session.directory);
    if (!context.mounted) return;
    if (draft == null) {
      final error = controller.createSessionErrorKey;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, error))));
      }
      return;
    }
    await Navigator.of(context).pushReplacement(
      platformPageRoute<void>(
        builder: (_) => ChatScreen(session: draft, appController: controller),
      ),
    );
  }

  Future<void> _switchSwipeSession(SessionSwipeDirection direction) async {
    final controller = widget.appController;
    if (controller == null || _session.isDraft) return;
    final next = swipeNeighbor(sessions: controller.sessions, currentId: _session.id, direction: direction);
    if (next == null) return;
    await NativeHaptics().impact(HapticStrength.medium);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      platformPageRoute<void>(
        builder: (_) => ChatScreen(session: next, appController: controller),
      ),
    );
  }

  Widget _withComposerSwipe(Widget child) {
    return GestureDetector(
      key: const Key('composer-session-swipe'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        final composerActive = FocusManager.instance.primaryFocus?.hasFocus == true;
        final backEdge = defaultTargetPlatform == TargetPlatform.iOS &&
            details.globalPosition.dx <= nativeIosBackEdgeWidth;
        if (!shouldStartSessionSwipe(onExplicitSurface: true, composerActive: composerActive, withinNativeBackEdge: backEdge)) {
          _swipeStart = null;
          return;
        }
        _swipeStart = details.globalPosition;
        _swipeLast = details.globalPosition;
      },
      onHorizontalDragUpdate: (details) {
        if (_swipeStart == null) return;
        _swipeLast = details.globalPosition;
      },
      onHorizontalDragEnd: (_) {
        final start = _swipeStart;
        final last = _swipeLast;
        _swipeStart = null;
        _swipeLast = null;
        if (start == null || last == null) return;
        final direction = evaluateSwipeDirection(
          startX: start.dx,
          startY: start.dy,
          endX: last.dx,
          endY: last.dy,
        );
        if (direction == null) return;
        unawaited(_switchSwipeSession(direction));
      },
      child: child,
    );
  }

  Future<void> _openFiles(BuildContext context) async {
    final controller = widget.appController;
    if (controller == null) return;
    final directory = _session.directory ?? await controller.filesystemHome();
    if (!context.mounted) return;
    await showFilesBrowserSheet(context: context, controller: controller, directory: directory);
  }

  Future<void> _openChanges(BuildContext context) async {
    final controller = widget.appController;
    if (controller == null) return;
    final directory = _session.directory;
    if (directory == null || directory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, 'mobile.files.empty.noDirectory'))));
      return;
    }
    await showChangesSheet(context: context, controller: controller, directory: directory);
  }

  Future<void> _openMcp(BuildContext context) async {
    final controller = widget.appController;
    if (controller == null) return;
    await showMcpOverlaySheet(context: context, controller: controller, directory: _session.directory);
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
    final messenger = ScaffoldMessenger.of(context);
    final success = t(context, 'sessions.sidebar.session.archive.success');
    final undo = t(context, 'sessions.sidebar.undo');
    final session = _session;
    final controller = widget.appController;
    final ok = await _mutateSession(() => controller!.archiveSession(session));
    if (ok && context.mounted) Navigator.of(context).maybePop();
    if (ok && controller != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(success),
          action: SnackBarAction(
            key: const Key('session-archive-undo'),
            label: undo,
            onPressed: () => unawaited(controller.unarchiveSession(session)),
          ),
        ),
      );
    }
  }

  Future<void> _sendQueuedNow(MessageQueueItem item) async {
    final controller = widget.appController;
    final scope = _queue;
    if (controller == null || scope == null) return;
    final ok = await controller.sendQueuedItemNow(session: _session, item: item, scope: scope);
    if (ok) await _refreshQueue();
  }

  Future<void> _removeQueued(MessageQueueItem item) async {
    final controller = widget.appController;
    final scope = _queue;
    if (controller == null || scope == null) return;
    final ok = await controller.removeQueuedItem(session: _session, item: item, scope: scope);
    if (ok) await _refreshQueue();
  }

  Future<void> _editQueued(MessageQueueItem item) async {
    final controller = widget.appController;
    final scope = _queue;
    if (controller == null || scope == null) return;
    final restored = await controller.editQueuedItemIntoComposer(
      session: _session,
      item: item,
      scope: scope,
    );
    if (restored == null || !mounted) return;
    _composer.text = restored.text;
    _composer.selection = TextSelection.collapsed(offset: _composer.text.length);
    setState(() {
      _attachments
        ..clear()
        ..addAll(restored.attachments);
    });
    await _refreshQueue();
  }

  Future<void> _reorderQueued(int from, int to) async {
    final controller = widget.appController;
    final scope = _queue;
    if (controller == null || scope == null) return;
    final ok = await controller.reorderQueuedItems(session: _session, scope: scope, from: from, to: to);
    if (ok) await _refreshQueue();
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
                      queuedChipHeight: (_queue?.items.isNotEmpty ?? false) ? queuedMessageChipsOccupancy : 0,
                      sessionChipHeight: widget.appController == null ? 0 : composerSessionChipHeight,
                      questionFooterHeight: _questions.isEmpty ? 0 : 220,
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
                      onQuestionReply: widget.appController == null ? null : _replyQuestion,
                      onQuestionReject: widget.appController == null ? null : _rejectQuestion,
                      onCopy: _copyMessage,
                      onShare: _copyMessage,
                      onFork: widget.appController == null ? null : _forkMessage,
                      onRevert: widget.appController == null ? null : _revertMessage,
                      onEdit: _editMessage,
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
                      title: _session.isDraft
                          ? t(context, 'sessions.switcher.draftTitle')
                          : _session.title,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_questions.isNotEmpty)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
                        child: ListView(
                          key: const Key('chat-question-footer'),
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          children: [
                            for (final question in _questions)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: QuestionReplyCard(
                                  part: questionPartFromRequest(question),
                                  onReply: _replyQuestion,
                                  onReject: _rejectQuestion,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (widget.appController != null)
                      ListenableBuilder(
                        listenable: widget.appController!,
                        builder: (context, _) {
                          return ComposerSessionChips(
                            pick: widget.appController!.sessionPick(_session.id),
                            models: widget.appController!.composerModels,
                            agents: widget.appController!.remoteSettings.agents.value ?? const [],
                            onChanged: (next) => widget.appController!.setSessionPick(_session.id, next),
                          );
                        },
                      ),
                    if (_queue != null && _queue!.items.isNotEmpty)
                      QueuedMessageChips(
                        items: _queue!.items,
                        onSendNow: (item) => unawaited(_sendQueuedNow(item)),
                        onRemove: (item) => unawaited(_removeQueued(item)),
                        onEdit: (item) => unawaited(_editQueued(item)),
                        onReorder: (from, to) => unawaited(_reorderQueued(from, to)),
                      ),
                    _withComposerSwipe(
                      ios
                          ? SizedBox(
                              height: collapsedComposerOccupancy + padding.bottom,
                              child: ListenableBuilder(
                                listenable: Listenable.merge([_busy, _composer]),
                                builder: (context, _) {
                                  final busy = _busy.value;
                                  final queueFollowUp = widget.appController?.followUpBehavior == 'queue';
                                  final hasDraft = _composer.text.trim().isNotEmpty || _attachments.isNotEmpty;
                                  return IosComposerHost(
                                    visible: true,
                                    warm: false,
                                    text: _composer.text,
                                    canSend: hasDraft,
                                    canAbort: busy && !(queueFollowUp && hasDraft),
                                    attachments: _attachments.map((item) => item.name).toList(),
                                    onSend: _send,
                                    onStop: _stop,
                                    onAttach: _attach,
                                    onPickedFiles: (drafts) => unawaited(_acceptAttachments(drafts)),
                                    onText: (value) => _composer.text = value,
                                    commands: _commands,
                                    files: _files,
                                    skills: _skills,
                                    snippets: _snippets,
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
                                  queueFollowUp: widget.appController?.followUpBehavior == 'queue',
                                  attachments: _attachments,
                                  showScrollToBottom: !_atLiveEdge.value || _timeline.length >= 2,
                                  onScrollToBottom: _jumpToLatest,
                                  onSend: _send,
                                  onStop: _stop,
                                  onAttach: _attach,
                                  onAttachFiles: _attachFiles,
                                  onRemoveAttachment: (index) => setState(() => _attachments.removeAt(index)),
                                  commands: _commands,
                                  files: _files,
                                  skills: _skills,
                                  snippets: _snippets,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
