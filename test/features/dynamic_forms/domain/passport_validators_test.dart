import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/dynamic_forms/domain/validators/passport_validators.dart';

void main() {
  final now = DateTime(2026, 9, 26);

  group('isValidExpiryDate', () {
    test('rejects an expiry less than 6 months away', () {
      final expiry = DateTime(2027, 1, 1); // ~3 months
      expect(PassportValidators.isValidExpiryDate(expiry, now: now), isFalse);
    });

    test('accepts an expiry exactly 6 months away', () {
      final expiry = DateTime(2027, 3, 26);
      expect(PassportValidators.isValidExpiryDate(expiry, now: now), isTrue);
    });

    test('accepts an expiry well past the 6-month threshold', () {
      final expiry = DateTime(2030, 1, 1);
      expect(PassportValidators.isValidExpiryDate(expiry, now: now), isTrue);
    });

    test('respects a custom minMonths', () {
      final expiry = DateTime(2027, 6, 26); // 9 months away
      expect(
        PassportValidators.isValidExpiryDate(expiry, now: now, minMonths: 12),
        isFalse,
      );
    });
  });

  group('isNotInFuture', () {
    test('rejects a date after now', () {
      expect(
        PassportValidators.isNotInFuture(DateTime(2026, 9, 27), now: now),
        isFalse,
      );
    });

    test('accepts today', () {
      expect(PassportValidators.isNotInFuture(now, now: now), isTrue);
    });

    test('accepts a date in the past', () {
      expect(
        PassportValidators.isNotInFuture(DateTime(2000, 1, 1), now: now),
        isTrue,
      );
    });
  });
}
