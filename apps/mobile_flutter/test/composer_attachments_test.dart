import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/prompt_attachment.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/native/media_channel.dart';
import 'package:openchamber/native/platform_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HEIC/HEIF mimes need JPEG transcode; JPEG does not', () {
    expect(needsHeicTranscode('image/heic'), isTrue);
    expect(needsHeicTranscode('image/HEIF'), isTrue);
    expect(needsHeicTranscode(' image/heif '), isTrue);
    expect(const AttachmentDraft(name: 'a.heic', mime: 'image/heic', bytes: Uint8List(0)).isHeic, isTrue);
    expect(needsHeicTranscode('image/jpeg'), isFalse);
    expect(needsHeicTranscode('image/png'), isFalse);
    expect(needsHeicTranscode('application/octet-stream'), isFalse);
  });

  test('prepareComposerAttachments transcodes HEIC then keeps JPEG bytes for upload', () async {
    final heic = AttachmentDraft(
      name: 'IMG_0001.HEIC',
      mime: 'image/heic',
      bytes: Uint8List.fromList(List<int>.filled(32, 9)),
    );
    final jpeg = AttachmentDraft(
      name: 'keep.jpg',
      mime: 'image/jpeg',
      bytes: Uint8List.fromList(List<int>.filled(8, 3)),
    );
    var transcodeCalls = 0;
    final prepared = await prepareComposerAttachments(
      picked: [heic, jpeg],
      transcodeHeic: (draft) async {
        transcodeCalls += 1;
        expect(draft.mime, 'image/heic');
        return AttachmentDraft(
          name: 'IMG_0001.jpg',
          mime: 'image/jpeg',
          bytes: Uint8List.fromList(List<int>.filled(16, 4)),
        );
      },
    );
    expect(transcodeCalls, 1);
    expect(prepared.errorKey, isNull);
    expect(prepared.ready, hasLength(2));
    expect(prepared.ready.first.mime, 'image/jpeg');
    expect(prepared.ready.first.name, 'IMG_0001.jpg');
    expect(prepared.ready.first.bytes, Uint8List.fromList(List<int>.filled(16, 4)));
    expect(prepared.ready.last.mime, 'image/jpeg');
    expect(prepared.ready.last.bytes, jpeg.bytes);
  });

  test('prepareComposerAttachments skips oversized drafts and does not fake success', () async {
    final huge = AttachmentDraft(
      name: 'huge.jpg',
      mime: 'image/jpeg',
      bytes: Uint8List(maxPromptAttachmentBytes + 1),
    );
    final ok = AttachmentDraft(
      name: 'ok.jpg',
      mime: 'image/jpeg',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    final prepared = await prepareComposerAttachments(
      picked: [huge, ok],
      transcodeHeic: (draft) async => draft,
    );
    expect(prepared.errorKey, 'chat.error.attachmentTooLarge');
    expect(prepared.ready.single.name, 'ok.jpg');
  });

  test('MediaChannel.transcodeHeic renames HEIC and returns JPEG from the native contract', () async {
    const channel = MethodChannel(OpenChamberChannels.media);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'transcode');
      final args = Map<String, Object?>.from(call.arguments as Map);
      expect(args['mime'], 'image/heic');
      expect(args['quality'], 0.9);
      expect(args['data'], isA<String>());
      return {
        'data': base64Encode(List<int>.filled(12, 11)),
        'mime': 'image/jpeg',
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final media = MediaChannel();
    final result = await media.transcodeHeic(
      AttachmentDraft(
        name: 'album.HEIC',
        mime: 'image/heic',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    );
    expect(result.mime, 'image/jpeg');
    expect(result.name, 'album.jpg');
    expect(result.bytes, Uint8List.fromList(List<int>.filled(12, 11)));

    final passthrough = await media.transcodeHeic(
      AttachmentDraft(name: 'plain.jpg', mime: 'image/jpeg', bytes: Uint8List.fromList([9])),
    );
    expect(passthrough.mime, 'image/jpeg');
    expect(passthrough.name, 'plain.jpg');
    expect(passthrough.bytes, Uint8List.fromList([9]));
  });

  test('sendPrompt after HEIC→JPEG prepare uses official prompt-attachments and file:// parts', () async {
    final transport = MemoryOpenChamberTransport();
    final api = OpenChamberApi(transport: transport);
    final controller = AppController(store: MemorySecureStore(), api: api);
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606');
    await controller.refreshSessions();
    final session = controller.sessions.firstWhere((row) => row.id == 'sess-catalog');

    final heic = AttachmentDraft(
      name: 'photo.heic',
      mime: 'image/heic',
      bytes: Uint8List.fromList(List<int>.filled(24, 5)),
    );
    final jpegBytes = Uint8List.fromList(List<int>.filled(10, 8));
    final prepared = await prepareComposerAttachments(
      picked: [heic],
      transcodeHeic: (draft) async => AttachmentDraft(
        name: 'photo.jpg',
        mime: 'image/jpeg',
        bytes: jpegBytes,
      ),
    );
    expect(prepared.ready.single.mime, 'image/jpeg');

    await controller.sendPrompt(
      session: session,
      messageId: 'msg-heic',
      text: 'see album',
      attachments: prepared.ready,
    );

    final upload = transport.calls.firstWhere((call) => call.path.startsWith('/api/fs/prompt-attachments/'));
    expect(upload.method, 'PUT');
    expect(upload.bytes, jpegBytes);
    expect(upload.extraHeaders['X-OpenChamber-Mime'], 'image/jpeg');
    expect(upload.extraHeaders['X-OpenChamber-Sha256'], sha256Hex(jpegBytes));
    expect(upload.extraHeaders['X-OpenChamber-Content-Length'], '${jpegBytes.length}');
    expect(transport.sentPromptParts.single.any((part) => part['type'] == 'file'), isTrue);
    expect(transport.sentPromptParts.single.any((part) => part['mime'] == 'image/jpeg'), isTrue);
    expect(transport.sentPromptParts.single.any((part) => part['url']?.toString().startsWith('file://') == true), isTrue);
    expect(transport.sentPromptParts.single.any((part) => part['url']?.toString().startsWith('data:') == true), isFalse);
    expect(transport.sentPromptParts.single.any((part) => part['url']?.toString().startsWith('blob:') == true), isFalse);
    expect(transport.sentPrompts, ['see album']);
  });
}
