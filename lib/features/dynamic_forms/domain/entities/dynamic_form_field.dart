import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import 'field_condition.dart';

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
  const FieldOption({required this.value, required this.label, this.description});

  /// The value submitted/stored — stable, not necessarily user-facing.
  final String value;

  /// The user-facing, already-localized text.
  final String label;

  /// Optional second line under [label] (e.g. a code or a short explanation).
  final String? description;

  @override
  List<Object?> get props => [value, label, description];
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
    this.definitionId,
    this.step = 1,
    this.format,
    this.showIf,
    this.requiredIf,
    this.dateNotFuture = false,
    this.dateNotPast = false,
    this.minValidMonths,
    this.minAgeYears,
    this.maxAgeYears,
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

  /// The server's id of this field (`fieldDefinitionId` when values are sent).
  final String? definitionId;

  /// The wizard step the server puts this field on.
  final int step;

  /// The server's `format` hint (informational; the server validates it).
  final String? format;

  /// Shown only while this holds for the traveler's other values; a hidden
  /// field counts as empty and is neither validated nor sent.
  final FieldCondition? showIf;

  /// Required (in addition to [required]) while this holds.
  final FieldCondition? requiredIf;

  /// Date rules from the server, independent of each other: not after today,
  /// not before today, at least this many months from today (a document's
  /// remaining validity), and an age range in whole years from today.
  final bool dateNotFuture;
  final bool dateNotPast;
  final int? minValidMonths;
  final int? minAgeYears;
  final int? maxAgeYears;

  /// Whether the field is shown for a traveler's current [values].
  bool isVisible(Map<String, Object?> values) => showIf == null || showIf!.matches(values);

  /// Whether the field must be filled for a traveler's current [values].
  bool isRequiredFor(Map<String, Object?> values) =>
      isVisible(values) && (required || (requiredIf?.matches(values) ?? false));

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
        definitionId,
        step,
        format,
        showIf,
        requiredIf,
        dateNotFuture,
        dateNotPast,
        minValidMonths,
        minAgeYears,
        maxAgeYears,
      ];
}
