/// Converts every Latin digit (0-9) in [value] to its Arabic-Indic form
/// (٠-٩). Any other character is left untouched.
String toArabicDigits(Object value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final input = value.toString();
  final out = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      out.write(arabic[unit - 0x30]);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}
