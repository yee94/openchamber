import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/chat_timeline.dart';

void main() {
  test('prepend older history does not change the newest reverse index', () {
    final list = ReverseChatController(seed: const [
      ChatMessage(id: 'old', body: 'older', isUser: false),
      ChatMessage(id: 'new', body: 'newest', isUser: true),
    ]);
    expect(list.newestAtReverseIndex(ReverseChatController.latestReverseIndex).id, 'new');
    list.prependOlder(const [ChatMessage(id: 'ancient', body: 'history', isUser: false)]);
    expect(list.newestAtReverseIndex(0).id, 'new');
    expect(list.oldestFirst.first.id, 'ancient');
    expect(list.length, 3);
  });

  test('append newer becomes the latest reverse edge (1.19.3-beta.5)', () {
    final list = ReverseChatController(seed: demoTranscript());
    list.appendNewer(const ChatMessage(id: 'latest', body: 'just now', isUser: false));
    expect(list.newestAtReverseIndex(0).id, 'latest');
  });
}
