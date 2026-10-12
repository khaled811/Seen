import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';

/// Text that always shows Arabic-Indic digits.
class ArabicNumber extends StatelessWidget {
  const ArabicNumber(
    this.value, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  /// A number, or any string containing digits ("٣ من ٥" built from "3 من 5").
  final Object value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
        toArabicDigits(value),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
      );
}
