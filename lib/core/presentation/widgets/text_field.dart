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
import 'svg_icon.dart';

/// Labelled input bound to the Figma Input component: label ABOVE the field
/// (never floating), 54px field, radius 16, 1.5px border, 14px body text.
///
/// States: default (strong line), focused (violet border), error (error
/// border + red helper line + trailing alert icon), disabled ([enabled] =
/// false: violet-05 fill, muted text), read-only (sunken fill, default line).
/// Passport data is always [ltr]; numbers use [mono]. Validate on blur, not
/// while typing.
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
    this.prefix,
    this.suffixText,
    this.suffix,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.picker = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.focusNode,
    this.below,
    this.showError = false,
    this.success = false,
  });

  final String label;
  final bool isRequired;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? helper;

  /// Replaces the helper line; shown in the error color with an alert icon.
  final String? errorText;
  final bool mono;
  final bool ltr;
  final IconData? prefixIcon;

  /// Inline widget before the value, at the reading start (right in Arabic),
  /// e.g. a country code. Shown even when the field is empty.
  final Widget? prefix;

  /// e.g. "USD"
  final String? suffixText;

  /// e.g. a "Show" toggle for passwords.
  final Widget? suffix;
  final bool readOnly;

  /// false = Figma "Disabled" state.
  final bool enabled;

  /// 1 = single line; more for free text (textarea).
  final int maxLines;

  /// A tap-to-pick field (date, select): not editable, but drawn as a normal
  /// enabled field rather than the read-only look.
  final bool picker;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;

  /// Keyboard action (done / search / send) pressed.
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;

  /// Extra content under the field, e.g. a validity/strength hint.
  final Widget? below;

  /// Draws the field in the error state (red border, alert mark) without a message
  /// of its own, e.g. the phone field next to a "wrong phone or password" line.
  final bool showError;

  /// Draws the field as accepted: green border and a check mark.
  final bool success;

  static const double _borderWidth = 1.5;

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: const BorderRadius.all(SeenRadius.lg),
        borderSide: BorderSide(color: color, width: _borderWidth),
      );

  /// The trailing mark: the caller's [suffix] (e.g. the password eye), the alert
  /// of an error, the check of an accepted value; an error keeps the caller's suffix
  /// next to the alert.
  Widget? _suffix(SeenColors c, Color okColor) {
    final hasError = errorText != null || showError;
    final mark = hasError
        ? Icon(SeenIcons.alert, size: 20, color: c.dangerFg)
        : (success ? SeenCheckGlyph(size: 20, color: okColor) : null);
    if (suffix == null) return mark;
    if (!hasError) return suffix;
    return Row(mainAxisSize: MainAxisSize.min, children: [mark!, const SizedBox(width: 8), suffix!]);
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final rtlContext = Directionality.of(context) == ui.TextDirection.rtl;
    final base = mono ? type.inputMono : type.body;
    final valueColor = !enabled ? c.inkMuted : (readOnly && !picker ? c.inkSecondary : c.ink);
    final plainReadOnly = readOnly && !picker;
    final filled = !enabled || plainReadOnly;
    final okColor = SeenRequestStatus.completed.colors.fg;
    final restingBorder = showError
        ? SeenBrand.inputErrorBorder
        : success
            ? okColor
            : (plainReadOnly && enabled ? c.border : c.borderStrong);
    const errorBorder = SeenBrand.inputErrorBorder;
    final helperStyle = type.caption.copyWith(color: c.inkMuted);
    final errorStyle = type.caption.copyWith(color: c.dangerFg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: label, style: type.label),
          if (isRequired) TextSpan(text: ' *', style: type.label.copyWith(color: c.dangerFg)),
        ])),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          focusNode: focusNode,
          enabled: enabled,
          maxLines: obscureText ? 1 : maxLines,
          readOnly: readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          onTap: onTap,
          validator: errorText == null ? validator : null, // an explicit errorText wins
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: base.copyWith(color: valueColor),
          textDirection: ltr ? ui.TextDirection.ltr : null,
          // An LTR value sits at the reading start of the field: right in Arabic, left in English.
          textAlign: ltr ? (rtlContext ? TextAlign.right : TextAlign.left) : TextAlign.start,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: base.copyWith(color: c.inkMuted),
            filled: true,
            fillColor: filled ? c.surfaceSunken : c.card,
            isDense: false,
            constraints: const BoxConstraints(minHeight: SeenSize.input),
            contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: SeenSpace.s4, vertical: SeenSpace.s4),
            border: _border(c.borderStrong),
            enabledBorder: _border(restingBorder),
            disabledBorder: _border(c.borderStrong),
            focusedBorder: _border(showError ? SeenBrand.inputErrorBorder : (success ? okColor : c.focus)),
            errorBorder: _border(errorBorder),
            focusedErrorBorder: _border(errorBorder),
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
            prefix: prefix,
            suffixText: suffixText,
            suffixStyle: base.copyWith(color: c.inkSecondary),
            suffixIcon: _suffix(c, okColor),
            helperText: errorText == null ? helper : null,
            helperStyle: helperStyle,
            helperMaxLines: 2,
            errorText: errorText,
            errorStyle: errorStyle,
            errorMaxLines: 2,
          ),
        ),
        if (below != null) below!,
      ],
    );
  }
}
