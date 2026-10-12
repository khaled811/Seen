import 'arabic_digits.dart';

/// 8325 -> "٨,٣٢٥" (Arabic-Indic digits, "," as the thousands separator, as in
/// the design).
String formatThousands(num value) {
  final digits = value.round().abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return toArabicDigits('${value < 0 ? '-' : ''}$out');
}

/// 21.4225 + "ش" -> "٢١٫٤٢٢٥° ش" (Arabic decimal separator).
String formatCoordinate(double degrees, String hemisphere, {int decimals = 4}) {
  final text = degrees.abs().toStringAsFixed(decimals).replaceAll('.', '٫');
  return '${toArabicDigits(text)}° $hemisphere';
}
