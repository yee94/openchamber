import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

export 'package:pointycastle/export.dart' show ECPrivateKey, ECPublicKey;

import 'protocol.dart';

class RelayCryptoError implements Exception {
  RelayCryptoError(this.message);
  final String message;
  @override
  String toString() => 'RelayCryptoError($message)';
}

class RelayKeyPair {
  RelayKeyPair({required this.privateKey, required this.publicJwk});
  final ECPrivateKey privateKey;
  final Map<String, String> publicJwk;
}

final _domain = ECDomainParameters('prime256v1');

FortunaRandom _secureRandom() {
  final rnd = FortunaRandom();
  final seed = Uint8List(32);
  final dart = Random.secure();
  for (var i = 0; i < seed.length; i++) {
    seed[i] = dart.nextInt(256);
  }
  rnd.seed(KeyParameter(seed));
  return rnd;
}

Uint8List _unsigned(BigInt value, int length) {
  final bytes = value.toUnsigned(length * 8).toRadixString(16).padLeft(length * 2, '0');
  return Uint8List.fromList([
    for (var i = 0; i < bytes.length; i += 2) int.parse(bytes.substring(i, i + 2), radix: 16),
  ]);
}

String bytesToBase64Url(Uint8List bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

Uint8List base64UrlToBytes(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]*$').hasMatch(value) || value.length % 4 == 1) {
    throw RelayCryptoError('invalid base64url input');
  }
  var normalized = value.replaceAll('-', '+').replaceAll('_', '/');
  final pad = (4 - normalized.length % 4) % 4;
  normalized = normalized.padRight(normalized.length + pad, '=');
  return Uint8List.fromList(base64.decode(normalized));
}

Map<String, String> exportPublicJwk(ECPublicKey key) {
  final point = key.Q;
  if (point == null) throw RelayCryptoError('invalid ECDH public key JWK');
  return {
    'kty': 'EC',
    'crv': 'P-256',
    'x': bytesToBase64Url(_unsigned(point.x!.toBigInteger()!, 32)),
    'y': bytesToBase64Url(_unsigned(point.y!.toBigInteger()!, 32)),
  };
}

ECPublicKey importPublicJwk(Map<String, String> jwk) {
  if (jwk['kty'] != 'EC' || jwk['crv'] != 'P-256' || jwk['x'] == null || jwk['y'] == null) {
    throw RelayCryptoError('invalid ECDH public key JWK');
  }
  try {
    final x = _readUnsigned(base64UrlToBytes(jwk['x']!));
    final y = _readUnsigned(base64UrlToBytes(jwk['y']!));
    final point = _domain.curve.createPoint(x, y);
    return ECPublicKey(point, _domain);
  } catch (error) {
    if (error is RelayCryptoError) rethrow;
    throw RelayCryptoError('invalid ECDH public key JWK');
  }
}

