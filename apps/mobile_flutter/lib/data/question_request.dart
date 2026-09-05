import 'settings_remote.dart';

class QuestionOption {
  const QuestionOption({required this.label, this.description = ''});

  final String label;
  final String description;
}

class QuestionInfo {
  const QuestionInfo({
    required this.question,
    this.header = '',
    this.options = const [],
    this.multiple = false,
  });

  final String question;
  final String header;
  final List<QuestionOption> options;
  final bool multiple;
}

/// Official `packages/ui/src/types/question.ts` `QuestionRequest`.
class QuestionRequest {
  const QuestionRequest({
    required this.id,
    required this.sessionId,
    this.questions = const [],
    this.callId,
  });

  final String id;
  final String sessionId;
  final List<QuestionInfo> questions;
  final String? callId;
}

QuestionRequest? parseQuestionRequest(Object? raw, {String? sessionId}) {
  if (raw is! Map) return null;
  final item = asObjectMap(raw);
  final id = item['id']?.toString() ?? '';
  if (id.isEmpty) return null;
  final session = item['sessionID']?.toString() ?? item['sessionId']?.toString() ?? sessionId ?? '';
  final tool = item['tool'] is Map ? asObjectMap(item['tool']) : const <String, Object?>{};
  return QuestionRequest(
    id: id,
    sessionId: session,
    questions: parseQuestionInfos(item['questions']),
    callId: tool['callID']?.toString() ?? tool['callId']?.toString(),
  );
}

List<QuestionRequest> parseQuestionList(Object? payload, {String? sessionId}) {
  if (payload is Map && payload['id'] != null) {
    final one = parseQuestionRequest(payload, sessionId: sessionId);
    return one == null ? const [] : [one];
  }
  final list = payload is List
      ? payload
      : payload is Map && payload['questions'] is List
          ? payload['questions'] as List
          : payload is Map && payload['items'] is List
              ? payload['items'] as List
              : const [];
  return list
      .map((item) => parseQuestionRequest(item, sessionId: sessionId))
      .whereType<QuestionRequest>()
      .where((item) => sessionId == null || item.sessionId.isEmpty || item.sessionId == sessionId)
      .toList();
}

List<QuestionInfo> parseQuestionInfos(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((item) {
    final map = asObjectMap(item);
    return QuestionInfo(
      question: map['question']?.toString() ?? '',
      header: map['header']?.toString() ?? '',
      multiple: map['multiple'] == true,
      options: parseQuestionOptions(map['options']),
    );
  }).toList();
}

List<QuestionInfo> questionsFromPartMetadata(Map<String, Object?> metadata) {
  return parseQuestionInfos(metadata['questions']);
}

List<QuestionOption> parseQuestionOptions(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((item) {
    final map = asObjectMap(item);
    return QuestionOption(
      label: map['label']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
    );
  }).where((item) => item.label.isNotEmpty).toList();
}
