import '../../theme/ios_hero.dart';

export '../../data/composer_autocomplete.dart';

/// Collapsed iOS composer pill height. Homepage occupancy uses this only —
/// keyboard height is owned by Scaffold `resizeToAvoidBottomInset`.
const double collapsedComposerOccupancy = 56;

/// ComposerBar's trailing pad under the pill (`EdgeInsets.fromLTRB(16, 0, 16, 8)`).
const double composerPillBottomPad = 8;

/// Cap `QueuedMessageChips` row above the composer.
const double queuedMessageChipsOccupancy = 48;

/// Bottom inset the reverse transcript must keep clear so the last-turn
/// footer meta strip sits above the composer, not under it.
///
/// [paddingBottom] is [MediaQuery.padding] after Scaffold consumed the
/// keyboard (`resizeToAvoidBottomInset`). Do not pass raw `viewInsets`.
double composerListReserve({
  required bool ios,
  required double paddingBottom,
  required bool showScrollToBottom,
  double queuedChipHeight = 0,
}) {
  if (ios) return collapsedComposerOccupancy + paddingBottom + queuedChipHeight;
  final fab = showScrollToBottom ? OcOptical.scrollFab + 6 : 0.0;
  return collapsedComposerOccupancy + paddingBottom + fab + composerPillBottomPad + queuedChipHeight;
}

