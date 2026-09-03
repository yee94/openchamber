/// Parse/build counters for chat Markdown. Keyed by message/part id + content.
///
/// Official web hydrates Markdown per stable turn entry and never re-parses
/// settled rows on every SSE tick. This cache is that contract on Flutter:
/// a live token only invalidates the one row whose source changed.
class ChatMarkdownBuildCounters {
  ChatMarkdownBuildCounters._();

  static int builds = 0;
  static int reuseHits = 0;

  static void reset() {
    builds = 0;
    reuseHits = 0;
  }
}

/// LRU of committed Markdown source hashes so streaming can skip no-op work.
class ChatMarkdownSourceCache {
  ChatMarkdownSourceCache._();

  static const int maxEntries = 128;
  static final List<String> _order = [];
  static final Set<String> _keys = {};

  static bool remember(String key) {
    if (_keys.contains(key)) {
      _order.remove(key);
      _order.add(key);
      return true;
    }
    _keys.add(key);
    _order.add(key);
    while (_order.length > maxEntries) {
      final evicted = _order.removeAt(0);
      _keys.remove(evicted);
    }
    return false;
  }

  static void clear() {
    _order.clear();
    _keys.clear();
  }
}
