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
    list.dispose();
  });

  test('append newer becomes the latest reverse edge (1.19.3-beta.5)', () {
    final list = ReverseChatController(seed: demoTranscript());
    list.appendNewer(const ChatMessage(id: 'latest', body: 'just now', isUser: false));
    expect(list.newestAtReverseIndex(0).id, 'latest');
    list.dispose();
  });

  test('applyMessages reuses rows and only notifies on structure change', () {
    final list = ReverseChatController(seed: const [
      ChatMessage(id: 'a', body: 'one', isUser: true),
      ChatMessage(id: 'b', body: 'two', isUser: false),
    ]);
    final firstStructure = list.structureNotifyCount;
    final slot = list.slotFor('b');
    var slotTicks = 0;
    slot.addListener(() => slotTicks += 1);

    list.applyMessages(const [
      ChatMessage(id: 'a', body: 'one', isUser: true),
      ChatMessage(id: 'b', body: 'two', isUser: false),
    ]);
    expect(list.structureNotifyCount, firstStructure);
    expect(slotTicks, 0);

    list.applyMessages(const [
      ChatMessage(id: 'a', body: 'one', isUser: true),
      ChatMessage(id: 'b', body: 'two **plus**', isUser: false),
    ]);
    expect(list.structureNotifyCount, firstStructure);
    expect(slotTicks, 1);
    expect(identical(list.slotFor('b'), slot), isTrue);

    list.applyMessages(const [
      ChatMessage(id: 'a', body: 'one', isUser: true),
      ChatMessage(id: 'b', body: 'two **plus**', isUser: false),
      ChatMessage(id: 'c', body: 'three', isUser: true),
    ]);
    expect(list.structureNotifyCount, firstStructure + 1);
    list.dispose();
  });
}
