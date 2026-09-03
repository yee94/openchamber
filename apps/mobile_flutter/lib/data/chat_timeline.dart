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
enum ChatPartKind { text, mermaid, diff, fileOp, permission, task, tool }

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
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.isUser,
    this.parts = const [],
    this.tokensPerSecond,
  });

  final String id;
  final String body;
  final bool isUser;
  final List<ChatPart> parts;
  final String? tokensPerSecond;

  ChatMessage copyWith({List<ChatPart>? parts}) {
    return ChatMessage(
      id: id,
      body: body,
      isUser: isUser,
      parts: parts ?? this.parts,
      tokensPerSecond: tokensPerSecond,
    );
  }
}

class ReverseChatController {
  ReverseChatController({List<ChatMessage>? seed})
      : _oldestFirst = List<ChatMessage>.of(seed ?? const []);

  final List<ChatMessage> _oldestFirst;

  /// Oldest → newest. Reverse list renders this from the end.
  List<ChatMessage> get oldestFirst => List.unmodifiable(_oldestFirst);

  int get length => _oldestFirst.length;

  ChatMessage newestAtReverseIndex(int reverseIndex) {
    return _oldestFirst[_oldestFirst.length - 1 - reverseIndex];
  }

  /// Insert older history at the top of the logical transcript.
  void prependOlder(List<ChatMessage> older) {
    _oldestFirst.insertAll(0, older);
  }

  void appendNewer(ChatMessage message) {
    _oldestFirst.add(message);
  }

  void replaceAll(List<ChatMessage> messages) {
    _oldestFirst
      ..clear()
      ..addAll(messages);
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
