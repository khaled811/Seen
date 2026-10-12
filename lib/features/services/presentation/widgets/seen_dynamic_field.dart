// DynamicField in the Seen design language: renders a [DynamicFormField] with
// SeenTextField (text / textarea / number / email / phone), and tap-to-pick
// SeenTextFields for date and select. Same value contract as the shared
// DynamicFieldWidget (String for text-like and select, DateTime for date), so
// the booking bloc and validators are untouched; DynamicFieldWidget itself
// stays as the engine's default renderer (used by the forms gallery).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/utils/latin_digits.dart';
import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';

class SeenDynamicField extends StatefulWidget {
  const SeenDynamicField({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.ltr = false,
  });

  final DynamicFormField field;

  /// `String` for text/textarea/number/email/phone/select, `DateTime` for date.
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? errorText;

  /// Latin-script values (passport data): LTR run at the reading start.
  final bool ltr;

  @override
  State<SeenDynamicField> createState() => _SeenDynamicFieldState();
}

class _SeenDynamicFieldState extends State<SeenDynamicField> {
  static final _dateFormat = DateFormat('yyyy / MM / dd', 'en_US');

  // Owned here: created in initState, disposed in dispose.
  late final TextEditingController _controller = TextEditingController(text: _display(widget.value));

  String _display(Object? value) {
    if (value is DateTime) return _dateFormat.format(value);
    if (value is String) {
      final options = widget.field.options;
      if (widget.field.type == FieldType.select && options != null) {
        for (final o in options) {
          if (o.value == value) return o.label;
        }
      }
      return value;
    }
    return '';
  }

  @override
  void didUpdateWidget(covariant SeenDynamicField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pickers change the value from outside the text edit: mirror it.
    final isPicker = widget.field.type == FieldType.date || widget.field.type == FieldType.select;
    if (isPicker && oldWidget.value != widget.value) _controller.text = _display(widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = widget.value is DateTime ? widget.value as DateTime : null;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year + 100),
    );
    if (picked != null) widget.onChanged(picked);
  }

  Future<void> _pickOption() async {
    final options = widget.field.options ?? const <FieldOption>[];
    final picked = await showSeenSheet<String>(
      context: context,
      title: widget.field.label,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            ListTile(
              title: Text(option.label),
              trailing: option.value == widget.value
                  ? Icon(SeenIcons.check, color: SeenColors.of(sheetContext).primary)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(option.value),
            ),
        ],
      ),
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final isPicker = f.type == FieldType.date || f.type == FieldType.select;
    final keyboard = switch (f.type) {
      FieldType.number => TextInputType.number,
      FieldType.email => TextInputType.emailAddress,
      FieldType.phone => TextInputType.phone,
      FieldType.textarea => TextInputType.multiline,
      _ => null,
    };
    final latinDigits = f.type == FieldType.number || f.type == FieldType.phone;

    return SeenTextField(
      label: f.label,
      hint: f.hint,
      controller: _controller,
      errorText: widget.errorText,
      enabled: !f.disabled,
      ltr: widget.ltr || f.type == FieldType.date || f.type == FieldType.email || f.type == FieldType.phone || f.type == FieldType.number,
      keyboardType: keyboard,
      maxLines: f.type == FieldType.textarea ? 4 : 1,
      inputFormatters: latinDigits ? const [LatinDigitsFormatter()] : null,
      readOnly: isPicker,
      picker: isPicker,
      onTap: !isPicker || f.disabled ? null : (f.type == FieldType.date ? _pickDate : _pickOption),
      suffix: switch (f.type) {
        FieldType.date => Icon(SeenIcons.calendar, size: 20, color: SeenColors.of(context).inkMuted),
        FieldType.select => Icon(SeenIcons.back(context), size: 18, color: SeenColors.of(context).inkMuted),
        _ => null,
      },
      onChanged: isPicker ? null : (v) => widget.onChanged(v),
    );
  }
}
