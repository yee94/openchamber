/// Port of `packages/ui/src/components/chat/message/parts/skillToolGrouping.ts`.
library;

import 'chat_timeline.dart';
import 'context_tool_grouping.dart';

const skillGroupVisibleLimit = 3;

class ConsecutiveSkillTools {
  const ConsecutiveSkillTools({required this.items, required this.end});

  final List<ChatPart> items;
  final int end;
}

class SkillNameSummary {
  const SkillNameSummary({
    required this.visibleNames,
    required this.hiddenCount,
    required this.joinedVisible,
  });

  final List<String> visibleNames;
  final int hiddenCount;
  final String joinedVisible;
}

bool isSkillGroupTool(String? toolName) => normalizeContextToolName(toolName) == 'skill';

String? getSkillNameFromPart(ChatPart part) {
  final fromMeta = part.metadata['name']?.toString().trim();
  if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
  final title = part.title.trim();
  if (title.isNotEmpty && title.toLowerCase() != 'skill') return title;
  return null;
}

SkillNameSummary summarizeSkillNames(Iterable<String?> names) {
  final cleaned = <String>[];
  for (final name in names) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isNotEmpty) cleaned.add(trimmed);
  }
  final visible = cleaned.take(skillGroupVisibleLimit).toList();
  return SkillNameSummary(
    visibleNames: visible,
    hiddenCount: cleaned.length > visible.length ? cleaned.length - visible.length : 0,
    joinedVisible: visible.join(', '),
  );
}

ConsecutiveSkillTools collectConsecutiveSkillTools(List<ChatPart> items, int start) {
  final grouped = <ChatPart>[];
  var index = start;
  while (index < items.length && isSkillGroupTool(items[index].toolName)) {
    grouped.add(items[index]);
    index += 1;
  }
  return ConsecutiveSkillTools(items: grouped, end: index);
}

bool isBashTool(String? toolName) {
  final name = normalizeContextToolName(toolName);
  return name == 'bash' || name == 'shell' || name == 'cmd' || name == 'terminal';
}

bool isWebFetchTool(String? toolName) {
  final name = normalizeContextToolName(toolName);
  return name == 'webfetch' || name == 'fetch' || name == 'curl' || name == 'wget';
}

bool isWebSearchTool(String? toolName) {
  final name = normalizeContextToolName(toolName);
  return name == 'websearch' ||
      name == 'web-search' ||
      name == 'search_web' ||
      name == 'codesearch' ||
      name == 'google' ||
      name == 'bing' ||
      name == 'duckduckgo' ||
      name == 'perplexity';
}

bool isQuestionTool(String? toolName) => normalizeContextToolName(toolName) == 'question';
