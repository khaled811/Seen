// TextField — universal labelled input.
//
// Adapted for Flutter 3.22.2: `AutovalidateMode.onUnfocus` is a later
// Flutter addition (this SDK only has `disabled` / `always` /
// `onUserInteraction` — verified against the installed SDK source, not
// assumed); `onUserInteraction` is the closest available equivalent.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';

/// Labelled input: label ABOVE the field (never floating), 52px, 16px input text.
/// Passport data is always [ltr]; numbers use [mono]. Validate on blur, not while typing.
class SeenTextField extends StatelessWidget {
  const SeenTextField({
    super.key,
    required this.label,
    this.isRequired = false,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.errorText,
    this.mono = false,
    this.ltr = false,
    this.prefixIcon,
    this.suffixText,
    this.suffix,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onTap,
    this.validator,
    this.focusNode,
    this.below,
  });

  final String label;
  final bool isRequired;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? helper;

  /// Replaces the helper line; shown with an alert icon.
  final String? errorText;
  final bool mono;
  final bool ltr;
  final IconData? prefixIcon;

  /// e.g. "USD"
  final String? suffixText;

  /// e.g. a "Show" toggle for passwords.
  final Widget? suffix;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;

  /// Extra content under the field, e.g. a validity/strength hint.
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    final rtlContext = Directionality.of(context) == ui.TextDirection.rtl;
    final base = mono ? SeenType.of(context).inputMono : text.bodyLarge!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: label, style: text.bodyMedium),
          if (isRequired) TextSpan(text: ' *', style: text.bodyMedium!.copyWith(color: c.dangerFg)),
        ])),
        const SizedBox(height: SeenSpace.s2),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          focusNode: focusNode,
          readOnly: readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onTap: onTap,
          validator: errorText == null ? validator : null, // an explicit errorText wins
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: base.copyWith(color: readOnly ? c.inkSecondary : c.ink),
          textDirection: ltr ? ui.TextDirection.ltr : null,
          // An LTR value sits at the reading start of the field: right in Arabic, left in English.
          textAlign: ltr ? (rtlContext ? TextAlign.right : TextAlign.left) : TextAlign.start,
          decoration: InputDecoration(
            hintText: hint,
            fillColor: readOnly ? c.surfaceSunken : c.card,
            enabledBorder: readOnly
                ? OutlineInputBorder(borderRadius: const BorderRadius.all(SeenRadius.sm), borderSide: BorderSide(color: c.border))
                : null,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
            suffixText: suffixText,
            suffixIcon: suffix,
            helperText: errorText == null ? helper : null,
            helperMaxLines: 2,
            error: errorText == null
                ? null
                : Row(children: [
                    Icon(SeenIcons.alert, size: 14, color: c.dangerFg),
                    const SizedBox(width: SeenSpace.s1),
                    Expanded(child: Text(errorText!, style: text.bodySmall!.copyWith(color: c.dangerFg))),
                  ]),
          ),
        ),
        if (below != null) below!,
      ],
    );
  }
}
