import 'package:equatable/equatable.dart';

/// A condition on another field of the same traveler, from the service's
/// `effectiveRules` (`show_if` / `required_if`). Operators: `eq`, `ne`, `in`,
/// `filled`, `empty`.
///
/// A hidden field counts as empty, so a condition on a hidden field sees an
/// empty value. An operator the app does not know never hides or requires a
/// field (the server stays the authority and says what it needs).
class FieldCondition extends Equatable {
  const FieldCondition({required this.field, required this.op, this.values = const []});

  /// The `fieldKey` of the field this one depends on.
  final String field;
  final String op;

  /// The compared value(s): one for `eq` / `ne`, several for `in`.
  final List<String> values;

  /// Whether the condition holds for the traveler's current [values]
  /// (field key -> entered value). Dates compare as `YYYY-MM-DD`.
  bool matches(Map<String, Object?> values) {
    final current = _text(values[field]);
    return switch (op) {
      'eq' => this.values.isNotEmpty && current == this.values.first,
      'ne' => this.values.isEmpty || current != this.values.first,
      'in' => this.values.contains(current),
      'filled' => current.isNotEmpty,
      'empty' => current.isEmpty,
      _ => true,
    };
  }

  /// Whether this condition's operator is one the app understands.
  bool get isKnown => const {'eq', 'ne', 'in', 'filled', 'empty'}.contains(op);

  static String _text(Object? value) {
    if (value == null) return '';
    if (value is DateTime) {
      return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    }
    return value.toString().trim();
  }

  @override
  List<Object?> get props => [field, op, values];
}
