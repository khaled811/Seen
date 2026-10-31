import 'dart:convert';

/// Error codes of the backend contract (`errors[].extensions.code`), the ones
/// the transport itself must understand. The full list is in
/// `docs/api/mobile-api-reference.md`. Always branch on the code, never on the
/// message.
abstract final class ApiErrorCodes {
  static const String notAuthenticated = 'not_authenticated';
  static const String sessionExpired = 'session_expired';
  static const String noRefreshSession = 'no_refresh_session';
  static const String permissionDenied = 'permission_denied';
  static const String tooManyAttempts = 'too_many_attempts';
  static const String validationFailed = 'validation_failed';

  /// A `refresh` answered with one of these means the session is over and the
  /// person must sign in again (contract section 3.4).
  static const Set<String> sessionEnded = {notAuthenticated, sessionExpired, noRefreshSession};

  /// The codes of every error in a decoded GraphQL response body, in order.
  static List<String> codesOf(Object? body) {
    if (body is! Map) return const [];
    final errors = body['errors'];
    if (errors is! List) return const [];
    return [
      for (final e in errors)
        if (e is Map && e['extensions'] is Map && (e['extensions'] as Map)['code'] is String)
          (e['extensions'] as Map)['code'] as String,
    ];
  }

  /// Whether the raw response [bytes] carry an error with [code]. Cheap for the
  /// common case: the body is only parsed when the code text appears in it.
  static bool bytesContainCode(List<int> bytes, String code) {
    try {
      final text = utf8.decode(bytes, allowMalformed: true);
      if (!text.contains(code)) return false;
      return codesOf(jsonDecode(text)).contains(code);
    } catch (_) {
      return false;
    }
  }
}
