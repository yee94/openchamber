/// Official composer STT: WebSocket `/api/dictation/ws`
/// (`packages/ui/src/lib/dictation/dictation-client.ts`). Flutter has no
/// tunneled WebSocket and no PCM capture yet. Production uses
/// [UnavailableDictation] so the mic stays visible and the official failure
/// is shown. [MemoryDictation] is for widget tests only.
library;

enum DictationStatus { idle, recording, uploading, failed }

class DictationResult {
  const DictationResult({required this.text});
  final String text;
}

abstract class DictationSession {
  DictationStatus get status;
  String get partialTranscript;
  Future<void> start();
  Future<DictationResult?> confirm();
  Future<void> cancel();
}

class UnavailableDictation implements DictationSession {
  DictationStatus _status = DictationStatus.idle;

  @override
  DictationStatus get status => _status;

  @override
  String get partialTranscript => '';

  @override
  Future<void> start() async {
    _status = DictationStatus.failed;
  }

  @override
  Future<DictationResult?> confirm() async {
    _status = DictationStatus.idle;
    return null;
  }

  @override
  Future<void> cancel() async {
    _status = DictationStatus.idle;
  }
}

class MemoryDictation implements DictationSession {
  MemoryDictation({this.transcript = 'hello from dictation'});

  final String transcript;
  DictationStatus _status = DictationStatus.idle;
  String _partial = '';

  @override
  DictationStatus get status => _status;

  @override
  String get partialTranscript => _partial;

  @override
  Future<void> start() async {
    _status = DictationStatus.recording;
    _partial = transcript;
  }

  @override
  Future<DictationResult?> confirm() async {
    if (_status == DictationStatus.idle) return null;
    _status = DictationStatus.idle;
    return DictationResult(text: _partial);
  }

  @override
  Future<void> cancel() async {
    _status = DictationStatus.idle;
    _partial = '';
  }
}
