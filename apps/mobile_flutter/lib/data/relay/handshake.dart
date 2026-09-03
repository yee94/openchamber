import 'dart:convert';
import 'dart:typed_data';

import 'crypto.dart';
import 'protocol.dart';

class EstablishedChannel {
  EstablishedChannel({required this.encryptor, required this.decryptor, required this.batch});
  final FrameEncryptor encryptor;
  final FrameDecryptor decryptor;
  final bool batch;
}

class HandshakeAction {
  const HandshakeAction._(this.kind, {this.channel, this.replyText, this.reason, this.closeCode});
  factory HandshakeAction.established(EstablishedChannel channel, {String? replyText}) =>
      HandshakeAction._('established', channel: channel, replyText: replyText);
  factory HandshakeAction.sendText(String text) => HandshakeAction._('send-text', replyText: text);
  factory HandshakeAction.ignore() => const HandshakeAction._('ignore');
  factory HandshakeAction.fail(String reason, {int closeCode = RelayCloseCode.channelFailure}) =>
      HandshakeAction._('fail', reason: reason, closeCode: closeCode);

  final String kind;
  final EstablishedChannel? channel;
  final String? replyText;
  final String? reason;
  final int? closeCode;
}

Map<String, Object?>? _parseHandshake(String raw) {
  try {
    final parsed = jsonDecode(raw);
    if (parsed is! Map) return null;
    final message = parsed.map((key, value) => MapEntry(key.toString(), value));
    if (message['v'] != relayProtocolVersion) return null;
    return message;
  } catch (_) {
    return null;
  }
}

class ClientHandshake {
  ClientHandshake._(
    this.helloText,
    this._privateKey,
    this._hostPublic,
    this._nonce,
    this._advertiseBatch,
  );

  final String helloText;
  final ECPrivateKey _privateKey;
  final Map<String, String> _hostPublic;
  final Uint8List _nonce;
  final bool _advertiseBatch;
  bool established = false;

  static ClientHandshake create(Map<String, String> hostEncPubJwk, {bool batch = true}) {
    importPublicJwk(hostEncPubJwk);
    final ephemeral = generateEcdhKeyPair();
    final nonce = generateHandshakeNonce();
    final hello = <String, Object?>{
      't': 'hello',
      'v': relayProtocolVersion,
      'clientPubJwk': ephemeral.publicJwk,
      'nonce': bytesToBase64Url(nonce),
      if (batch) 'batch': true,
    };
    return ClientHandshake._(
      jsonEncode(hello),
      ephemeral.privateKey,
      hostEncPubJwk,
      nonce,
      batch,
    );
  }

  HandshakeAction handleText(String raw) {
    final message = _parseHandshake(raw);
    if (established) {
      if (message?['t'] == 'ready') return HandshakeAction.ignore();
      return HandshakeAction.fail('plaintext frame on established channel');
    }
    if (message?['t'] != 'ready') return HandshakeAction.ignore();
    final keys = deriveSessionKeys(
      ownPrivateKey: _privateKey,
      peerPublicKey: importPublicJwk(_hostPublic),
      handshakeNonce: _nonce,
    );
    established = true;
    return HandshakeAction.established(
      EstablishedChannel(
        encryptor: FrameEncryptor(keys.clientToHost),
        decryptor: FrameDecryptor(keys.hostToClient),
        batch: _advertiseBatch && message?['batch'] == true,
      ),
    );
  }
}

class HostHandshake {
  HostHandshake(this._privateKey, {bool batch = true}) : _advertiseBatch = batch;

  final ECPrivateKey _privateKey;
  final bool _advertiseBatch;
  bool established = false;
  String? _acceptedFingerprint;
  String? _readyText;

  HandshakeAction handleText(String raw) {
    final message = _parseHandshake(raw);
    if (message?['t'] != 'hello') {
      if (established) return HandshakeAction.fail('plaintext frame on established channel');
      return HandshakeAction.ignore();
    }
    final jwkRaw = message?['clientPubJwk'];
    if (jwkRaw is! Map || message?['nonce'] is! String) {
      return HandshakeAction.fail('malformed hello');
    }
    final jwk = jwkRaw.map((key, value) => MapEntry(key.toString(), value.toString()));
    final fingerprint = jsonEncode({'crv': jwk['crv'], 'kty': jwk['kty'], 'x': jwk['x'], 'y': jwk['y']});
    if (_acceptedFingerprint != null) {
      if (fingerprint == _acceptedFingerprint && _readyText != null) {
        return HandshakeAction.sendText(_readyText!);
      }
      return HandshakeAction.fail('rekey mismatch', closeCode: RelayCloseCode.rekeyMismatch);
    }
    late final SessionKeys keys;
    try {
      keys = deriveSessionKeys(
        ownPrivateKey: _privateKey,
        peerPublicKey: importPublicJwk(jwk),
        handshakeNonce: base64UrlToBytes(message!['nonce'] as String),
      );
    } catch (_) {
      return HandshakeAction.fail('malformed hello');
    }
    final negotiated = _advertiseBatch && message['batch'] == true;
    final ready = <String, Object?>{
      't': 'ready',
      'v': relayProtocolVersion,
      if (negotiated) 'batch': true,
    };
    _readyText = jsonEncode(ready);
    _acceptedFingerprint = fingerprint;
    established = true;
    return HandshakeAction.established(
      EstablishedChannel(
        encryptor: FrameEncryptor(keys.hostToClient),
        decryptor: FrameDecryptor(keys.clientToHost),
        batch: negotiated,
      ),
      replyText: _readyText,
    );
  }
}
