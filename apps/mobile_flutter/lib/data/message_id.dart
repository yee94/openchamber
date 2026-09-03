import 'dart:math';

/// OpenCode `Identifier.ascending` / `packages/ui/src/sync/message-id.ts`.
/// Client-generated message IDs must sort with server IDs.
const _base62 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
const _randomLength = 14;
final _valueMask = (BigInt.one << 48) - BigInt.one;
final _random = Random.secure();

BigInt _lastAscendingValue = BigInt.zero;

String _randomBase62(int length) {
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(_base62[_random.nextInt(_base62.length)]);
  }
  return buffer.toString();
}

String ascendingId(String prefix) {
  final base = (BigInt.from(DateTime.now().millisecondsSinceEpoch) * BigInt.from(0x1000)) & _valueMask;
  final maximum = base > _lastAscendingValue ? base : _lastAscendingValue;
  final value = maximum + BigInt.one;
  _lastAscendingValue = value;
  final hex = value.toUnsigned(48).toRadixString(16).padLeft(12, '0');
  return '${prefix}_$hex${_randomBase62(_randomLength)}';
}
