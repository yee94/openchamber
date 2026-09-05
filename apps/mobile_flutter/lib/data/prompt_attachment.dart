import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

import 'openchamber_api.dart';

/// Official prompt-attachment contract from
/// `packages/ui/src/lib/prompt-attachment-upload.ts`.
/// Never put `data:` / `blob:` URLs into `prompt_async`.
const int maxPromptAttachmentBytes = 25 * 1024 * 1024;
const int maxPickedMediaBytes = 32 * 1024 * 1024;
const String fileUriPrefix = 'file://';

class PromptAttachmentUploadError implements Exception {
  const PromptAttachmentUploadError(this.status, this.code);

  final int status;
  final String code;

  @override
  String toString() => 'PromptAttachmentUploadError($status $code)';
}

class PromptAttachmentUploadResult {
  const PromptAttachmentUploadResult({
    required this.path,
    required this.url,
    required this.mime,
    required this.size,
    required this.sha256,
  });

  final String path;
  final String url;
  final String mime;
  final int size;
  final String sha256;
}

class PromptFilePart {
  const PromptFilePart({
    required this.mime,
    required this.filename,
    required this.url,
  });

  final String mime;
  final String filename;
  final String url;
}

class AttachmentDraft {
  const AttachmentDraft({
    required this.name,
    required this.mime,
    required this.bytes,
  });

  final String name;
  final String mime;
  final Uint8List bytes;

  bool get isHeic {
    final lower = mime.toLowerCase();
    return lower == 'image/heic' || lower == 'image/heif';
  }
}

String sha256Hex(List<int> bytes) {
  final digest = SHA256Digest().process(Uint8List.fromList(bytes));
  final buffer = StringBuffer();
  for (final byte in digest) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

String attachmentIdFor(String? filename) {
  final raw = '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  final cleaned = filename
      ?.replaceAll(RegExp(r'[^a-z0-9._-]+', caseSensitive: false), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final suffix = cleaned == null || cleaned.isEmpty
      ? null
      : cleaned.substring(0, cleaned.length > 32 ? 32 : cleaned.length);
  return suffix != null && suffix.isNotEmpty ? 'att-$raw-$suffix' : 'att-$raw';
}

String toPromptAttachmentFileUrl(String filepath) {
  final trimmed = filepath.trim();
  if (trimmed.toLowerCase().startsWith(fileUriPrefix)) return trimmed;
  if (trimmed.startsWith('/')) return '$fileUriPrefix$trimmed';
  return '$fileUriPrefix/$trimmed';
}

bool needsHeicTranscode(String mime) {
  final lower = mime.trim().toLowerCase();
  return lower == 'image/heic' || lower == 'image/heif';
}

class PreparedComposerAttachments {
  const PreparedComposerAttachments({required this.ready, this.errorKey});

  final List<AttachmentDraft> ready;
  final String? errorKey;
}

/// Album/picker attach pipeline: HEIC/HEIF → JPEG via [transcodeHeic], then
/// the official 25 MiB upload cap. Preview publish stays in the composer.
Future<PreparedComposerAttachments> prepareComposerAttachments({
  required List<AttachmentDraft> picked,
  required Future<AttachmentDraft> Function(AttachmentDraft draft) transcodeHeic,
}) async {
  final ready = <AttachmentDraft>[];
  String? errorKey;
  for (final draft in picked) {
    var next = draft;
    if (needsHeicTranscode(next.mime)) {
      next = await transcodeHeic(next);
    }
    if (next.bytes.length > maxPromptAttachmentBytes) {
      errorKey = 'chat.error.attachmentTooLarge';
      continue;
    }
    ready.add(next);
  }
  return PreparedComposerAttachments(ready: ready, errorKey: errorKey);
}

Future<PromptAttachmentUploadResult> uploadPromptAttachmentBytes({
  required OpenChamberApi api,
  required Uri base,
  String? bearer,
  required List<int> bytes,
  required String mime,
  String? filename,
}) async {
  if (bytes.isEmpty || bytes.length > maxPromptAttachmentBytes) {
    throw const PromptAttachmentUploadError(413, 'too-large');
  }
  final digest = sha256Hex(bytes);
  final id = attachmentIdFor(filename);
  final result = await api.putPromptAttachment(
    base: base,
    bearer: bearer,
    attachmentId: id,
    bytes: bytes,
    mime: mime,
    filename: filename,
    sha256: digest,
  );
  if (result.size != bytes.length) {
    throw PromptAttachmentUploadError(200, 'unavailable');
  }
  return result;
}
