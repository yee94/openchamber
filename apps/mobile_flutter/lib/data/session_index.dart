import 'home_session.dart';

class SessionIndexSnapshot {
  const SessionIndexSnapshot({
    required this.revision,
    required this.directories,
    this.pinnedSessionIds = const [],
  });

  final int revision;
  final List<SessionIndexDirectory> directories;
  final List<String> pinnedSessionIds;
}

class SessionIndexDirectory {
  const SessionIndexDirectory({
    required this.directory,
    required this.sessions,
  });

  final String directory;
  final List<SessionIndexSession> sessions;
}

class SessionIndexSession {
  const SessionIndexSession({
    required this.id,
    required this.title,
    required this.directory,
    this.parentId,
    this.projectLabel,
    this.branch,
    this.updated = 0,
    this.pinned = false,
    this.unread = false,
    this.archived = false,
  });

  final String id;
  final String title;
  final String directory;
  final String? parentId;
  final String? projectLabel;
  final String? branch;
  final num updated;
  final bool pinned;
  final bool unread;
  final bool archived;
}

SessionIndexSnapshot? parseSessionIndexSnapshot(Object? payload) {
  if (payload is! Map) return null;
  if (payload['available'] != true) return null;
  final directoriesRaw = payload['directories'];
  if (directoriesRaw is! List) return null;
  final pinnedRaw = payload['pinnedSessionIds'];
  final pinned = <String>[];
  if (pinnedRaw is List) {
    for (final id in pinnedRaw) {
      if (id is String && id.isNotEmpty) pinned.add(id);
    }
  }
  final directories = <SessionIndexDirectory>[];
  for (final item in directoriesRaw) {
    if (item is! Map) continue;
    final directory = item['directory']?.toString() ?? '';
    final sessionsRaw = item['sessions'];
    if (sessionsRaw is! List) continue;
    final sessions = <SessionIndexSession>[];
    for (final raw in sessionsRaw) {
      if (raw is! Map) continue;
      final parsed = _parseSession(raw, directory, pinned.toSet());
      if (parsed != null) sessions.add(parsed);
    }
    directories.add(SessionIndexDirectory(directory: directory, sessions: sessions));
  }
  return SessionIndexSnapshot(
    revision: payload['revision'] is num ? (payload['revision'] as num).toInt() : 0,
    directories: directories,
    pinnedSessionIds: pinned,
  );
}

SessionIndexSession? _parseSession(Map<Object?, Object?> raw, String fallbackDirectory, Set<String> pinned) {
  final id = raw['id']?.toString() ?? '';
  if (id.isEmpty) return null;
  final directory = (raw['directory']?.toString().trim().isNotEmpty ?? false)
      ? raw['directory'].toString()
      : fallbackDirectory;
  final time = raw['time'];
  num updated = 0;
  var isPinned = pinned.contains(id);
  var archived = false;
  if (time is Map) {
    final value = time['updated'] ?? time['created'];
    if (value is num) updated = value;
    if (time['pinned'] != null && time['pinned'] != false) isPinned = true;
    final archivedAt = time['archived'];
    archived = archivedAt is num && archivedAt > 0;
  }
  String? projectLabel;
  final project = raw['project'];
  if (project is Map) {
    projectLabel = project['name']?.toString() ?? project['id']?.toString();
  }
  projectLabel ??= _basename(directory);
  return SessionIndexSession(
    id: id,
    title: raw['title']?.toString() ?? '',
    directory: directory,
    parentId: raw['parentID']?.toString(),
    projectLabel: projectLabel,
    branch: raw['branch']?.toString() ?? (project is Map ? project['branch']?.toString() : null),
    updated: updated,
    pinned: isPinned,
    unread: raw['unread'] == true,
    archived: archived,
  );
}

String _basename(String path) {
  final trimmed = path.replaceAll(RegExp(r'[/\\]+$'), '');
  final parts = trimmed.split(RegExp(r'[/\\]'));
  return parts.isEmpty ? path : parts.last;
}

List<HomeSessionRow> rowsFromSessionIndex(
  SessionIndexSnapshot snapshot, {
  Map<String, String> statusById = const {},
}) {
  final rows = <HomeSessionRow>[];
  for (final directory in snapshot.directories) {
    for (final session in directory.sessions) {
      if (session.parentId != null && session.parentId!.isNotEmpty) continue;
      if (session.archived) continue;
      final status = statusById[session.id];
      final busy = status == 'busy' || status == 'retry';
      final kind = session.pinned
          ? HomeSessionKind.pinned
          : busy
              ? HomeSessionKind.inProgress
              : HomeSessionKind.catalog;
      rows.add(
        HomeSessionRow(
          id: session.id,
          title: session.title.isEmpty ? session.id : session.title,
          projectLabel: session.projectLabel ?? _basename(session.directory),
          branch: session.branch,
          kind: kind,
          unread: session.unread,
          directory: session.directory,
          updated: session.updated,
        ),
      );
    }
  }
  rows.sort((a, b) {
    final rank = a.kind.index.compareTo(b.kind.index);
    if (rank != 0) return rank;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return rows;
}

/// 1.19.3-beta.1: search matches loaded directory titles + id / project / path.
bool sessionMatchesQuery(HomeSessionRow row, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return [
    row.title,
    row.subtitle,
    row.id,
    row.projectLabel,
    row.directory ?? '',
    row.branch ?? '',
  ].any((value) => value.toLowerCase().contains(needle));
}

List<HomeSessionRow> filterSessionsForSearch(List<HomeSessionRow> rows, String query) {
  return rows.where((row) => sessionMatchesQuery(row, query)).toList();
}
