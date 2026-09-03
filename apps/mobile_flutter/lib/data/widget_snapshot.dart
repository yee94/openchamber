import 'dart:convert';

import 'home_session.dart';

/// Mirrors `packages/ui/src/apps/mobileWidgetSnapshot.ts`.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.attentionCount,
    required this.recentSessions,
  });

  final int attentionCount;
  final List<WidgetSessionRow> recentSessions;

  Map<String, Object?> toJson() => {
        'attentionCount': attentionCount,
        'recentSessions': recentSessions.map((row) => row.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());
}

class WidgetSessionRow {
  const WidgetSessionRow({
    required this.id,
    required this.title,
    required this.unread,
    this.project,
  });

  final String id;
  final String title;
  final bool unread;
  final String? project;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'unread': unread,
        if (project != null) 'project': project,
      };
}

WidgetSnapshot buildWidgetSnapshot(List<HomeSessionRow> sessions, {int limit = 6}) {
  final topLevel = sessions.where((row) => row.id.isNotEmpty).toList();
  final attention = topLevel.where((row) => row.unread).length;
  final recent = topLevel.take(limit).map((row) {
    return WidgetSessionRow(
      id: row.id,
      title: row.title,
      unread: row.unread,
      project: row.projectLabel,
    );
  }).toList();
  return WidgetSnapshot(attentionCount: attention, recentSessions: recent);
}
