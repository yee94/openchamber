import 'package:flutter/foundation.dart';

/// LegendList analogue for Flutter chat.
///
/// Official 1.19 timeline (`packages/ui/src/components/chat/TimelineList.tsx`)
/// uses `@legendapp/list` with `initialScrollAtEnd`, `maintainScrollAtEnd`,
/// and `maintainVisibleContentPosition` so prepending older history does not
/// jump the reading position. Do **not** port TanStack Virtual, StickToBottom,
/// or Virtua.
///
/// Flutter mapping: a `ListView.builder(reverse: true)` whose index 0 is the
/// newest message (visual bottom). Prepending older items appends to the
/// unreversed oldest-first buffer, which becomes high indices — the reverse
/// scroller keeps its bottom-relative offset.
///
/// Listeners of this controller fire only on **structure** (ids / order /
/// length). Per-message content updates go through [slotFor] so a streaming
/// token cannot rebuild the whole list.
enum ChatPartKind { text, mermaid, diff, fileOp, permission, task, tool, reasoning }

class DiffLine {
  const DiffLine({required this.kind, required this.text});

  /// `add`, `remove`, or `context`.
  final String kind;
  final String text;
}

class ChatPart {
  const ChatPart({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.body,
    this.status,
    this.toolName,
    this.path,
    this.added = const [],
    this.removed = const [],
    this.diffLines = const [],
    this.permissionId,
    this.tokensPerSecond,
    this.patterns = const [],
    this.metadata = const {},
  });

  final String id;
  final ChatPartKind kind;
  final String title;
  final String? subtitle;
  final String? body;
  final String? status;
  final String? toolName;
  final String? path;
  final List<String> added;
  final List<String> removed;
  final List<DiffLine> diffLines;
  final String? permissionId;
  final String? tokensPerSecond;
  final List<String> patterns;
  final Map<String, Object?> metadata;

  bool get isPendingPermission => kind == ChatPartKind.permission && permissionId != null;

  bool sameContent(ChatPart other) {
    return id == other.id &&
        kind == other.kind &&
        title == other.title &&
        subtitle == other.subtitle &&
        body == other.body &&
        status == other.status &&
        toolName == other.toolName &&
        path == other.path &&
        permissionId == other.permissionId &&
        tokensPerSecond == other.tokensPerSecond &&
        added.length == other.added.length &&
        removed.length == other.removed.length &&
        diffLines.length == other.diffLines.length &&
        patterns.length == other.patterns.length;
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.isUser,
    this.parts = const [],
    this.tokensPerSecond,
    this.modelName,
    this.agentRole,
    this.processedLabel,
    this.completedClock,
    this.agentCount = 0,
    this.errorKind,
    this.errorText,
  });

  final String id;
  final String body;
  final bool isUser;
  final List<ChatPart> parts;
  final String? tokensPerSecond;
  final String? modelName;
  final String? agentRole;
  final String? processedLabel;
  final String? completedClock;
  final int agentCount;

  /// Official `resolveAssistantErrorPresentation`: `aborted` | `error`.
  final String? errorKind;
  final String? errorText;

  ChatMessage copyWith({List<ChatPart>? parts, String? errorKind, String? errorText}) {
    return ChatMessage(
      id: id,
      body: body,
      isUser: isUser,
      parts: parts ?? this.parts,
      tokensPerSecond: tokensPerSecond,
      modelName: modelName,
      agentRole: agentRole,
      processedLabel: processedLabel,
      completedClock: completedClock,
      agentCount: agentCount,
      errorKind: errorKind ?? this.errorKind,
      errorText: errorText ?? this.errorText,
    );
  }

  bool sameContent(ChatMessage other) {
    if (id != other.id ||
        body != other.body ||
        isUser != other.isUser ||
        tokensPerSecond != other.tokensPerSecond ||
        modelName != other.modelName ||
        agentRole != other.agentRole ||
        processedLabel != other.processedLabel ||
        completedClock != other.completedClock ||
        agentCount != other.agentCount ||
        errorKind != other.errorKind ||
        errorText != other.errorText ||
        parts.length != other.parts.length) {
      return false;
    }
    for (var i = 0; i < parts.length; i += 1) {
      if (!parts[i].sameContent(other.parts[i])) return false;
    }
    return true;
  }
}

