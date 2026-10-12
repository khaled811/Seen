import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/core/arabic_digits.dart';

void main() {
  test('converts every Latin digit', () {
    expect(toArabicDigits('0123456789'), '٠١٢٣٤٥٦٧٨٩');
  });

  test('accepts ints and leaves other characters alone', () {
    expect(toArabicDigits(293), '٢٩٣');
    expect(toArabicDigits('8,325 كم'), '٨,٣٢٥ كم');
    expect(toArabicDigits('٣ من 7'), '٣ من ٧');
    expect(toArabicDigits(''), '');
  });
}
