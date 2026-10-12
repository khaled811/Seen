import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/utils/money.dart';

void main() {
  group('centsFromDecimalString', () {
    test('parses a whole number', () {
      expect(MoneyParser.centsFromDecimalString('1234'), 123400);
    });

    test('parses two decimal places', () {
      expect(MoneyParser.centsFromDecimalString('1234.56'), 123456);
    });

    test('pads a single decimal place', () {
      expect(MoneyParser.centsFromDecimalString('1234.5'), 123450);
    });

    test('truncates extra decimal places rather than rounding', () {
      expect(MoneyParser.centsFromDecimalString('1234.567'), 123456);
    });

    test('parses a negative amount', () {
      expect(MoneyParser.centsFromDecimalString('-12.34'), -1234);
    });

    test('parses zero', () {
      expect(MoneyParser.centsFromDecimalString('0'), 0);
      expect(MoneyParser.centsFromDecimalString('0.00'), 0);
    });

    test('parses a leading-dot amount', () {
      expect(MoneyParser.centsFromDecimalString('.50'), 50);
    });

    test('throws FormatException on malformed input', () {
      expect(
        () => MoneyParser.centsFromDecimalString('abc'),
        throwsFormatException,
      );
      expect(
        () => MoneyParser.centsFromDecimalString('1.2.3'),
        throwsFormatException,
      );
    });
  });

  group('decimalStringFromCents', () {
    test('formats a whole-dollar amount', () {
      expect(MoneyParser.decimalStringFromCents(123400), '1234.00');
    });

    test('formats cents under 10', () {
      expect(MoneyParser.decimalStringFromCents(105), '1.05');
    });

    test('formats a negative amount', () {
      expect(MoneyParser.decimalStringFromCents(-1234), '-12.34');
    });

    test('formats zero', () {
      expect(MoneyParser.decimalStringFromCents(0), '0.00');
    });

    test('round-trips through centsFromDecimalString', () {
      for (final cents in [0, 1, 50, 100, 123456, -999, -1]) {
        final asString = MoneyParser.decimalStringFromCents(cents);
        expect(MoneyParser.centsFromDecimalString(asString), cents);
      }
    });
  });
}
