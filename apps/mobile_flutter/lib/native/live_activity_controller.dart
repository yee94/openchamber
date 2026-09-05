import 'package:flutter/services.dart';

import '../data/home_session.dart';
import 'platform_channels.dart';

const liveActivityBusyDelay = Duration(seconds: 5);

/// Official `NATIVE_LIVE_ACTIVITY_ID`. One Activity holds every working row.
const liveActivityCatalogId = 'live';

const liveActivityItemLimit = 4;
const liveActivityTitleMax = 80;

const liveActivityStatuses = {
  'working',
  'tool',
  'retry',
  'input',
  'permission',
  'stale',
  'complete',
  'error',
};

class LiveActivityCatalogItem {
  const LiveActivityCatalogItem({
    required this.sessionId,
    required this.title,
    required this.status,
    required this.startedAt,
    this.endedAt,
  });

  final String sessionId;
  final String title;
  final String status;
  final double startedAt;
  final double? endedAt;

  Map<String, Object?> toPayload() {
    return {
      'sessionId': sessionId,
      'title': title,
      'status': status,
      'startedAt': startedAt,
      if (endedAt != null) 'endedAt': endedAt,
    };
  }
}

String truncateLiveActivityTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.length <= liveActivityTitleMax) return trimmed;
  return '${trimmed.substring(0, liveActivityTitleMax - 1)}…';
}

String liveActivityStatusFromSession(String? raw) {
  switch (raw) {
    case 'retry':
      return 'retry';
    case 'busy':
    case 'working':
      return 'working';
    default:
      return 'working';
  }
}

bool isLiveActivityWorkingStatus(String status) => status != 'complete' && status != 'error';

bool isLiveActivityRunningSessionStatus(String? raw) => raw == 'busy' || raw == 'retry';

/// Top-level working sessions only. Mirrors official
/// `buildNativeLiveActivityCatalog` (main `15cf6643e`).
List<LiveActivityCatalogItem> buildLiveActivityCatalog({
  required Map<String, String> statusById,
  required List<HomeSessionRow> sessions,
  DateTime Function()? now,
}) {
  final runningIds = <String>{
    for (final entry in statusById.entries)
      if (isLiveActivityRunningSessionStatus(entry.value)) entry.key,
  };
  if (runningIds.isEmpty) return const [];

  final clock = now ?? DateTime.now;
  final startedAt = clock().millisecondsSinceEpoch / 1000;
  final byId = {for (final session in sessions) session.id: session};
  final items = <LiveActivityCatalogItem>[];
  final seen = <String>{};

  for (final session in sessions) {
    if (!runningIds.contains(session.id)) continue;
    seen.add(session.id);
    items.add(
      LiveActivityCatalogItem(
        sessionId: session.id,
        title: truncateLiveActivityTitle(session.title),
        status: liveActivityStatusFromSession(statusById[session.id]),
        startedAt: startedAt,
      ),
    );
    if (items.length >= liveActivityItemLimit) return items;
  }

  for (final sessionId in runningIds) {
    if (seen.contains(sessionId)) continue;
    final session = byId[sessionId];
    items.add(
      LiveActivityCatalogItem(
        sessionId: sessionId,
        title: truncateLiveActivityTitle(session?.title ?? ''),
        status: liveActivityStatusFromSession(statusById[sessionId]),
        startedAt: startedAt,
      ),
    );
    if (items.length >= liveActivityItemLimit) break;
  }
  return items;
}

Uri liveActivityRowUri(String sessionId) {
  if (sessionId.isEmpty || sessionId == liveActivityCatalogId) {
    return Uri(scheme: 'openchamber', host: 'session', path: '/$liveActivityCatalogId');
  }
  return Uri(scheme: 'openchamber', host: 'session', path: '/$sessionId');
}

/// Local Live Activity. Starts after [liveActivityBusyDelay] of continuous
/// work across the live catalog. Does not rebuild after the user dismisses
/// the same task (native `dismissedSessionIDs` + this set).
class LiveActivityController {
  LiveActivityController({
    MethodChannel? channel,
    this.now = DateTime.now,
  }) : _channel = channel ?? const MethodChannel(OpenChamberChannels.liveActivity);

  final MethodChannel _channel;
  final DateTime Function() now;

  final Set<String> dismissedSessionIds = {};
  String? selectedSessionId;
  List<LiveActivityCatalogItem> catalog = const [];
  DateTime? _workStartedAt;
  bool _started = false;
  int _eventVersion = 0;

