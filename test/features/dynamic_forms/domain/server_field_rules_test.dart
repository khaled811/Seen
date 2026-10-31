// The field rules a service sends (`effectiveRules`): conditions between fields
// and the date rules. They are hints; the server validates again.

import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/features/dynamic_forms/domain/entities/dynamic_form_field.dart';
import 'package:seen_booking/features/dynamic_forms/domain/entities/field_condition.dart';
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
  dateInPast: _dateInPast,
  ageTooYoung: _ageTooYoung,
  ageTooOld: _ageTooOld,
);

String _tooShort(int min) => 'tooShort:$min';
String _tooLong(int max) => 'tooLong:$max';
String _numberTooSmall(num min) => 'numberTooSmall:$min';
String _numberTooLarge(num max) => 'numberTooLarge:$max';
String _expiryTooSoon(int months) => 'expiryTooSoon:$months';
String _dateInFuture(String label) => 'dateInFuture';
String _dateInPast(String label) => 'dateInPast';
String _ageTooYoung(int years) => 'ageTooYoung:$years';
String _ageTooOld(int years) => 'ageTooOld:$years';

void main() {
  const validator = DynamicFieldValidator(_messages);

  group('FieldCondition', () {
    test('eq / ne compare the entered text', () {
      const eq = FieldCondition(field: 'kind', op: 'eq', values: ['visa']);
      const ne = FieldCondition(field: 'kind', op: 'ne', values: ['visa']);
      expect(eq.matches({'kind': 'visa'}), isTrue);
      expect(eq.matches({'kind': 'other'}), isFalse);
      expect(ne.matches({'kind': 'visa'}), isFalse);
      expect(ne.matches({'kind': 'other'}), isTrue);
    });

    test('in matches any listed value', () {
      const c = FieldCondition(field: 'k', op: 'in', values: ['a', 'b']);
      expect(c.matches({'k': 'b'}), isTrue);
      expect(c.matches({'k': 'c'}), isFalse);
      expect(c.matches(const {}), isFalse);
    });

    test('filled / empty treat blanks and missing values as empty', () {
      const filled = FieldCondition(field: 'k', op: 'filled');
      const empty = FieldCondition(field: 'k', op: 'empty');
      expect(filled.matches({'k': '  '}), isFalse);
      expect(filled.matches({'k': 'x'}), isTrue);
      expect(empty.matches(const {}), isTrue);
      expect(empty.matches({'k': 'x'}), isFalse);
    });

    test('dates compare as YYYY-MM-DD', () {
      const c = FieldCondition(field: 'd', op: 'eq', values: ['2026-03-05']);
      expect(c.matches({'d': DateTime(2026, 3, 5, 14)}), isTrue);
    });

    test('an operator the app does not know never hides or requires anything', () {
      const c = FieldCondition(field: 'k', op: 'startswith', values: ['x']);
      expect(c.isKnown, isFalse);
      expect(c.matches({'k': 'y'}), isTrue);
    });
  });

  group('visibility and requirement', () {
    const spouse = DynamicFormField(
      key: 'spouseName',
      type: FieldType.text,
      label: 'Spouse',
      showIf: FieldCondition(field: 'status', op: 'eq', values: ['married']),
      required: true,
    );

    test('a field shown only under a condition is hidden and not an error otherwise', () {
      expect(spouse.isVisible({'status': 'single'}), isFalse);
      expect(validator.validate(spouse, null, values: {'status': 'single'}), isNull);
      expect(validator.validate(spouse, null, values: {'status': 'married'}), 'required');
      expect(validator.validate(spouse, 'Amal', values: {'status': 'married'}), isNull);
    });

    test('a hidden field with a bad value is still not validated', () {
      const f = DynamicFormField(
        key: 'x',
        type: FieldType.email,
        label: 'x',
        showIf: FieldCondition(field: 'a', op: 'filled'),
      );
      expect(validator.validate(f, 'not an email', values: const {}), isNull);
      expect(validator.validate(f, 'not an email', values: {'a': '1'}), 'invalidEmail');
    });

    test('required_if makes an optional field required under its condition', () {
      const f = DynamicFormField(
        key: 'visaNo',
        type: FieldType.text,
        label: 'Visa',
        requiredIf: FieldCondition(field: 'hasVisa', op: 'eq', values: ['yes']),
      );
      expect(validator.validate(f, '', values: {'hasVisa': 'no'}), isNull);
      expect(validator.validate(f, '', values: {'hasVisa': 'yes'}), 'required');
    });
  });

  group('date rules', () {
    DynamicFormField date({
      bool notFuture = false,
      bool notPast = false,
      int? validMonths,
      int? minAge,
      int? maxAge,
    }) =>
        DynamicFormField(
          key: 'd',
          type: FieldType.date,
          label: 'Date',
          dateNotFuture: notFuture,
          dateNotPast: notPast,
          minValidMonths: validMonths,
          minAgeYears: minAge,
          maxAgeYears: maxAge,
        );

    final today = DateTime.now();

    test('date_not_future', () {
      expect(validator.validate(date(notFuture: true), today.add(const Duration(days: 2))), 'dateInFuture');
      expect(validator.validate(date(notFuture: true), today.subtract(const Duration(days: 2))), isNull);
    });

    test('date_not_past', () {
      expect(validator.validate(date(notPast: true), today.subtract(const Duration(days: 2))), 'dateInPast');
      expect(validator.validate(date(notPast: true), today.add(const Duration(days: 2))), isNull);
    });

    test('min_valid_months (a passport must stay valid for N more months)', () {
      expect(validator.validate(date(validMonths: 6), DateTime(today.year, today.month + 3, today.day)), 'expiryTooSoon:6');
      expect(validator.validate(date(validMonths: 6), DateTime(today.year, today.month + 8, today.day)), isNull);
    });

    test('min_age_years and max_age_years', () {
      final tenYearsAgo = DateTime(today.year - 10, today.month, today.day);
      final ninetyYearsAgo = DateTime(today.year - 90, today.month, today.day);
      expect(validator.validate(date(minAge: 18), tenYearsAgo), 'ageTooYoung:18');
      expect(validator.validate(date(minAge: 18), DateTime(today.year - 30, 1, 1)), isNull);
      expect(validator.validate(date(maxAge: 80), ninetyYearsAgo), 'ageTooOld:80');
      expect(validator.validate(date(maxAge: 80), DateTime(today.year - 30, 1, 1)), isNull);
    });

    test('the server date rules work without the optional messages (generic invalid date)', () {
      const plain = FormValidationMessages(
        required: 'required',
        invalidEmail: 'e',
        invalidPhone: 'p',
        invalidNumber: 'n',
        invalidDate: 'invalidDate',
        invalidSelection: 's',
        tooShort: _tooShort,
        tooLong: _tooLong,
        numberTooSmall: _numberTooSmall,
        numberTooLarge: _numberTooLarge,
        expiryTooSoon: _expiryTooSoon,
        dateInFuture: _dateInFuture,
      );
      expect(const DynamicFieldValidator(plain).validate(date(notPast: true), DateTime(2000)), 'invalidDate');
    });
  });
}
