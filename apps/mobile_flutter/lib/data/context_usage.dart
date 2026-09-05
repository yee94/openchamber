/// Port of official `packages/ui/src/mobile/chat/mobileContextUsage.ts` and
/// `packages/ui/src/sync/context-token-baseline.ts`.
///
/// The chat ring is **tokens / model context limit**, not provider quota.
/// Quotas (`GET /api/quota/{id}`) are a separate metadata-sheet section.
library;

import 'chat_timeline.dart';

class MobileContextDisplay {
  const MobileContextDisplay({
    required this.percentage,
    required this.tokensLabel,
  });

  final double percentage;
  final String tokensLabel;
}

class ContextTokenBaseline {
  const ContextTokenBaseline({required this.messageId, required this.totalTokens});

  final String messageId;
  final num totalTokens;
}

num readContextTokenCount(Object? value) {
  return value is num && value.isFinite ? value : 0;
}

ContextTokenRecord? parseContextTokenRecord(Object? value) {
  if (value is! Map) return null;
  final record = ContextTokenRecord(
    input: readContextTokenCount(value['input']),
    output: readContextTokenCount(value['output']),
    reasoning: readContextTokenCount(value['reasoning']),
    cacheRead: readContextTokenCount(value['cache'] is Map ? (value['cache'] as Map)['read'] : null),
    cacheWrite: readContextTokenCount(value['cache'] is Map ? (value['cache'] as Map)['write'] : null),
  );
  return record.hasAny ? record : null;
}

String formatContextTokens(num value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.round().toString();
}

/// Official `resolveContextColorClass` bands, without CSS class names.
enum ContextUsageBand { ok, warning, error }

ContextUsageBand resolveContextUsageBand(double percentage) {
  if (percentage >= 90) return ContextUsageBand.error;
  if (percentage >= 75) return ContextUsageBand.warning;
  return ContextUsageBand.ok;
}

MobileContextDisplay? buildMobileContextDisplay({
  required num totalTokens,
  required num contextLimit,
  bool isDraft = false,
}) {
  if (isDraft || totalTokens <= 0 || contextLimit <= 0) return null;
  final percentage = (totalTokens / contextLimit) * 100;
  return MobileContextDisplay(
    percentage: percentage > 999 ? 999 : percentage,
    tokensLabel: '${formatContextTokens(totalTokens)}/${formatContextTokens(contextLimit)}',
  );
}

/// Newest→oldest scan. A compaction row newer than the last token-bearing
/// assistant resets the baseline (`compacted` → usage unknown).
ContextTokenBaseline? scanContextTokenBaseline(List<ChatMessage> messages) {
  for (var i = messages.length - 1; i >= 0; i -= 1) {
    final message = messages[i];
    if (message.isUser) {
      if (message.hasCompactionPart) return null;
      continue;
    }
    final tokens = message.tokens;
    if (tokens == null || !tokens.hasAny) continue;
    return ContextTokenBaseline(messageId: message.id, totalTokens: tokens.total);
  }
  return null;
}

num getLatestAssistantTotalTokens(List<ChatMessage> messages) {
  return scanContextTokenBaseline(messages)?.totalTokens ?? 0;
}

num? getNumericContextLimit(Object? limit) {
  if (limit is! Map) return null;
  final value = limit['context'];
  return value is num && value.isFinite && value > 0 ? value : null;
}

({String providerID, String modelID})? getLatestUserMessageModel(List<ChatMessage> messages) {
  for (var i = messages.length - 1; i >= 0; i -= 1) {
    final message = messages[i];
    if (!message.isUser) continue;
    final providerID = message.providerID?.trim();
    final modelID = message.modelID?.trim();
    if (providerID != null && providerID.isNotEmpty && modelID != null && modelID.isNotEmpty) {
      return (providerID: providerID, modelID: modelID);
    }
  }
  return null;
}

num? resolveContextLimit({
  required Map<String, num> catalogLimits,
  String? providerID,
  String? modelID,
  String? defaultModel,
}) {
  if (providerID != null && modelID != null) {
    final keyed = catalogLimits['$providerID/$modelID'];
    if (keyed != null && keyed > 0) return keyed;
    final modelOnly = catalogLimits[modelID];
    if (modelOnly != null && modelOnly > 0) return modelOnly;
  }
  final fallback = defaultModel?.trim();
  if (fallback == null || fallback.isEmpty) return null;
  return catalogLimits[fallback];
}

Map<String, num> parseProviderContextLimits(Object? payload) {
  if (payload is! Map) return const {};
  final providers = payload['providers'];
  if (providers is! List) return const {};
  final limits = <String, num>{};
  for (final provider in providers) {
    if (provider is! Map) continue;
    final providerId = provider['id']?.toString() ?? '';
    final models = provider['models'];
    if (models is! Map) continue;
    models.forEach((modelId, spec) {
      if (spec is! Map) return;
      final limit = getNumericContextLimit(spec['limit']);
      if (limit == null || providerId.isEmpty) return;
      final id = modelId.toString();
      limits['$providerId/$id'] = limit;
      limits[id] = limit;
    });
  }
  return limits;
}

class QuotaUsageRow {
  const QuotaUsageRow({
    required this.providerId,
    required this.providerName,
    this.usedPercent,
    this.status,
  });

  final String providerId;
  final String providerName;
  final num? usedPercent;
  final String? status;
}

QuotaUsageRow parseQuotaUsageRow(String providerId, Object? payload) {
  if (payload is! Map) {
    return QuotaUsageRow(providerId: providerId, providerName: providerId, status: 'unavailable');
  }
  final name = payload['providerName']?.toString() ?? providerId;
  if (payload['ok'] != true) {
    return QuotaUsageRow(
      providerId: providerId,
      providerName: name,
      status: payload['error']?.toString() ?? (payload['configured'] == false ? 'not configured' : 'unavailable'),
    );
  }
  num? percent;
  final usage = payload['usage'];
  if (usage is Map) {
    final windows = usage['windows'];
    if (windows is List && windows.isNotEmpty && windows.first is Map) {
      final used = (windows.first as Map)['usedPercent'];
      if (used is num) percent = used;
    } else if (windows is Map) {
      for (final value in windows.values) {
        if (value is Map && value['usedPercent'] is num) {
          percent = value['usedPercent'] as num;
          break;
        }
      }
    }
  }
  return QuotaUsageRow(providerId: providerId, providerName: name, usedPercent: percent);
}
