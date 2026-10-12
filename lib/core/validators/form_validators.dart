import '../utils/money.dart';

/// Pure client-side form validation. Purely cosmetic — the backend is the
/// authority and must re-validate everything it receives.
abstract final class FormValidators {
  static String? required(String? value, {required String message}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? otpCode(
    String? value, {
    required String message,
    int length = 6,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length != length || !RegExp(r'^\d+$').hasMatch(trimmed)) {
      return message;
    }
    return null;
  }

  /// Validates a raw decimal-amount string is present, parseable, and > 0.
  /// Run this before converting the value to cents — by the time business
  /// logic sees the amount, it's already known to be well-formed.
  static String? positiveAmount(String? value, {required String message}) {
    final parsed = num.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) return message;
    return null;
  }

  /// Validates a raw decimal-amount string does not exceed [maxCents] (e.g.
  /// a transfer that must not exceed the sender's available balance).
  /// Malformed input is left to `positiveAmount`/similar to report — this
  /// only ever returns [message] for a well-formed amount that's too large.
  static String? maxAmount(
    String? value, {
    required int maxCents,
    required String message,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    try {
      if (MoneyParser.centsFromDecimalString(trimmed) > maxCents) return message;
    } on FormatException {
      return null;
    }
    return null;
  }
}
