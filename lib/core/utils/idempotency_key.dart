import 'dart:math';

/// A random (version 4) UUID for the `idempotencyKey` argument of operations
/// that move money (`docs/api/mobile-api.md` section 2): generated once per user
/// action and reused when that same action is retried, so a retry can never move
/// the money twice.
String generateIdempotencyKey([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  String hex(int from, int to) => [for (var i = from; i < to; i++) bytes[i].toRadixString(16).padLeft(2, '0')].join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// Remembers the key of the action in flight.
///
/// The same key is handed out while the action is the same (equal
/// [fingerprint]); a different fingerprint gets a new key, because the server
/// answers `idempotency_key_reused` when a key comes back with different
/// details. Call [settled] once the action succeeded or was definitively
/// rejected so the next action starts clean.
class IdempotencyKeyRegistry {
  IdempotencyKeyRegistry({Random? random}) : _random = random;

  final Random? _random;
  String? _fingerprint;
  String? _key;

  String keyFor(String fingerprint) {
    if (_key == null || _fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _key = generateIdempotencyKey(_random);
    }
    return _key!;
  }

  void settled() {
    _fingerprint = null;
    _key = null;
  }
}