BigInt _readUnsigned(Uint8List bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

RelayKeyPair generateEcdhKeyPair() {
  final rnd = _secureRandom();
  final generator = ECKeyGenerator()..init(ParametersWithRandom(ECKeyGeneratorParameters(_domain), rnd));
  final pair = generator.generateKeyPair();
  return RelayKeyPair(
    privateKey: pair.privateKey as ECPrivateKey,
    publicJwk: exportPublicJwk(pair.publicKey as ECPublicKey),
  );
}

Uint8List generateHandshakeNonce() {
  final nonce = Uint8List(handshakeNonceBytes);
  final dart = Random.secure();
  for (var i = 0; i < nonce.length; i++) {
    nonce[i] = dart.nextInt(256);
  }
  return nonce;
}

class SessionKeys {
  SessionKeys({required this.clientToHost, required this.hostToClient});
  final Uint8List clientToHost;
  final Uint8List hostToClient;
}

SessionKeys deriveSessionKeys({
  required ECPrivateKey ownPrivateKey,
  required ECPublicKey peerPublicKey,
  required Uint8List handshakeNonce,
}) {
  if (handshakeNonce.length != handshakeNonceBytes) {
    throw RelayCryptoError('invalid handshake nonce length');
  }
  final agreement = ECDHBasicAgreement()..init(ownPrivateKey);
  final shared = agreement.calculateAgreement(peerPublicKey);
  final sharedSecret = _unsigned(shared, 32);
  // RFC 5869 HKDF-SHA-256 — same inputs as `packages/ui/src/lib/relay/crypto.ts`
  // (salt = handshake nonce, info = RELAY_HKDF_INFO, 64-byte OKM).
  final material = _hkdfSha256(
    ikm: sharedSecret,
    salt: handshakeNonce,
    info: Uint8List.fromList(utf8.encode(relayHkdfInfo)),
    length: sessionKeyBytes * 2,
  );
  return SessionKeys(
    clientToHost: Uint8List.sublistView(material, 0, sessionKeyBytes),
    hostToClient: Uint8List.sublistView(material, sessionKeyBytes),
  );
}

Uint8List _hkdfSha256({
  required Uint8List ikm,
  required Uint8List salt,
  required Uint8List info,
  required int length,
}) {
  final extract = HMac(SHA256Digest(), 64)..init(KeyParameter(salt));
  final prk = extract.process(ikm);
  final okm = BytesBuilder(copy: false);
  var previous = Uint8List(0);
  var counter = 1;
  while (okm.length < length) {
    final expand = HMac(SHA256Digest(), 64)..init(KeyParameter(prk));
    expand.update(previous, 0, previous.length);
    expand.update(info, 0, info.length);
    expand.updateByte(counter);
    previous = Uint8List(32);
    expand.doFinal(previous, 0);
    okm.add(previous);
    counter += 1;
  }
  return Uint8List.sublistView(okm.toBytes(), 0, length);
}

void _writeCounter(Uint8List target, int offset, BigInt counter) {
  var value = counter;
  for (var i = ivCounterBytes - 1; i >= 0; i--) {
    target[offset + i] = (value & BigInt.from(0xff)).toInt();
    value >>= 8;
  }
}

BigInt _readCounter(Uint8List source, int offset) {
  var value = BigInt.zero;
  for (var i = 0; i < ivCounterBytes; i++) {
    value = (value << 8) | BigInt.from(source[offset + i]);
  }
  return value;
}

Uint8List _aesGcm(Uint8List key, Uint8List iv, Uint8List data, {required bool encrypt}) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(encrypt, AEADParameters(KeyParameter(key), gcmTagBytes * 8, iv, Uint8List(0)));
  try {
    return cipher.process(data);
  } catch (_) {
    throw RelayCryptoError(encrypt ? 'frame encryption failed' : 'frame decryption failed');
  }
}

class FrameEncryptor {
  FrameEncryptor(this._key) {
    final dart = Random.secure();
    for (var i = 0; i < _ivPrefix.length; i++) {
      _ivPrefix[i] = dart.nextInt(256);
    }
  }

  final Uint8List _key;
  final Uint8List _ivPrefix = Uint8List(ivPrefixBytes);
  BigInt _counter = BigInt.zero;

  Uint8List encrypt(Uint8List plaintext) {
    if (plaintext.length > maxPlaintextFrameBytes) {
      throw RelayCryptoError('plaintext frame exceeds maximum size');
    }
    _counter += BigInt.one;
    final iv = Uint8List(encryptedFrameIvBytes);
    iv.setAll(0, _ivPrefix);
    _writeCounter(iv, ivPrefixBytes, _counter);
    final ciphertext = _aesGcm(_key, iv, plaintext, encrypt: true);
    final frame = Uint8List(encryptedFrameHeaderBytes + ciphertext.length);
    frame[0] = encryptedFrameVersion;
    frame.setAll(1, iv);
    frame.setAll(encryptedFrameHeaderBytes, ciphertext);
    return frame;
  }
}

class FrameDecryptor {
  FrameDecryptor(this._key);
  final Uint8List _key;
  BigInt _lastCounter = BigInt.zero;

  Uint8List decrypt(Uint8List frame) {
    if (frame.length < encryptedFrameHeaderBytes + gcmTagBytes) {
      throw RelayCryptoError('encrypted frame too short');
    }
    if (frame[0] != encryptedFrameVersion) {
      throw RelayCryptoError('unsupported encrypted frame version');
    }
    final iv = frame.sublist(1, encryptedFrameHeaderBytes);
    final counter = _readCounter(iv, ivPrefixBytes);
    if (counter <= _lastCounter) {
      throw RelayCryptoError('frame counter regression');
    }
    final plaintext = _aesGcm(_key, iv, frame.sublist(encryptedFrameHeaderBytes), encrypt: false);
    _lastCounter = counter;
    return plaintext;
  }
}
