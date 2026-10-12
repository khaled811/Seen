import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/validators/form_validators.dart';

void main() {
  group('positiveAmount', () {
    test('rejects a missing value', () {
      expect(FormValidators.positiveAmount(null, message: 'bad'), 'bad');
    });

    test('rejects zero and negative amounts', () {
      expect(FormValidators.positiveAmount('0', message: 'bad'), 'bad');
      expect(FormValidators.positiveAmount('-5', message: 'bad'), 'bad');
    });

    test('accepts a positive amount', () {
      expect(FormValidators.positiveAmount('10.50', message: 'bad'), isNull);
    });
  });

  group('maxAmount', () {
    test('accepts an empty value (left to other validators)', () {
      expect(FormValidators.maxAmount('', maxCents: 10000, message: 'too much'), isNull);
    });

    test('accepts a malformed value (left to other validators)', () {
      expect(FormValidators.maxAmount('abc', maxCents: 10000, message: 'too much'), isNull);
    });

    test('accepts an amount under the limit', () {
      expect(
        FormValidators.maxAmount('50.00', maxCents: 10000, message: 'too much'),
        isNull,
      );
    });

    test('accepts an amount exactly at the limit', () {
      expect(
        FormValidators.maxAmount('100.00', maxCents: 10000, message: 'too much'),
        isNull,
      );
    });

    test('rejects an amount over the limit', () {
      expect(
        FormValidators.maxAmount('100.01', maxCents: 10000, message: 'too much'),
        'too much',
      );
    });
  });
}
