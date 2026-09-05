import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/prompt_attachment.dart';
import 'platform_channels.dart';

class SaveFileResult {
  const SaveFileResult({this.cancelled = false, this.failed = false});

  final bool cancelled;
  final bool failed;

  bool get saved => !cancelled && !failed;
}

/// Capacitor contract names: `OpenChamberMedia` / `OpenChamberVirtualAsset`.
/// Flutter uses MethodChannels; JSON keys stay the same.
class MediaChannel {
  MediaChannel({MethodChannel? media, MethodChannel? virtualAsset})
      : _media = media ?? const MethodChannel(OpenChamberChannels.media),
        _virtual = virtualAsset ?? const MethodChannel(OpenChamberChannels.virtualAsset);

  final MethodChannel _media;
  final MethodChannel _virtual;

  Future<List<AttachmentDraft>> pickFiles({int limit = 8}) async {
    try {
      final raw = await _media.invokeMethod<Object>('pickFiles', {'limit': limit});
      return _draftsFromChannel(raw);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<List<AttachmentDraft>> pickImages({int limit = 8}) async {
    try {
      final raw = await _media.invokeMethod<Object>('pickMedia', {'limit': limit});
      return _draftsFromChannel(raw);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<AttachmentDraft> transcodeHeic(AttachmentDraft draft) async {
    if (!draft.isHeic) return draft;
    try {
      final raw = await _media.invokeMethod<Object>('transcode', {
        'data': base64Encode(draft.bytes),
        'mime': draft.mime,
        'quality': 0.9,
      });
      if (raw is! Map) {
        throw const PromptAttachmentUploadError(0, 'transcode');
      }
      final encoded = raw['data']?.toString() ?? '';
      final mime = raw['mime']?.toString() ?? 'image/jpeg';
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty) {
        throw const PromptAttachmentUploadError(0, 'transcode');
      }
      final name = draft.name.replaceAll(RegExp(r'\.(heic|heif)$', caseSensitive: false), '.jpg');
      return AttachmentDraft(
        name: name.toLowerCase().endsWith('.jpg') ? name : '$name.jpg',
        mime: mime,
        bytes: Uint8List.fromList(bytes),
      );
    } on MissingPluginException {
      throw const PromptAttachmentUploadError(0, 'transcode');
    }
  }

  Future<SaveFileResult> saveFile({
    required String dataBase64,
    String mimeType = 'application/json',
    String filename = 'export.json',
  }) async {
    try {
      final raw = await _media.invokeMethod<Object>('saveFile', {
        'dataBase64': dataBase64,
        'mimeType': mimeType,
        'filename': filename,
      });
      if (raw is Map && raw['cancelled'] == true) {
        return const SaveFileResult(cancelled: true);
      }
      return const SaveFileResult();
    } on MissingPluginException {
      return const SaveFileResult(failed: true);
    } on PlatformException {
      return const SaveFileResult(failed: true);
    }
  }

  Future<void> publishVirtualAsset(AttachmentDraft draft) async {
    final id = attachmentIdFor(draft.name).replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (id.length < 8) return;
    try {
      await _virtual.invokeMethod<void>('create', {
        'assetId': id.substring(0, id.length > 80 ? 80 : id.length),
        'mime': draft.mime.startsWith('image/') ? draft.mime : 'image/jpeg',
      });
      await _virtual.invokeMethod<void>('append', {
        'assetId': id.substring(0, id.length > 80 ? 80 : id.length),
        'chunk': base64Encode(draft.bytes),
      });
      await _virtual.invokeMethod<void>('finish', {'assetId': id.substring(0, id.length > 80 ? 80 : id.length)});
    } on MissingPluginException {
      // Display uses Image.memory; native virtual URLs are for WebView.
    } on PlatformException {
      // Same — preview does not depend on the scheme handler.
    }
  }

  Future<List<AttachmentDraft>> _draftsFromChannel(Object? raw) async {
    if (raw is! Map) return const [];
    if (raw['cancelled'] == true) return const [];
    final files = raw['files'];
    if (files is! List) return const [];
    final drafts = <AttachmentDraft>[];
    for (final file in files) {
      if (file is! Map) continue;
      final draft = await _draftFromPicked(file);
      if (draft != null) drafts.add(draft);
    }
    return drafts;
  }

  Future<AttachmentDraft?> _draftFromPicked(Map<dynamic, dynamic> file) async {
    final name = file['name']?.toString() ?? 'image.jpg';
    final mime = file['mimeType']?.toString() ?? file['mime']?.toString() ?? 'image/jpeg';
    final encoded = file['dataBase64']?.toString();
    if (encoded != null && encoded.isNotEmpty) {
      final payload = encoded.contains(',') ? encoded.substring(encoded.indexOf(',') + 1) : encoded;
      final bytes = base64Decode(payload);
      if (bytes.isEmpty || bytes.length > maxPickedMediaBytes) return null;
      return AttachmentDraft(name: name, mime: mime, bytes: Uint8List.fromList(bytes));
    }
    final path = file['path']?.toString();
    if (path == null || path.isEmpty) return null;
    final bytes = await File(path).readAsBytes();
    if (bytes.isEmpty || bytes.length > maxPickedMediaBytes) return null;
    return AttachmentDraft(name: name, mime: mime, bytes: bytes);
  }
}
