/// Port of `packages/ui/src/components/chat/message/parts/contextToolGrouping.ts`
/// and `toolRenderUtils.ts` context-tool names. Do not invent extra tools.
library;

import 'chat_timeline.dart';

const contextGroupToolNames = {'read', 'glob', 'grep', 'list'};

const _activeToolStatuses = {'pending', 'started', 'running'};

const _settledToolStatuses = {
  'completed',
  'error',
  'failed',
  'aborted',
  'timeout',
  'cancelled',
};

enum ContextToolCountKey { read, search, list }

const contextToolCountOrder = [
  ContextToolCountKey.search,
  ContextToolCountKey.read,
  ContextToolCountKey.list,
];

class ContextToolCounts {
  const ContextToolCounts({this.read = 0, this.search = 0, this.list = 0});

  final int read;
  final int search;
  final int list;

  int operator [](ContextToolCountKey key) {
    switch (key) {
      case ContextToolCountKey.read:
        return read;
      case ContextToolCountKey.search:
        return search;
      case ContextToolCountKey.list:
        return list;
    }
  }
}

class ConsecutiveContextTools {
  const ConsecutiveContextTools({required this.items, required this.end});

  final List<ChatPart> items;
  final int end;
}

String normalizeContextToolName(String? toolName) {
  final trimmed = toolName?.trim().toLowerCase() ?? '';
  if (trimmed.isEmpty) return '';
  final withoutIndex = trimmed.replaceFirst(RegExp(r':\d+$'), '');
  if (!withoutIndex.contains('.')) return withoutIndex;
  final parts = withoutIndex.split('.').where((part) => part.isNotEmpty).toList();
  return parts.isEmpty ? withoutIndex : parts.last;
}

bool isContextGroupTool(String? toolName) =>
    contextGroupToolNames.contains(normalizeContextToolName(toolName));

bool isToolPartActive(ChatPart part) {
  final status = (part.status ?? '').trim().toLowerCase();
  if (_activeToolStatuses.contains(status)) return true;
  if (_settledToolStatuses.contains(status)) return false;
  return false;
}

bool isContextExploreSuccessorPart(ChatPart part) {
  if (part.kind == ChatPartKind.text ||
      part.kind == ChatPartKind.mermaid ||
      part.kind == ChatPartKind.reasoning) {
    return true;
  }
  if (part.kind == ChatPartKind.permission) return false;
  if (part.kind == ChatPartKind.tool ||
      part.kind == ChatPartKind.fileOp ||
      part.kind == ChatPartKind.diff ||
      part.kind == ChatPartKind.task) {
    return !isContextGroupTool(part.toolName);
  }
  return true;
}

bool hasContextExploreSuccessor(List<ChatPart> items, int start) {
  for (var index = start; index < items.length; index += 1) {
    if (isContextExploreSuccessorPart(items[index])) return true;
  }
  return false;
}

bool isContextGroupExploring({
  required List<ChatPart> parts,
  required bool hasFollowingOtherType,
  required bool isTurnLive,
}) {
  if (parts.any(isToolPartActive)) return true;
  if (hasFollowingOtherType) return false;
  return isTurnLive;
}

ContextToolCountKey? contextToolCountKey(String? toolName) {
  final name = normalizeContextToolName(toolName);
  if (name == 'read') return ContextToolCountKey.read;
  if (name == 'glob' || name == 'grep') return ContextToolCountKey.search;
  if (name == 'list') return ContextToolCountKey.list;
  return null;
}

ContextToolCounts summarizeContextTools(Iterable<String?> toolNames) {
  var read = 0;
  var search = 0;
  var list = 0;
  for (final toolName in toolNames) {
    switch (contextToolCountKey(toolName)) {
      case ContextToolCountKey.read:
        read += 1;
      case ContextToolCountKey.search:
        search += 1;
      case ContextToolCountKey.list:
        list += 1;
      case null:
        break;
    }
  }
  return ContextToolCounts(read: read, search: search, list: list);
}

ConsecutiveContextTools collectConsecutiveContextTools(List<ChatPart> items, int start) {
  final grouped = <ChatPart>[];
  var index = start;
  while (index < items.length && isContextGroupTool(items[index].toolName)) {
    grouped.add(items[index]);
    index += 1;
  }
  return ConsecutiveContextTools(items: grouped, end: index);
}

bool messageHasRunningTool(ChatMessage message) => message.parts.any(isToolPartActive);

bool messageHasConfirmedFinalBody(ChatMessage message) {
  final text = message.parts
      .where((part) => part.kind == ChatPartKind.text)
      .map((part) => part.body?.trim() ?? '')
      .where((text) => text.isNotEmpty)
      .join();
  return text.isNotEmpty && !messageHasRunningTool(message);
}
