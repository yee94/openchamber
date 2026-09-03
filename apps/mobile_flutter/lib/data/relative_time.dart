/// Compact relative timestamps matching official mobile home / scheduled cards.
String? formatRelativeTime(num? value, {DateTime? now}) {
  final millis = _asMillis(value);
  if (millis == null) return null;
  final then = DateTime.fromMillisecondsSinceEpoch(millis);
  final delta = (now ?? DateTime.now()).difference(then);
  final future = delta.isNegative;
  final abs = future ? -delta : delta;
  final label = _compact(abs);
  if (label == null) return future ? 'now' : 'now';
  return future ? label : label;
}

String? formatRelativeCountdown(num? value, {DateTime? now, required String Function(String duration) inFuture}) {
  final millis = _asMillis(value);
  if (millis == null) return null;
  final then = DateTime.fromMillisecondsSinceEpoch(millis);
  final delta = then.difference(now ?? DateTime.now());
  final abs = delta.isNegative ? -delta : delta;
  final label = _compact(abs);
  if (label == null) return null;
  return delta.isNegative ? label : inFuture(label);
}

String? _compact(Duration abs) {
  if (abs.inSeconds < 45) return null;
  if (abs.inMinutes < 60) return '${abs.inMinutes}m';
  if (abs.inHours < 24) {
    final hours = abs.inHours;
    final minutes = abs.inMinutes % 60;
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  if (abs.inDays < 14) {
    final days = abs.inDays;
    final hours = abs.inHours % 24;
    return hours == 0 ? '${days}d' : '${days}d ${hours}h';
  }
  return '${abs.inDays}d';
}

int? _asMillis(num? value) {
  if (value == null || value <= 0) return null;
  if (value < 1e9) return null;
  if (value < 1e11) return (value * 1000).round();
  return value.round();
}
