import 'home_session.dart';

/// Official Cap `useEdgeSwipeSessionSwitch.ts` constants.
const sessionSwipeMinDistance = 64.0;
const sessionSwipeMaxOffAxisRatio = 0.6;
const nativeIosBackEdgeWidth = 28.0;

enum SessionSwipeDirection { prev, next }

class SessionSwipeProgress {
  const SessionSwipeProgress({
    required this.direction,
    required this.progress,
    required this.offsetX,
    required this.canSwitch,
  });

  final SessionSwipeDirection direction;
  final double progress;
  final double offsetX;
  final bool canSwitch;
}

bool shouldStartSessionSwipe({
  required bool onExplicitSurface,
  bool onCodeBlock = false,
  bool withinHorizontalScroller = false,
  bool withinNativeBackEdge = false,
  bool composerActive = false,
}) {
  if (composerActive) return false;
  if (onCodeBlock || withinHorizontalScroller || withinNativeBackEdge) return false;
  return onExplicitSurface;
}

SessionSwipeDirection? evaluateSwipeDirection({
  required double startX,
  required double startY,
  required double endX,
  required double endY,
}) {
  final dx = endX - startX;
  final dy = endY - startY;
  final absDx = dx.abs();
  final absDy = dy.abs();
  if (absDx < sessionSwipeMinDistance) return null;
  if (absDy > absDx * sessionSwipeMaxOffAxisRatio) return null;
  return dx < 0 ? SessionSwipeDirection.next : SessionSwipeDirection.prev;
}

SessionSwipeProgress? evaluateSwipeProgress({
  required double startX,
  required double startY,
  required double endX,
  required double endY,
  required bool canPrev,
  required bool canNext,
}) {
  final dx = endX - startX;
  final dy = endY - startY;
  final absDx = dx.abs();
  final absDy = dy.abs();
  if (absDx < 8 || absDy > absDx * sessionSwipeMaxOffAxisRatio) return null;
  final direction = dx < 0 ? SessionSwipeDirection.next : SessionSwipeDirection.prev;
  return SessionSwipeProgress(
    direction: direction,
    progress: (absDx / sessionSwipeMinDistance).clamp(0, 1),
    offsetX: dx,
    canSwitch: direction == SessionSwipeDirection.next ? canNext : canPrev,
  );
}

/// Cap swipe list: top-level sessions, newest-first by `time.updated`.
List<HomeSessionRow> orderedTopLevelSessionsForSwipe(Iterable<HomeSessionRow> sessions) {
  final rows = sessions.where((row) => row.id.isNotEmpty).toList()
    ..sort((a, b) => b.updated.compareTo(a.updated));
  return rows;
}

HomeSessionRow? swipeNeighbor({
  required Iterable<HomeSessionRow> sessions,
  required String currentId,
  required SessionSwipeDirection direction,
}) {
  if (currentId.isEmpty) return null;
  final ordered = orderedTopLevelSessionsForSwipe(sessions);
  final index = ordered.indexWhere((row) => row.id == currentId);
  if (index < 0) return null;
  final next = direction == SessionSwipeDirection.next ? index + 1 : index - 1;
  if (next < 0 || next >= ordered.length) return null;
  return ordered[next];
}
