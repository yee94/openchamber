import '../../theme/ios_hero.dart';

/// Collapsed iOS composer pill height. Homepage occupancy uses this only —
/// keyboard height is owned by Scaffold `resizeToAvoidBottomInset`.
const double collapsedComposerOccupancy = 56;

/// ComposerBar's trailing pad under the pill (`EdgeInsets.fromLTRB(16, 0, 16, 8)`).
const double composerPillBottomPad = 8;

/// Bottom inset the reverse transcript must keep clear so the last-turn
/// footer meta strip sits above the composer, not under it.
///
/// [paddingBottom] is [MediaQuery.padding] after Scaffold consumed the
/// keyboard (`resizeToAvoidBottomInset`). Do not pass raw `viewInsets`.
double composerListReserve({
  required bool ios,
  required double paddingBottom,
  required bool showScrollToBottom,
}) {
  if (ios) return collapsedComposerOccupancy + paddingBottom;
  final fab = showScrollToBottom ? OcOptical.scrollFab + 6 : 0.0;
  return collapsedComposerOccupancy + paddingBottom + fab + composerPillBottomPad;
}

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
  if (trimmed.startsWith('#')) {
    return const [
      ComposerAutocompleteItem(id: 'mention-todo', label: '#todo', kind: 'mention'),
      ComposerAutocompleteItem(id: 'mention-bug', label: '#bug', kind: 'mention'),
    ];
  }
  return const [];
}
