import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Removes data that earlier app versions wrote to secure storage and that must
/// no longer live on the device: traveler drafts (passport data) and recent
/// searches (may hold names). See `docs/implementation/DECISIONS.md` F-07.
///
/// Runs once per launch and is safe to repeat. It never throws: an unreadable
/// store is reset instead, because leftover unreadable data is worse than
/// losing a theme or language preference.
class LegacyDataPurger {
  LegacyDataPurger(this._storage);

  final FlutterSecureStorage _storage;

  static const List<String> sensitiveKeyPrefixes = [
    'booking_drafts_v1:',
    'request_recent_searches_v1:',
  ];

  /// Exact keys that earlier versions used for the session; added to the purge
  /// once the access token stops being persisted (see [purgeSession]).
  static const List<String> sessionKeys = ['auth_token', 'session_user'];

  Future<void> purge({bool purgeSession = false}) async {
    try {
      final all = await _storage.readAll();
      for (final key in all.keys.toList()) {
        final sensitive = sensitiveKeyPrefixes.any(key.startsWith) || (purgeSession && sessionKeys.contains(key));
        if (sensitive) await _storage.delete(key: key);
      }
    } catch (_) {
      try {
        await _storage.deleteAll();
      } catch (_) {
        // Nothing more can be done; the next launch tries again.
      }
    }
  }
}
