import 'package:intl/intl.dart';

/// Money is represented internally as integer minor units (cents) — never
/// `double` — so ledger arithmetic can't drift from floating-point rounding.
/// [MoneyParser] converts to/from the backend's decimal-string wire format
/// using only integer math; [MoneyFormatter] is the one place a `double` is
/// allowed, purely to hand a value to `intl` for display.
abstract final class MoneyParser {
  /// Parses a decimal string (e.g. `"1234.5"`, `"-12"`) into integer cents.
  /// Extra fractional digits are truncated, not rounded, to avoid silently
  /// changing a value the backend is responsible for. Throws
  /// [FormatException] on a malformed string — a backend contract
  /// violation, surfaced rather than swallowed.
  static int centsFromDecimalString(String value) {
    final trimmed = value.trim();
    final negative = trimmed.startsWith('-');
    final unsigned = negative ? trimmed.substring(1) : trimmed;
    final parts = unsigned.split('.');
    if (parts.isEmpty || parts.length > 2) {
      throw FormatException('Not a valid decimal amount', value);
    }
    final whole = parts[0].isEmpty ? '0' : parts[0];
    final fractionRaw = parts.length > 1 ? parts[1] : '';
    final fraction = fractionRaw.padRight(2, '0').substring(0, 2);
    final cents = int.parse(whole) * 100 + int.parse(fraction.isEmpty ? '0' : fraction);
    return negative ? -cents : cents;
  }

  /// The inverse of [centsFromDecimalString] — for building outgoing
  /// GraphQL variables without ever going through `double`.
  static String decimalStringFromCents(int cents) {
    final negative = cents < 0;
    final absolute = cents.abs();
    final whole = absolute ~/ 100;
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$whole.$fraction';
  }
}

/// Display-only formatting. `cents / 100` here is safe: it never feeds back
/// into stored or transmitted amounts, only into text the user reads.
abstract final class MoneyFormatter {
  static String formatCents(
    int cents, {
    String locale = 'en_US',
    String symbol = r'$',
  }) {
    return NumberFormat.currency(locale: locale, symbol: symbol).format(cents / 100);
  }
}
