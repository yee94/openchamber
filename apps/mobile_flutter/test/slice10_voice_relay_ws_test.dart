import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/chat_timeline.dart';
import 'package:openchamber/data/dictation.dart';
import 'package:openchamber/data/dictation_protocol.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/pcm_capture.dart';
import 'package:openchamber/data/relay/crypto.dart';
import 'package:openchamber/data/relay/handshake.dart';
import 'package:openchamber/data/relay/protocol.dart';
import 'package:openchamber/data/relay/tunnel_client.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/features/chat/tool_cards.dart';
import 'package:openchamber/l10n/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dictation WS URI mints oc_url_token on the official path', () {
    final uri = dictationWebSocketUri(
      Uri.parse('http://192.168.1.74:2606'),
      urlToken: 'oc_url_secret',
    );
    expect(uri.scheme, 'ws');
    expect(uri.path, OpenChamberPaths.dictationWs);
    expect(uri.queryParameters['oc_url_token'], 'oc_url_secret');
    expect(pcmDictationFormat, 'audio/pcm;rate=16000;bits=16');
  });

  test('official dictation client streams PCM chunks then finish', () async {
    final wire = MemoryDictationWire();
    final client = OfficialDictationClient(wire);
    wire.deliver({'type': 'ready'});
    await client.waitUntilReady();
    const id = 'dic_test';
    final started = client.startStream(dictationId: id);
    await Future<void>.delayed(Duration.zero);
    wire.deliver({'type': 'ack', 'dictationId': id});
    await started;
    client.sendChunk(dictationId: id, seq: 0, audio: 'AAAA');
    final finished = client.finishStream(dictationId: id, finalSeq: 0);
    await Future<void>.delayed(Duration.zero);
    wire.deliver({'type': 'final', 'dictationId': id, 'text': 'hello from pcm'});
    expect(await finished, 'hello from pcm');
    expect(wire.sent.map((item) => item['type']), ['start', 'chunk', 'finish']);
    expect(wire.sent[0]['format'], pcmDictationFormat);
    expect(wire.sent[1]['audio'], 'AAAA');
    await client.close();
  });

  test('OfficialDictation production path streams captured PCM', () async {
    final wire = MemoryDictationWire();
    final capture = MemoryPcmCapture(segments: ['AQID']);
    final api = OpenChamberApi(transport: MemoryOpenChamberTransport());
    final session = OfficialDictation(
      resolveBase: () => Uri.parse('http://192.168.1.74:2606'),
      resolveBearer: () => 'oc_client',
      resolveTransport: () => api.transport,
      api: api,
      capture: capture,
      openWire: (_, __) async {
        wire.deliver({'type': 'ready'});
        return wire;
      },
    );
    final started = session.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final start = wire.sent.firstWhere((item) => item['type'] == 'start');
    wire.deliver({'type': 'ack', 'dictationId': start['dictationId']});
    await started;
    expect(session.status, DictationStatus.recording);
    expect(capture.started, isTrue);
    expect(wire.sent.any((item) => item['type'] == 'chunk' && item['audio'] == 'AQID'), isTrue);
    final confirmed = session.confirm();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final finish = wire.sent.firstWhere((item) => item['type'] == 'finish');
    wire.deliver({'type': 'final', 'dictationId': finish['dictationId'], 'text': 'streamed pcm'});
    final result = await confirmed;
    expect(result?.text, 'streamed pcm');
  });

  test('tunneled WebSocket carries dictation and oc_url_token', () async {
    final http = MemoryOpenChamberTransport();
    final opened = await _openMemoryTunnel(http);
    final token = await OpenChamberApi(transport: opened.client).mintUrlToken(
      base: RelayTunnelTransport.dummyBase,
      bearer: 'oc_client',
    );
    expect(token, 'oc_url_test');
    expect(http.calls.any((call) => call.path == OpenChamberPaths.authUrlToken), isTrue);

    final capture = MemoryPcmCapture(segments: ['BBBB']);
    final session = OfficialDictation(
      resolveBase: () => RelayTunnelTransport.dummyBase,
      resolveBearer: () => 'oc_client',
      resolveTransport: () => opened.client,
      api: OpenChamberApi(transport: opened.client),
      capture: capture,
    );
    await session.start();
    expect(session.status, DictationStatus.recording);
    expect(opened.host.lastWsQuery, contains('oc_url_token=oc_url_test'));
    final result = await session.confirm();
    expect(result?.text, 'tunneled transcript');
    await opened.client.close();
    await opened.host.close();
  });

  test('message TTS posts official /api/tts/speak', () async {
    final transport = MemoryOpenChamberTransport();
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: transport),
      dictation: MemoryDictation(),
    );
    await controller.bootstrap(skipDelay: true);
    await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    await controller.speakMessage('Read this reply');
    expect(
      transport.calls.any((call) => call.method == 'POST' && call.path == OpenChamberPaths.ttsSpeak),
      isTrue,
    );
    final speak = transport.calls.firstWhere((call) => call.path == OpenChamberPaths.ttsSpeak);
    expect(speak.body?['text'], 'Read this reply');
    expect(speak.body?['summarize'], false);
    expect(speak.rawResponse, isTrue);
  });

  testWidgets('assistant message exposes read-aloud', (tester) async {
    var spoken = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StringsScope(
          strings: AppStrings.of(AppStrings.en),
          child: Scaffold(
            body: ChatTranscriptBody(
              message: const ChatMessage(
                id: 'm-tts',
                body: 'Hello from the assistant.',
                isUser: false,
                parts: [
                  ChatPart(id: 't1', kind: ChatPartKind.text, title: 'text', body: 'Hello from the assistant.'),
                ],
              ),
              onSpeak: () => spoken = true,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('chat-tts-m-tts')), findsOneWidget);
    expect(find.text('Read aloud'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-tts-m-tts')));
    expect(spoken, isTrue);
  });
}

Future<({RelayTunnelTransport client, MemoryRelayHost host})> _openMemoryTunnel(
  MemoryOpenChamberTransport http,
) async {
  final hostKeys = generateEcdhKeyPair();
  final pair = MemoryTunnelPair();
  final host = MemoryRelayHost(
    handshake: HostHandshake(hostKeys.privateKey),
    wire: pair.host,
    handler: (request) => http.send(RelayTunnelTransport.dummyBase, request),
  );
  final client = RelayTunnelTransport(
    wire: pair.client,
    handshake: ClientHandshake.create(hostKeys.publicJwk),
  );
  await client.establish();
  return (client: client, host: host);
}
