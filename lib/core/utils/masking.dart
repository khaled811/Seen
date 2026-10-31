import 'dart:math' as math;

/// How sensitive values look while hidden (design/gaps SPEC §5). The number of dots never
/// follows the value's length, so a masked value does not leak how long it is.
abstract final class Masking {
  static const _dot = '•';

  /// `N08494821` -> `••••••4821`
  static String keepLast4(String value) =>
      value.length <= 4 ? _dot * 6 : '${_dot * 6}${value.substring(value.length - 4)}';

  /// `sara.a@mail.com` -> `sa•••••@mail.com`
  static String email(String value) {
    final at = value.indexOf('@');
    if (at <= 0) {
      return keepLast4(value);
    }
    return '${value.substring(0, math.min(2, at))}${_dot * 5}${value.substring(at)}';
  }

  /// `+966 512 345 214` -> `+966 5•• ••• 214`
  static String phone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length < 9) {
      return keepLast4(value);
    }
    final country = digits.substring(0, digits.length - 9);
    final local = digits.substring(digits.length - 9);
    final prefix = country.isEmpty ? '' : '+$country ';
    return '$prefix${local[0]}$_dot$_dot $_dot$_dot$_dot ${local.substring(6)}';
  }
}
