import 'package:cookie_jar/cookie_jar.dart';

/// `PersistCookieJar` with the two guarantees the stock jar does not give.
///
/// `DefaultCookieJar` decides with `(secure && https) || !expired`, so a Secure
/// cookie is also sent over plain http and an expired Secure cookie is still
/// sent over https. This subclass drops cookies that are Secure on a non-https
/// request or already expired, and it treats unreadable stored cookies as "no
/// cookies" (and forgets them) instead of failing the request.
class StrictPersistCookieJar extends PersistCookieJar {
  StrictPersistCookieJar({required super.storage, super.persistSession = false, super.ignoreExpires});

  @override
  Future<List<Cookie>> loadForRequest(Uri uri) async {
    try {
      final loaded = await super.loadForRequest(uri);
      return [
        for (final cookie in loaded)
          if (!(cookie.secure && uri.scheme != 'https') && !_isExpired(cookie)) cookie,
      ];
    } catch (_) {
      try {
        await deleteAll();
      } catch (_) {
        // Already unusable; behave as signed out.
      }
      return const [];
    }
  }

  bool _isExpired(Cookie cookie) {
    if (ignoreExpires) return false;
    for (final byHost in [hostCookies, domainCookies]) {
      for (final byPath in byHost.values) {
        // Cookies restored from storage sit in lazily cast maps whose static
        // value type is wrong; `cast` on a cast view goes back to the source
        // (the same trick the stock jar uses), so iteration is safe.
        for (final byName in byPath.cast<String, Map<String, dynamic>>().values) {
          for (final stored in byName.values) {
            if (stored is SerializableCookie && identical(stored.cookie, cookie)) return stored.isExpired();
          }
        }
      }
    }
    return false;
  }
}
