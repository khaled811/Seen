import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../domain/entities/dynamic_form_field.dart';

/// Renders the input control matching a [DynamicFormField.type].
///
/// Owns its own [TextEditingController] for text-like fields (created in
/// [initState], disposed in [dispose]) so typing doesn't fight the parent
/// rebuilding on every keystroke; [onChanged] is the single source of truth
/// pushed back up to the wizard cubit.
class DynamicFieldWidget extends StatefulWidget {
  const DynamicFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final DynamicFormField field;

  /// `String` for text/textarea/number/email/phone/select, `DateTime` for
  /// date.
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? errorText;

  @override
  State<DynamicFieldWidget> createState() => _DynamicFieldWidgetState();
}

class _DynamicFieldWidgetState extends State<DynamicFieldWidget> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value is String ? widget.value as String : '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: switch (widget.field.type) {
        FieldType.textarea => _buildText(maxLines: 4),
        FieldType.number => _buildText(keyboardType: TextInputType.number),
        FieldType.email => _buildText(keyboardType: TextInputType.emailAddress),
        FieldType.phone => _buildText(keyboardType: TextInputType.phone),
        FieldType.date => _buildDate(),
        FieldType.select => _buildSelect(),
        FieldType.text || FieldType.unknown => _buildText(),
      },
    );
  }

  Widget _buildText({int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: _controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: !widget.field.disabled,
      decoration: InputDecoration(
        labelText: widget.field.label,
        hintText: widget.field.hint,
        errorText: widget.errorText,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }

  Widget _buildDate() {
    final date = widget.value is DateTime ? widget.value as DateTime : null;
    return InkWell(
      onTap: widget.field.disabled ? null : () => _pickDate(date),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.field.label,
          hintText: widget.field.hint,
          errorText: widget.errorText,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(date == null ? '' : DateFormat.yMMMd().format(date)),
      ),
    );
  }

  Future<void> _pickDate(DateTime? initial) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year + 100),
    );
    if (picked != null) widget.onChanged(picked);
  }

  Widget _buildSelect() {
    final options = widget.field.options ?? const [];
    final currentValue = widget.value is String ? widget.value as String : null;
    return DropdownButtonFormField<String>(
      value: options.any((o) => o.value == currentValue) ? currentValue : null,
      decoration: InputDecoration(
        labelText: widget.field.label,
        errorText: widget.errorText,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option.value, child: Text(option.label)),
      ],
      onChanged: widget.field.disabled ? null : widget.onChanged,
    );
  }
}
