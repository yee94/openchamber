/// Cap-parity composer trigger: leading `/` commands, mid-line `/` skills,
/// `#` snippets, `@` file mentions. Matches
/// `packages/ui/src/lib/composer-autocomplete/trigger.ts`.
enum ComposerTriggerKind { command, skill, snippet, mention }

class ComposerAutocompleteItem {
  const ComposerAutocompleteItem({required this.id, required this.label, required this.kind});

  final String id;
  final String label;
  final String kind;
}

class ComposerTrigger {
  const ComposerTrigger({required this.kind, required this.query});

  final ComposerTriggerKind kind;
  final String query;
}

bool _isWhitespace(String? char) => char == null || RegExp(r'\s').hasMatch(char);

ComposerTrigger? resolveComposerTrigger(String text) {
  if (text.startsWith('/')) {
    final firstSpace = text.indexOf(' ');
    final firstNewline = text.indexOf('\n');
    final commandEnd = [
      if (firstSpace >= 0) firstSpace,
      if (firstNewline >= 0) firstNewline,
      text.length,
    ].reduce((a, b) => a < b ? a : b);
    if (firstSpace < 0 && firstNewline < 0) {
      return ComposerTrigger(kind: ComposerTriggerKind.command, query: text.substring(1, commandEnd).trim().toLowerCase());
    }
  }

  final lastSlash = text.lastIndexOf('/');
  if (lastSlash >= 0) {
    final before = lastSlash > 0 ? text[lastSlash - 1] : null;
    final after = text.substring(lastSlash + 1);
    if (_isWhitespace(before) && !after.contains(' ') && !after.contains('\n')) {
      return ComposerTrigger(kind: ComposerTriggerKind.skill, query: after.trim().toLowerCase());
    }
  }

  final lastHash = text.lastIndexOf('#');
  if (lastHash >= 0) {
    final before = lastHash > 0 ? text[lastHash - 1] : null;
    final after = text.substring(lastHash + 1);
    if (_isWhitespace(before) && !after.contains(' ') && !after.contains('\n')) {
      return ComposerTrigger(kind: ComposerTriggerKind.snippet, query: after.trim().toLowerCase());
    }
  }

  final lastAt = text.lastIndexOf('@');
  if (lastAt >= 0) {
    final before = lastAt > 0 ? text[lastAt - 1] : null;
    final after = text.substring(lastAt + 1);
    if (_isWhitespace(before) && !after.contains(' ') && !after.contains('\n')) {
      return ComposerTrigger(kind: ComposerTriggerKind.mention, query: after.trim().toLowerCase());
    }
  }
  return null;
}

List<String> parseNamedEntries(Object? payload, {String? listKey}) {
  final raw = payload is List
      ? payload
      : payload is Map
          ? payload[listKey] ?? payload['items']
          : null;
  if (raw is! List) return const [];
  return raw.map((item) {
    if (item is! Map) return '';
    return (item['name'] ?? item['id'] ?? '').toString();
  }).where((name) => name.isNotEmpty).toList();
}

List<String> parseCommandNames(Object? payload) => parseNamedEntries(payload, listKey: 'commands');

List<String> parseSkillNames(Object? payload) => parseNamedEntries(payload, listKey: 'skills');

List<String> parseSnippetNames(Object? payload) => parseNamedEntries(payload, listKey: 'snippets');

List<ComposerAutocompleteItem> filterComposerSuggestions(
  String text, {
  required Iterable<String> commands,
  required Iterable<String> files,
  required Iterable<String> skills,
  Iterable<String> snippets = const [],
}) {
  final trigger = resolveComposerTrigger(text);
  if (trigger == null) return const [];
  final query = trigger.query;
  switch (trigger.kind) {
    case ComposerTriggerKind.command:
      return commands
          .where((name) => query.isEmpty || name.toLowerCase().contains(query))
          .map((name) => ComposerAutocompleteItem(id: 'cmd-$name', label: '/$name', kind: 'command'))
          .toList();
    case ComposerTriggerKind.skill:
      return skills
          .where((name) => query.isEmpty || name.toLowerCase().contains(query))
          .map((name) => ComposerAutocompleteItem(id: 'skill-$name', label: '/$name', kind: 'skill'))
          .toList();
    case ComposerTriggerKind.mention:
      return files
          .where((path) => query.isEmpty || path.toLowerCase().contains(query))
          .map((path) => ComposerAutocompleteItem(id: 'file-$path', label: '@$path', kind: 'file'))
          .toList();
    case ComposerTriggerKind.snippet:
      return snippets
          .where((name) => query.isEmpty || name.toLowerCase().contains(query))
          .map((name) => ComposerAutocompleteItem(id: 'snippet-$name', label: '#$name', kind: 'snippet'))
          .toList();
  }
}
