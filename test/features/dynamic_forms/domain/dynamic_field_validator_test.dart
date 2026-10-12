import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/features/dynamic_forms/domain/entities/dynamic_form_field.dart';
import 'package:seen_booking/features/dynamic_forms/domain/validators/dynamic_field_validator.dart';
import 'package:seen_booking/features/dynamic_forms/domain/validators/form_validation_messages.dart';

const _messages = FormValidationMessages(
  required: 'required',
  invalidEmail: 'invalidEmail',
  invalidPhone: 'invalidPhone',
  invalidNumber: 'invalidNumber',
  invalidDate: 'invalidDate',
  invalidSelection: 'invalidSelection',
  tooShort: _tooShort,
  tooLong: _tooLong,
  numberTooSmall: _numberTooSmall,
  numberTooLarge: _numberTooLarge,
  expiryTooSoon: _expiryTooSoon,
  dateInFuture: _dateInFuture,
);

String _tooShort(int min) => 'tooShort:$min';
String _tooLong(int max) => 'tooLong:$max';
String _numberTooSmall(num min) => 'numberTooSmall:$min';
String _numberTooLarge(num max) => 'numberTooLarge:$max';
String _expiryTooSoon(int months) => 'expiryTooSoon:$months';
String _dateInFuture(String label) => 'dateInFuture:$label';

void main() {
  const validator = DynamicFieldValidator(_messages);

  DynamicFormField textField({bool required = false, int? min, int? max}) =>
      DynamicFormField(
        key: 'f',
        type: FieldType.text,
        label: 'Field',
        required: required,
        minLength: min,
        maxLength: max,
      );

  group('required', () {
    test('rejects a missing value when required', () {
      expect(validator.validate(textField(required: true), null), 'required');
    });

    test('rejects an empty string when required', () {
      expect(validator.validate(textField(required: true), ''), 'required');
    });

    test('accepts a missing value when optional', () {
      expect(validator.validate(textField(), null), isNull);
    });
  });

  group('text length', () {
    test('rejects below minLength', () {
      expect(validator.validate(textField(min: 5), 'ab'), 'tooShort:5');
    });

    test('rejects above maxLength', () {
      expect(validator.validate(textField(max: 3), 'abcd'), 'tooLong:3');
    });

    test('accepts a value within bounds', () {
      expect(validator.validate(textField(min: 2, max: 5), 'abc'), isNull);
    });
  });

  group('email', () {
    DynamicFormField emailField() => const DynamicFormField(
          key: 'email',
          type: FieldType.email,
          label: 'Email',
        );

    test('rejects a malformed address', () {
      expect(validator.validate(emailField(), 'not-an-email'), 'invalidEmail');
    });

    test('accepts a well-formed address', () {
      expect(validator.validate(emailField(), 'a@b.com'), isNull);
    });
  });

  group('phone', () {
    DynamicFormField phoneField() => const DynamicFormField(
          key: 'phone',
          type: FieldType.phone,
          label: 'Phone',
        );

    test('rejects letters', () {
      expect(validator.validate(phoneField(), 'abc'), 'invalidPhone');
    });

    test('accepts an international number with formatting characters', () {
      expect(validator.validate(phoneField(), '+1 (202) 555-0173'), isNull);
    });
  });

  group('number', () {
    DynamicFormField numberField({num? min, num? max}) => DynamicFormField(
          key: 'n',
          type: FieldType.number,
          label: 'Number',
          min: min,
          max: max,
        );

    test('rejects non-numeric text', () {
      expect(validator.validate(numberField(), 'abc'), 'invalidNumber');
    });

    test('rejects below min', () {
      expect(validator.validate(numberField(min: 10), '5'), 'numberTooSmall:10');
    });

    test('rejects above max', () {
      expect(validator.validate(numberField(max: 10), '20'), 'numberTooLarge:10');
    });

    test('accepts a value within bounds', () {
      expect(validator.validate(numberField(min: 0, max: 10), '5'), isNull);
    });
  });

  group('select', () {
    DynamicFormField selectField() => const DynamicFormField(
          key: 's',
          type: FieldType.select,
          label: 'Select',
          options: [
            FieldOption(value: 'a', label: 'A'),
            FieldOption(value: 'b', label: 'B'),
          ],
        );

    test('rejects a value outside the option list', () {
      expect(validator.validate(selectField(), 'z'), 'invalidSelection');
    });

    test('accepts a value from the option list', () {
      expect(validator.validate(selectField(), 'a'), isNull);
    });
  });

  group('date', () {
    test('rejects a non-DateTime value', () {
      expect(
        validator.validate(
          const DynamicFormField(key: 'd', type: FieldType.date, label: 'Date'),
          'not-a-date',
        ),
        'invalidDate',
      );
    });

    test('rejects an expiry date under the minimum months', () {
      const field = DynamicFormField(
        key: 'expiry',
        type: FieldType.date,
        label: 'Expiry',
        dateConstraint: DateFieldConstraint.minMonthsInFuture,
        minMonthsInFuture: 6,
      );
      final soon = DateTime.now().add(const Duration(days: 30));
      expect(validator.validate(field, soon), 'expiryTooSoon:6');
    });

    test('accepts an expiry date past the minimum months', () {
      const field = DynamicFormField(
        key: 'expiry',
        type: FieldType.date,
        label: 'Expiry',
        dateConstraint: DateFieldConstraint.minMonthsInFuture,
        minMonthsInFuture: 6,
      );
      final farEnough = DateTime.now().add(const Duration(days: 400));
      expect(validator.validate(field, farEnough), isNull);
    });

    test('rejects a birth/issue date in the future', () {
      const field = DynamicFormField(
        key: 'issue',
        type: FieldType.date,
        label: 'Issue date',
        dateConstraint: DateFieldConstraint.notInFuture,
      );
      final future = DateTime.now().add(const Duration(days: 1));
      expect(validator.validate(field, future), 'dateInFuture:Issue date');
    });

    test('accepts a birth/issue date in the past', () {
      const field = DynamicFormField(
        key: 'issue',
        type: FieldType.date,
        label: 'Issue date',
        dateConstraint: DateFieldConstraint.notInFuture,
      );
      expect(validator.validate(field, DateTime(2000, 1, 1)), isNull);
    });
  });
}
