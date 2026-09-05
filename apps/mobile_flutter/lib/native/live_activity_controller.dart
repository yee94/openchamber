import 'package:flutter/services.dart';

import 'platform_channels.dart';

const liveActivityBusyDelay = Duration(seconds: 5);

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

/// Local Live Activity MVP. Starts after [liveActivityBusyDelay] of continuous
/// work on one selected top-level session. Does not rebuild after the user
/// dismisses the same task (native `dismissedSessionIDs` + this set).
class LiveActivityController {
  LiveActivityController({
    MethodChannel? channel,
    this.now = DateTime.now,
  }) : _channel = channel ?? const MethodChannel(OpenChamberChannels.liveActivity);

  final MethodChannel _channel;
  final DateTime Function() now;

  final Set<String> dismissedSessionIds = {};
  String? selectedSessionId;
  DateTime? _workStartedAt;
  bool _started = false;
  int _eventVersion = 0;

  void selectSession(String sessionId) {
    if (selectedSessionId == sessionId) return;
    selectedSessionId = sessionId;
    _workStartedAt = null;
    _started = false;
  }

  bool get hasWorkStarted => _workStartedAt != null;

  void markWorkStarted({DateTime? at}) {
    final sessionId = selectedSessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    if (dismissedSessionIds.contains(sessionId)) return;
    _workStartedAt ??= at ?? now();
  }

  bool get shouldStart {
    final startedAt = _workStartedAt;
    final sessionId = selectedSessionId;
    if (startedAt == null || sessionId == null || _started) return false;
    if (dismissedSessionIds.contains(sessionId)) return false;
    return now().difference(startedAt) >= liveActivityBusyDelay;
  }

  Future<String?> startIfDue({String status = 'working'}) async {
    final sessionId = selectedSessionId;
    if (sessionId == null || !shouldStart) return null;
    if (!liveActivityStatuses.contains(status)) return null;
    _started = true;
    _eventVersion += 1;
    final startedAt = (_workStartedAt ?? now()).millisecondsSinceEpoch / 1000;
    final updatedAt = now().millisecondsSinceEpoch / 1000;
    try {
      final id = await _channel.invokeMethod<String>('start', {
        'sessionId': sessionId,
        'startedAt': startedAt,
        'status': status,
        'eventVersion': _eventVersion,
        'updatedAt': updatedAt,
      });
      if (id == null) {
        dismissedSessionIds.add(sessionId);
      }
      return id;
    } on PlatformException {
      dismissedSessionIds.add(sessionId);
      return null;
    }
  }

  Future<void> update(String status) async {
    final sessionId = selectedSessionId;
    if (sessionId == null || !_started) return;
    if (dismissedSessionIds.contains(sessionId)) return;
    if (!liveActivityStatuses.contains(status)) return;
    _eventVersion += 1;
    await _channel.invokeMethod<void>('update', {
      'sessionId': sessionId,
      'status': status,
      'eventVersion': _eventVersion,
      'updatedAt': now().millisecondsSinceEpoch / 1000,
    });
  }

  Future<void> complete({required bool error}) async {
    final sessionId = selectedSessionId;
    if (sessionId == null || !_started) return;
    _eventVersion += 1;
    await _channel.invokeMethod<void>('end', {
      'sessionId': sessionId,
      'status': error ? 'error' : 'complete',
      'eventVersion': _eventVersion,
      'updatedAt': now().millisecondsSinceEpoch / 1000,
      'endedAt': now().millisecondsSinceEpoch / 1000,
    });
    _started = false;
    _workStartedAt = null;
  }

  void markDismissed(String sessionId) {
    dismissedSessionIds.add(sessionId);
    if (selectedSessionId == sessionId) {
      _started = false;
      _workStartedAt = null;
    }
  }

  Uri jumpBackUri(String sessionId) => Uri(
        scheme: 'openchamber',
        host: 'session',
        path: '/$sessionId',
      );
}
