/// Token-safe persistence. Implementations must never log values.
///
/// First slice: an in-process store that tests inject, plus a
/// [MemorySecureStore] used until Keychain / EncryptedSharedPreferences
/// plugins land. See `docs/flutter-native-gap.md` (secure storage).
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
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
