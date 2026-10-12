import '../../../../core/utils/latin_digits.dart';

/// Maps what the user types into the phone field onto the single `identifier`
/// string the auth contract (`AuthLoginSubmitted.identifier` → GraphQL login)
/// already accepts. Pure Dart so it is unit-testable.
abstract final class PhoneIdentifier {
  /// Country shown in the phone field. Figma shows a Yemeni number and has no
  /// country picker, so this is a fixed default for now.
  static const defaultCountryCode = '+967';

  static const minDigits = 7;
  static const maxDigits = 15;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// The login field takes an email or a phone number. Anything typed with an
  /// `@` or a letter is an email; otherwise it is a phone number.
  static bool looksLikeEmail(String raw) => RegExp(r'[@A-Za-z]').hasMatch(raw);

  /// Valid email (when [looksLikeEmail]) or valid phone number.
  static bool isValidIdentifier(String raw) =>
      looksLikeEmail(raw) ? _emailPattern.hasMatch(raw.trim()) : isValid(raw);

  /// The `identifier` for the auth contract: a trimmed email as typed, or the
  /// E.164 phone from [toIdentifier].
  static String toLoginIdentifier(String raw, {String countryCode = defaultCountryCode}) =>
      looksLikeEmail(raw) ? raw.trim() : toIdentifier(raw, countryCode: countryCode);

  /// Digits only, Latin, no spaces/dashes/leading `+`.
  static String digitsOf(String raw) => toLatinDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');

  /// `true` if [raw] holds a plausible phone number (7-15 digits, E.164 range).
  static bool isValid(String raw) {
    final digits = digitsOf(raw);
    return digits.length >= minDigits && digits.length <= maxDigits;
  }

  /// E.164-style identifier: `+<country><national>`.
  ///  * input starting with `+` or `00` is taken as already international;
  ///  * otherwise a single trunk `0` is dropped and [countryCode] is prepended.
  static String toIdentifier(String raw, {String countryCode = defaultCountryCode}) {
    final latin = toLatinDigits(raw).trim();
    final digits = digitsOf(latin);
    if (latin.startsWith('+')) return '+$digits';
    if (digits.startsWith('00')) return '+${digits.substring(2)}';
    final national = digits.startsWith('0') ? digits.substring(1) : digits;
    return '$countryCode$national';
  }

  /// Masked form for display, e.g. `+96777 ••• 4567`. Anything that is not a
  /// phone (e.g. an email identifier) keeps only its first character visible.
  static String mask(String identifier) {
    if (identifier.contains('@')) {
      final at = identifier.indexOf('@');
      return at <= 1 ? identifier : '${identifier[0]}•••${identifier.substring(at)}';
    }
    final digits = digitsOf(identifier);
    if (digits.length < 9) return identifier;
    final head = digits.substring(0, digits.length - 7);
    final tail = digits.substring(digits.length - 4);
    return '+$head ••• $tail';
  }
}
