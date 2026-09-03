/// Collapsed iOS composer pill height. Homepage occupancy uses this only —
/// expanded card / keyboard height must not push the home list.
const double collapsedComposerOccupancy = 56;

/// Autocomplete stub rows for `/` and `@`. The iOS platform view pan-scrolls
/// this list; Dart keeps the same model for tests and Android.
class ComposerAutocompleteItem {
  const ComposerAutocompleteItem({required this.id, required this.label, required this.kind});

  final String id;
  final String label;
  final String kind;
}

List<ComposerAutocompleteItem> autocompleteStubFor(String text) {
  final trimmed = text.trimLeft();
  if (trimmed.startsWith('/')) {
    return const [
      ComposerAutocompleteItem(id: 'cmd-status', label: '/status', kind: 'command'),
      ComposerAutocompleteItem(id: 'cmd-help', label: '/help', kind: 'command'),
      ComposerAutocompleteItem(id: 'cmd-new', label: '/new', kind: 'command'),
    ];
  }
  if (trimmed.startsWith('@')) {
    return const [
      ComposerAutocompleteItem(id: 'file-readme', label: '@README.md', kind: 'file'),
      ComposerAutocompleteItem(id: 'file-gap', label: '@docs/flutter-native-gap.md', kind: 'file'),
    ];
  }
  return const [];
}
