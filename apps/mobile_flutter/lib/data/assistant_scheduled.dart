import 'home_session.dart';
import 'settings_remote.dart';

class AssistantRecord {
  const AssistantRecord({
    required this.id,
    required this.name,
    required this.revision,
    this.enabled = true,
    this.providerId,
    this.modelId,
    this.mode,
    this.sessionId,
    this.workspacePath,
    this.defaultPrompt,
  });

  final String id;
  final String name;
  final int revision;
  final bool enabled;
  final String? providerId;
  final String? modelId;
  final String? mode;
  final String? sessionId;
  final String? workspacePath;
  final String? defaultPrompt;

  String? get modelLabel {
    final parts = [providerId, modelId].whereType<String>().where((part) => part.isNotEmpty);
    if (parts.isEmpty) return mode;
    return parts.join('/');
  }

  HomeSessionRow? get boundSession {
    final session = sessionId;
    if (session == null || session.isEmpty) return null;
    return HomeSessionRow(
      id: session,
      title: name,
      projectLabel: name,
      kind: HomeSessionKind.catalog,
      directory: workspacePath,
    );
  }
}

class AssistantSnapshotView {
  const AssistantSnapshotView({
    required this.revision,
    required this.enabled,
    required this.assistants,
    this.capabilityAvailable = true,
  });

  final int revision;
  final bool enabled;
  final List<AssistantRecord> assistants;
  final bool capabilityAvailable;
}

class ScheduledTaskRecord {
  const ScheduledTaskRecord({
    required this.projectId,
    required this.id,
    required this.name,
    this.enabled = true,
    this.lastStatus,
    this.lastSessionId,
    this.prompt,
  });

  final String projectId;
  final String id;
  final String name;
  final bool enabled;
  final String? lastStatus;
  final String? lastSessionId;
  final String? prompt;
}

class ScheduledRunRecord {
  const ScheduledRunRecord({
    required this.id,
    required this.projectId,
    required this.taskId,
    required this.taskName,
    required this.status,
    this.sessionId,
    this.directory,
    this.error,
    this.startedAt,
  });

  final String id;
  final String projectId;
  final String taskId;
  final String taskName;
  final String status;
  final String? sessionId;
  final String? directory;
  final String? error;
  final num? startedAt;

  HomeSessionRow? get historySession {
    final session = sessionId;
    if (session == null || session.isEmpty) return null;
    return HomeSessionRow(
      id: session,
      title: taskName,
      projectLabel: taskName,
      kind: HomeSessionKind.catalog,
      directory: directory,
    );
  }
}

AssistantSnapshotView parseAssistantSnapshotView(Object? payload) {
  final root = asObjectMap(payload);
  return AssistantSnapshotView(
    revision: root['revision'] is num ? (root['revision'] as num).toInt() : 0,
    enabled: root['enabled'] != false,
    assistants: asObjectList(root['assistants']).map(parseAssistantRecord).where((item) => item.id.isNotEmpty).toList(),
  );
}

AssistantRecord parseAssistantRecord(Map<String, Object?> item) {
  return AssistantRecord(
    id: item['id']?.toString() ?? '',
    name: item['name']?.toString() ?? item['id']?.toString() ?? '',
    revision: item['revision'] is num ? (item['revision'] as num).toInt() : 0,
    enabled: item['enabled'] != false,
    providerId: item['providerID']?.toString(),
    modelId: item['modelID']?.toString(),
    mode: item['mode']?.toString(),
    sessionId: item['sessionID']?.toString(),
    workspacePath: item['workspacePath']?.toString() ?? item['effectiveWorkspacePath']?.toString(),
    defaultPrompt: item['defaultPrompt']?.toString(),
  );
}

List<ScheduledTaskRecord> parseScheduledTasks(Object? payload) {
  final root = asObjectMap(payload);
  return asObjectList(root['tasks']).map((item) {
    final task = asObjectMap(item['task']);
    final state = asObjectMap(task['state']);
    final execution = asObjectMap(task['execution']);
    return ScheduledTaskRecord(
      projectId: item['projectId']?.toString() ?? '',
      id: task['id']?.toString() ?? '',
      name: task['name']?.toString() ?? task['id']?.toString() ?? '',
      enabled: task['enabled'] != false,
      lastStatus: state['lastStatus']?.toString(),
      lastSessionId: state['lastSessionId']?.toString(),
      prompt: execution['prompt']?.toString(),
    );
  }).where((item) => item.id.isNotEmpty && item.projectId.isNotEmpty).toList();
}

List<String> parseFailedScheduledProjectIds(Object? payload) {
  final root = asObjectMap(payload);
  final raw = root['failedProjectIds'];
  if (raw is! List) return const [];
  return raw.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
}

List<ScheduledRunRecord> parseScheduledRuns(Object? payload) {
  final root = asObjectMap(payload);
  return asObjectList(root['runs']).map((item) {
    return ScheduledRunRecord(
      id: item['id']?.toString() ?? '',
      projectId: item['projectId']?.toString() ?? '',
      taskId: item['taskId']?.toString() ?? '',
      taskName: item['taskName']?.toString() ?? '',
      status: item['status']?.toString() ?? '',
      sessionId: item['sessionId']?.toString(),
      directory: item['directory']?.toString(),
      error: item['error']?.toString(),
      startedAt: item['startedAt'] is num ? item['startedAt'] as num : null,
    );
  }).where((item) => item.id.isNotEmpty).toList();
}

HomeSessionRow? parseSessionBinding(Object? payload) {
  final root = asObjectMap(payload);
  final id = root['sessionID']?.toString() ?? '';
  if (id.isEmpty) return null;
  return HomeSessionRow(
    id: id,
    title: 'Assistant',
    projectLabel: 'Assistant',
    kind: HomeSessionKind.catalog,
    directory: root['directory']?.toString(),
  );
}