  bool get started => _started;

  void selectSession(String sessionId) {
    if (selectedSessionId == sessionId) return;
    selectedSessionId = sessionId;
    _workStartedAt = null;
    _started = false;
  }

  bool get hasWorkStarted => _workStartedAt != null;

  void applyCatalog(List<LiveActivityCatalogItem> items) {
    catalog = items;
    if (items.isEmpty) return;
    if (dismissedSessionIds.contains(liveActivityCatalogId)) return;
    if (selectedSessionId != null && dismissedSessionIds.contains(selectedSessionId)) return;
    _workStartedAt ??= now();
  }

  void markWorkStarted({DateTime? at}) {
    if (dismissedSessionIds.contains(liveActivityCatalogId)) return;
    final sessionId = selectedSessionId;
    if (sessionId != null && dismissedSessionIds.contains(sessionId)) return;
    if (catalog.isEmpty && (sessionId == null || sessionId.isEmpty)) return;
    _workStartedAt ??= at ?? now();
  }

  bool get shouldStart {
    final startedAt = _workStartedAt;
    if (startedAt == null || _started) return false;
    if (dismissedSessionIds.contains(liveActivityCatalogId)) return false;
    final sessionId = selectedSessionId;
    if (sessionId != null && dismissedSessionIds.contains(sessionId)) return false;
    if (catalog.isEmpty && (sessionId == null || sessionId.isEmpty)) return false;
    return now().difference(startedAt) >= liveActivityBusyDelay;
  }

  List<LiveActivityCatalogItem> get _payloadItems {
    if (catalog.isNotEmpty) return catalog;
    final sessionId = selectedSessionId;
    if (sessionId == null || sessionId.isEmpty) return const [];
    return [
      LiveActivityCatalogItem(
        sessionId: sessionId,
        title: '',
        status: 'working',
        startedAt: (_workStartedAt ?? now()).millisecondsSinceEpoch / 1000,
      ),
    ];
  }

  Map<String, Object?> _fields({required String status, double? endedAt}) {
    final items = _payloadItems;
    final workingCount = items.where((item) => isLiveActivityWorkingStatus(item.status)).length;
    return {
      'sessionId': liveActivityCatalogId,
      'startedAt': (_workStartedAt ?? now()).millisecondsSinceEpoch / 1000,
      'status': liveActivityStatuses.contains(status) ? status : 'working',
      'eventVersion': _eventVersion,
      'updatedAt': now().millisecondsSinceEpoch / 1000,
      if (endedAt != null) 'endedAt': endedAt,
      'workingCount': workingCount,
      'items': items.map((item) => item.toPayload()).toList(),
    };
  }

  Future<String?> startIfDue({String status = 'working'}) async {
    if (!shouldStart) return null;
    if (!liveActivityStatuses.contains(status)) return null;
    _started = true;
    _eventVersion += 1;
    try {
      final id = await _channel.invokeMethod<String>('start', _fields(status: status));
      if (id == null) {
        dismissedSessionIds.add(liveActivityCatalogId);
        final selected = selectedSessionId;
        if (selected != null) dismissedSessionIds.add(selected);
      }
      return id;
    } on PlatformException {
      dismissedSessionIds.add(liveActivityCatalogId);
      return null;
    }
  }

  Future<void> update(String status) async {
    if (!_started) return;
    if (dismissedSessionIds.contains(liveActivityCatalogId)) return;
    if (!liveActivityStatuses.contains(status)) return;
    _eventVersion += 1;
    await _channel.invokeMethod<void>('update', _fields(status: status));
  }

  Future<void> complete({required bool error}) async {
    if (!_started) return;
    _eventVersion += 1;
    final endedAt = now().millisecondsSinceEpoch / 1000;
    await _channel.invokeMethod<void>(
      'end',
      _fields(status: error ? 'error' : 'complete', endedAt: endedAt),
    );
    _started = false;
    _workStartedAt = null;
    catalog = const [];
  }

  void markDismissed(String sessionId) {
    dismissedSessionIds.add(sessionId);
    if (sessionId == liveActivityCatalogId || sessionId == selectedSessionId) {
      dismissedSessionIds.add(liveActivityCatalogId);
      _started = false;
      _workStartedAt = null;
    }
  }

  Uri jumpBackUri(String sessionId) => liveActivityRowUri(sessionId);
}
