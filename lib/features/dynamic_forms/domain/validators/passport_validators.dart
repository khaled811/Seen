/// Pure date-rule checks for passport/travel documents.
///
/// Each takes [now] as an explicit parameter, rather than calling
/// `DateTime.now()` internally, so tests can pin "today" and stay
/// deterministic.
abstract final class PassportValidators {
  /// Must be at least [minMonths] months from [now].
  ///
  /// Uses [DateTime]'s own month-rollover normalization to add months, which
  /// is exact except at month-end edge cases (e.g. Aug 31 + 6 months lands
  /// on Mar 3, not "Feb 31") — acceptably conservative for this rule, which
  /// only needs to reject expiries that are clearly too soon.
  static bool isValidExpiryDate(
    DateTime expiry, {
    required DateTime now,
    int minMonths = 6,
  }) {
    final threshold = DateTime(now.year, now.month + minMonths, now.day);
    return !expiry.isBefore(threshold);
  }

  /// Must not be in the future relative to [now]. Used for both issue date
  /// and date of birth — same rule, different field semantics.
  static bool isNotInFuture(DateTime date, {required DateTime now}) =>
      !date.isAfter(now);
}
