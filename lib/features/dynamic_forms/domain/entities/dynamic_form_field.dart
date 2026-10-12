import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// A date field's business-rule constraint, applied on top of the generic
/// [FieldType.date] rendering. Declarative — the engine doesn't need to
/// know a field is "passport expiry" by name, only which constraint to run.
enum DateFieldConstraint {
  none,

  /// Must be at least [DynamicFormField.minMonthsInFuture] months from
  /// today (e.g. passport expiry).
  minMonthsInFuture,

  /// Must not be in the future (e.g. passport issue date, date of birth).
  notInFuture,
}

/// One selectable choice for a [FieldType.select] field.
class FieldOption extends Equatable {
  const FieldOption({required this.value, required this.label});

  /// The value submitted/stored — stable, not necessarily user-facing.
  final String value;

  /// The user-facing, already-localized text.
  final String label;

  @override
  List<Object?> get props => [value, label];
}

/// Declarative definition of one dynamic form field.
///
/// Pure Dart — this is what a backend-driven form configuration would
/// deserialize into (that data-layer mapping is out of scope for this
/// engine; today's callers build these by hand). [label]/[hint] are plain
/// strings so the caller decides the source — a localized ARB string or
/// backend-provided text — the engine itself doesn't care.
class DynamicFormField extends Equatable {
  const DynamicFormField({
    required this.key,
    required this.type,
    required this.label,
    this.hint,
    this.required = false,
    this.disabled = false,
    this.minLength,
    this.maxLength,
    this.min,
    this.max,
    this.options,
    this.dateConstraint = DateFieldConstraint.none,
    this.minMonthsInFuture = 6,
  });

  /// Stable identifier; the key into a wizard's values/errors maps.
  final String key;
  final FieldType type;
  final String label;
  final String? hint;
  final bool required;
  final bool disabled;

  /// Text/textarea only.
  final int? minLength;
  final int? maxLength;

  /// Number only.
  final num? min;
  final num? max;

  /// Select only.
  final List<FieldOption>? options;

  /// Date only.
  final DateFieldConstraint dateConstraint;

  /// Date only, used when [dateConstraint] is [DateFieldConstraint.minMonthsInFuture].
  final int minMonthsInFuture;

  @override
  List<Object?> get props => [
        key,
        type,
        label,
        hint,
        required,
        disabled,
        minLength,
        maxLength,
        min,
        max,
        options,
        dateConstraint,
        minMonthsInFuture,
      ];
}
