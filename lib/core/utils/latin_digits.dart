import 'package:flutter/services.dart';

/// Maps Arabic-Indic (٠-٩) and Persian/Urdu (۰-۹) digits to Latin 0-9.
/// Phone numbers, OTP codes and other identifiers are always entered and
/// sent in Latin digits, whatever keyboard or locale the user has.
String toLatinDigits(String input) {
  final out = StringBuffer();
  for (final unit in input.runes) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      out.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      out.writeCharCode(0x30 + unit - 0x06F0);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// Latin 0-9 (and the `,` group separator) to Arabic-Indic digits for display
/// of counts in Arabic. `intl` formats the `ar` locale with Latin digits, so
/// the conversion is explicit.
String toArabicIndicDigits(String input) {
  final out = StringBuffer();
  for (final unit in input.runes) {
    if (unit >= 0x30 && unit <= 0x39) {
      out.writeCharCode(0x0660 + unit - 0x30);
    } else if (unit == 0x2C) {
      out.writeCharCode(0x066C);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// [TextInputFormatter] that rewrites Arabic-Indic/Persian digits to Latin as
/// the user types. Place it BEFORE any digit-filtering formatter.
class LatinDigitsFormatter extends TextInputFormatter {
  const LatinDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final converted = toLatinDigits(newValue.text);
    if (converted == newValue.text) return newValue;
    // Digit-for-digit replacement keeps the length, so selection stays valid.
    return newValue.copyWith(text: converted);
  }
}
