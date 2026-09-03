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
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.isUser,
  });

  final String id;
  final String body;
  final bool isUser;
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
