import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the cookie jar keeps its cookies: the platform's encrypted storage
/// (Android Keystore-backed, iOS Keychain), never plain files.
///
/// `PersistCookieJar` writes one entry per host (the key is the host name) whose
/// JSON contains the cookie *value*, i.e. the refresh token, plus two small
/// index entries. All of them live under [keyPrefix].
///
/// Failures never escape: an unreadable entry reads as "no cookie" (the person
/// signs in again) and a failed write only means the cookie is not restored
/// after a restart. [beforeFirstUse] runs once, before the jar first touches
/// storage; the install guard uses it to drop cookies that survived an app
/// reinstall (the iOS Keychain outlives the app).
class SecureCookieStorage implements Storage {
  SecureCookieStorage({
    required FlutterSecureStorage storage,
    Future<void> Function()? beforeFirstUse,
  })  : _storage = storage,
        _beforeFirstUse = beforeFirstUse;

  static const String keyPrefix = 'api_cookie_jar_v1:';

  final FlutterSecureStorage _storage;
  final Future<void> Function()? _beforeFirstUse;

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {
    try {
      await _beforeFirstUse?.call();
    } catch (_) {
      // The guard is best effort; the jar must still start.
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: '$keyPrefix$key');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: '$keyPrefix$key', value: value);
    } catch (_) {
      // Keep working from memory for this run.
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: '$keyPrefix$key');
    } catch (_) {
      // Nothing more to do.
    }
  }

  /// Removes every cookie entry, whatever [keys] the jar still remembers: if
  /// its index was lost an entry could otherwise be left behind.
  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
    await wipe(_storage);
  }

  /// Deletes every entry under [keyPrefix].
  static Future<void> wipe(FlutterSecureStorage storage) async {
    try {
      final all = await storage.readAll();
      for (final key in all.keys.toList()) {
        if (key.startsWith(keyPrefix)) await storage.delete(key: key);
      }
    } catch (_) {
      // Unreadable storage cannot hold a usable cookie either.
    }
  }
}
