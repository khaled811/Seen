import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/utils/latin_digits.dart';

void main() {
  test('maps Arabic-Indic and Persian digits to Latin and leaves the rest alone', () {
    expect(toLatinDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    expect(toLatinDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    expect(toLatinDigits('+٩٦٧ 77-abc'), '+967 77-abc');
  });

  test('Arabic-Indic display conversion handles digits and the group separator', () {
    expect(toArabicIndicDigits('1,234'), '١٬٢٣٤');
    expect(toArabicIndicDigits('52'), '٥٢');
  });

  test('formatter converts as the user types and keeps selection', () {
    const formatter = LatinDigitsFormatter();
    const typed = TextEditingValue(text: '٧٧', selection: TextSelection.collapsed(offset: 2));
    final out = formatter.formatEditUpdate(TextEditingValue.empty, typed);
    expect(out.text, '77');
    expect(out.selection.baseOffset, 2);
  });
}
