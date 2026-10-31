import '../../../../core/constants/enums.dart';
import '../entities/dynamic_form_field.dart';
import 'form_validation_messages.dart';
import 'passport_validators.dart';

/// Validates a raw field value against its [DynamicFormField] definition.
///
/// Pure Dart — no Flutter import — so it's testable in isolation and usable
/// from both the wizard cubit and any ad-hoc single-field validation.
/// Every field value is stored as a plain type the caller controls: a
/// [String] for text/textarea/number/email/phone/select, a [DateTime] for
/// date. Parsing (e.g. "is this text a number") happens here, not in the UI.
class DynamicFieldValidator {
  const DynamicFieldValidator(this.messages);

  final FormValidationMessages messages;

  static final _emailRegExp = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  /// Loose international format: optional leading `+`, 8–15 digits, ignoring
  /// spaces/dashes/parentheses a user might type.
  static final _phoneRegExp = RegExp(r'^\+?[1-9]\d{7,14}$');

  /// Validates one field. [values] are the traveler's other entered values,
  /// needed for `show_if` / `required_if`; a hidden field is never an error.
  String? validate(DynamicFormField field, Object? rawValue, {Map<String, Object?> values = const {}}) {
    if (!field.isVisible(values)) return null;
    final isEmpty = rawValue == null ||
        (rawValue is String && rawValue.trim().isEmpty);

    if (isEmpty) return field.isRequiredFor(values) ? messages.required : null;

    return switch (field.type) {
      FieldType.text || FieldType.textarea =>
        _validateLength(field, rawValue as String),
      FieldType.number => _validateNumber(field, rawValue as String),
      FieldType.email => _validateEmail(rawValue as String),
      FieldType.phone => _validatePhone(rawValue as String),
      FieldType.date => _validateDate(field, rawValue),
      FieldType.select => _validateSelect(field, rawValue),
      FieldType.unknown => null,
    };
  }

  String? _validateLength(DynamicFormField field, String value) {
    final length = value.trim().length;
    if (field.minLength != null && length < field.minLength!) {
      return messages.tooShort(field.minLength!);
    }
    if (field.maxLength != null && length > field.maxLength!) {
      return messages.tooLong(field.maxLength!);
    }
    return null;
  }

  String? _validateNumber(DynamicFormField field, String value) {
    final parsed = num.tryParse(value.trim());
    if (parsed == null) return messages.invalidNumber;
    if (field.min != null && parsed < field.min!) {
      return messages.numberTooSmall(field.min!);
    }
    if (field.max != null && parsed > field.max!) {
      return messages.numberTooLarge(field.max!);
    }
    return null;
  }

  String? _validateEmail(String value) =>
      _emailRegExp.hasMatch(value.trim()) ? null : messages.invalidEmail;

  String? _validatePhone(String value) {
    final normalized = value.replaceAll(RegExp(r'[\s\-()]'), '');
    return _phoneRegExp.hasMatch(normalized) ? null : messages.invalidPhone;
  }

  String? _validateDate(DynamicFormField field, Object? rawValue) {
    if (rawValue is! DateTime) return messages.invalidDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(rawValue.year, rawValue.month, rawValue.day);

    // The server's date rules (hints; the server validates again).
    if (field.dateNotFuture && day.isAfter(today)) return messages.dateInFuture(field.label);
    if (field.dateNotPast && day.isBefore(today)) return (messages.dateInPast ?? (_) => messages.invalidDate)(field.label);
    final validMonths = field.minValidMonths;
    if (validMonths != null &&
        !PassportValidators.isValidExpiryDate(rawValue, now: now, minMonths: validMonths)) {
      return messages.expiryTooSoon(validMonths);
    }
    final minAge = field.minAgeYears;
    if (minAge != null && minAge > 0 && day.isAfter(DateTime(today.year - minAge, today.month, today.day))) {
      return (messages.ageTooYoung ?? (_) => messages.invalidDate)(minAge);
    }
    final maxAge = field.maxAgeYears;
    if (maxAge != null && day.isBefore(DateTime(today.year - maxAge, today.month, today.day))) {
      return (messages.ageTooOld ?? (_) => messages.invalidDate)(maxAge);
    }

    return switch (field.dateConstraint) {
      DateFieldConstraint.none => null,
      DateFieldConstraint.minMonthsInFuture =>
        PassportValidators.isValidExpiryDate(
          rawValue,
          now: now,
          minMonths: field.minMonthsInFuture,
        )
            ? null
            : messages.expiryTooSoon(field.minMonthsInFuture),
      DateFieldConstraint.notInFuture =>
        PassportValidators.isNotInFuture(rawValue, now: now)
            ? null
            : messages.dateInFuture(field.label),
    };
  }

  String? _validateSelect(DynamicFormField field, Object? rawValue) {
    final options = field.options ?? const [];
    if (options.isNotEmpty && !options.any((o) => o.value == rawValue)) {
      return messages.invalidSelection;
    }
    return null;
  }
}
