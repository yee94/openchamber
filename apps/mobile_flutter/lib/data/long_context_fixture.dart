import 'chat_timeline.dart';

/// Deterministic long-context transcript for scroll / Markdown stress tests.
///
/// Default: 160 turns (320 messages). Each assistant body is multi-KB GFM
/// with headings, emphasis, lists, blockquotes, links, and fenced code.
/// Several turns also carry reasoning + a tool card so mixed rows are real.
class LongContextFixture {
  const LongContextFixture._();

  static const int defaultTurns = 160;
  static const int codeLinesPerAssistant = 80;

  static List<ChatMessage> build({int turns = defaultTurns}) {
    final out = <ChatMessage>[];
    for (var i = 0; i < turns; i += 1) {
      out.add(
        ChatMessage(
          id: 'user-$i',
          body: 'User turn $i — please continue the long-context review.',
          isUser: true,
        ),
      );
      final mixed = i % 5 == 0;
      final aborted = i == turns - 3;
      final empty = i == turns - 2;
      out.add(
        ChatMessage(
          id: 'asst-$i',
          body: empty ? '' : assistantMarkdown(i),
          isUser: false,
          errorKind: aborted ? 'aborted' : null,
          parts: [
            if (mixed)
              ChatPart(
                id: 'think-$i',
                kind: ChatPartKind.reasoning,
                title: 'thinking',
                body: reasoningMarkdown(i),
                status: 'completed',
              ),
            if (!empty)
              ChatPart(
                id: 'text-$i',
                kind: ChatPartKind.text,
                title: 'text',
                body: assistantMarkdown(i),
              ),
            if (mixed)
              ChatPart(
                id: 'tool-$i',
                kind: ChatPartKind.tool,
                title: 'ls',
                status: 'completed',
                toolName: 'bash',
                body: 'README.md',
              ),
          ],
        ),
      );
    }
    return out;
  }

  static String assistantMarkdown(int seed) {
    final buffer = StringBuffer()
      ..writeln('# Review $seed')
      ..writeln()
      ..writeln('Paragraph with **bold**, *italic*, and `inline($seed)` code.')
      ..writeln()
      ..writeln('- first item')
      ..writeln('- second item')
      ..writeln('  - nested item $seed')
      ..writeln()
      ..writeln('> Blockquote for turn $seed.')
      ..writeln()
      ..writeln('[Example](https://example.invalid/turn-$seed)')
      ..writeln()
      ..writeln('```dart');
    for (var line = 0; line < codeLinesPerAssistant; line += 1) {
      buffer.writeln('int value${seed}_$line() => $seed + $line;');
    }
    buffer
      ..writeln('```')
      ..writeln()
      ..writeln('Closing sentence for turn $seed.');
    return buffer.toString();
  }

  static String reasoningMarkdown(int seed) {
    return 'First thought about turn $seed and how to approach the long context.\n'
        'Second line goes deeper so the collapsed header summary truncates '
        'before this hidden detail $seed.';
  }

  static int estimatedLineCount({int turns = defaultTurns}) {
    // heading + blanks + list + quote + fence + code + close, times assistants
    return turns * (codeLinesPerAssistant + 16);
  }
}