class ReverseChatController extends ChangeNotifier {
  ReverseChatController({List<ChatMessage>? seed}) {
    if (seed != null) {
      _oldestFirst.addAll(seed);
      for (final message in seed) {
        _slots[message.id] = ValueNotifier<ChatMessage>(message);
      }
    }
  }

  final List<ChatMessage> _oldestFirst = [];
  final Map<String, ValueNotifier<ChatMessage>> _slots = {};

  /// Oldest → newest. Reverse list renders this from the end.
  List<ChatMessage> get oldestFirst => List.unmodifiable(_oldestFirst);

  int get length => _oldestFirst.length;

  /// How many times the list structure notified (not per-token slot writes).
  int structureNotifyCount = 0;

  ChatMessage newestAtReverseIndex(int reverseIndex) {
    return _oldestFirst[_oldestFirst.length - 1 - reverseIndex];
  }

  String idAtReverseIndex(int reverseIndex) => newestAtReverseIndex(reverseIndex).id;

  int? reverseIndexOfId(String id) {
    final logical = _oldestFirst.indexWhere((message) => message.id == id);
    if (logical < 0) return null;
    return _oldestFirst.length - 1 - logical;
  }

  ValueNotifier<ChatMessage> slotFor(String id) {
    return _slots.putIfAbsent(
      id,
      () => ValueNotifier<ChatMessage>(ChatMessage(id: id, body: '', isUser: false)),
    );
  }

  bool isNewestAssistant(int reverseIndex) {
    if (_oldestFirst.isEmpty) return false;
    for (var i = 0; i < reverseIndex; i += 1) {
      if (!newestAtReverseIndex(i).isUser) return false;
    }
    return !newestAtReverseIndex(reverseIndex).isUser;
  }

  /// Insert older history at the top of the logical transcript.
  void prependOlder(List<ChatMessage> older) {
    if (older.isEmpty) return;
    _oldestFirst.insertAll(0, older);
    for (final message in older) {
      _writeSlot(message);
    }
    _notifyStructure();
  }

  void appendNewer(ChatMessage message) {
    _oldestFirst.add(message);
    _writeSlot(message);
    _notifyStructure();
  }

  void replaceAll(List<ChatMessage> messages) => applyMessages(messages);

  /// Diff-apply a fetched transcript. Unchanged rows keep their [ValueNotifier]
  /// identity; only mutated ids notify their slot. Structure notifies only when
  /// ids or order change — not on every SSE token of the live tail.
  void applyMessages(List<ChatMessage> messages) {
    var structureChanged = messages.length != _oldestFirst.length;
    if (!structureChanged) {
      for (var i = 0; i < messages.length; i += 1) {
        if (messages[i].id != _oldestFirst[i].id) {
          structureChanged = true;
          break;
        }
      }
    }

    final incomingIds = <String>{};
    final next = <ChatMessage>[];
    for (final message in messages) {
      incomingIds.add(message.id);
      final existing = _slots[message.id];
      if (existing != null && existing.value.sameContent(message)) {
        next.add(existing.value);
      } else {
        _writeSlot(message);
        next.add(message);
      }
    }

    final stale = _slots.keys.where((id) => !incomingIds.contains(id)).toList();
    for (final id in stale) {
      _slots.remove(id)?.dispose();
    }

    _oldestFirst
      ..clear()
      ..addAll(next);
    if (structureChanged) _notifyStructure();
  }

  void _writeSlot(ChatMessage message) {
    final existing = _slots[message.id];
    if (existing == null) {
      _slots[message.id] = ValueNotifier<ChatMessage>(message);
      return;
    }
    if (!existing.value.sameContent(message)) {
      existing.value = message;
    }
  }

  void _notifyStructure() {
    structureNotifyCount += 1;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final slot in _slots.values) {
      slot.dispose();
    }
    _slots.clear();
    super.dispose();
  }

  /// 1.19.3-beta.5: re-entering a session scrolls to latest, not the last
  /// sent user message. Reverse index 0 is that latest edge.
  static const int latestReverseIndex = 0;
}

List<ChatMessage> demoTranscript() => const [
      ChatMessage(id: 'm1', body: 'Open a session from Projects.', isUser: true),
      ChatMessage(
        id: 'm2',
        body: 'This list is a reverse LegendList analogue. Older history prepends without jumping the live edge.',
        isUser: false,
      ),
      ChatMessage(id: 'm3', body: 'Re-entering this session jumps to the latest message.', isUser: true),
    ];
