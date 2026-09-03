import 'package:flutter/services.dart';

import '../native/platform_channels.dart';

/// Token-safe persistence. Implementations must never log values.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production store: iOS Keychain + Android Keystore-wrapped prefs.
/// Never log [key] values or returned secrets.
class PlatformSecureStore implements SecureStore {
  PlatformSecureStore({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(OpenChamberChannels.secureStore);

  final MethodChannel _channel;

  @override
  Future<String?> read(String key) async {
    final value = await _channel.invokeMethod<String>('read', {'key': key});
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    await _channel.invokeMethod<void>('write', {'key': key, 'value': value});
  }

  @override
  Future<void> delete(String key) async {
    await _channel.invokeMethod<void>('delete', {'key': key});
  }
}

class MemorySecureStore implements SecureStore {
  MemorySecureStore([Map<String, String>? seed]) : _values = Map.of(seed ?? const {});

  final Map<String, String> _values;

  Map<String, String> get snapshot => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
