import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/auth/presentation/utils/phone_identifier.dart';

void main() {
  group('toIdentifier', () {
    test('prepends the default country code and drops one trunk zero', () {
      expect(PhoneIdentifier.toIdentifier('77 123 4567'), '+967771234567');
      expect(PhoneIdentifier.toIdentifier('077-123-4567'), '+967771234567');
    });

    test('accepts Arabic-Indic digits', () {
      expect(PhoneIdentifier.toIdentifier('٧٧١٢٣٤٥٦٧'), '+967771234567');
    });

    test('keeps numbers that are already international', () {
      expect(PhoneIdentifier.toIdentifier('+966 50 123 4567'), '+966501234567');
      expect(PhoneIdentifier.toIdentifier('00966501234567'), '+966501234567');
    });

    test('honours an explicit country code', () {
      expect(PhoneIdentifier.toIdentifier('501234567', countryCode: '+966'), '+966501234567');
    });
  });

  group('isValid', () {
    test('requires 7-15 digits', () {
      expect(PhoneIdentifier.isValid(''), isFalse);
      expect(PhoneIdentifier.isValid('123456'), isFalse);
      expect(PhoneIdentifier.isValid('771234567'), isTrue);
      expect(PhoneIdentifier.isValid('1234567890123456'), isFalse);
    });
  });

  group('mask', () {
    test('hides the middle of a phone number', () {
      expect(PhoneIdentifier.mask('+967771234567'), '+96777 ••• 4567');
    });

    test('hides the local part of an email and leaves short values alone', () {
      expect(PhoneIdentifier.mask('agent@seen.com'), 'a•••@seen.com');
      expect(PhoneIdentifier.mask('12345'), '12345');
    });
  });
}
